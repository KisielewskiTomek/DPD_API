unit dpd;

{==============================================================================|
| Bibiloteka dla FPC/Lazarus do komunikacji z  WebService DPD                  |
| wymagane biblioteki DLL                                                      |
| libeay32.dll                                                                 |
| ssleay32.dll                                                                 |
| dla Linux: Open_SSL                                                          |
|                                                                              |
| Wymagany do kompilacji pakiet Aratat Synapse                                 |
|                                                                              |
|                                                                              |
|                                                                              |
| Copyright (c) 2018, Tomasz Kisielewski                                       |
| All rights reserved.                                                         |
|                                                                              |
| Redistribution and use in source and binary forms, with or without           |
| modification, are permitted provided that the following conditions are met:  |
|                                                                              |
| Redistributions of source code must retain the above copyright notice, this  |
| list of conditions and the following disclaimer.                             |
|                                                                              |
| Redistributions in binary form must reproduce the above copyright notice,    |
| this list of conditions and the following disclaimer in the documentation    |
| and/or other materials provided with the distribution.                       |
|                                                                              |
| THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"  |
| AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE    |
| IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE   |
| ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR  |
| ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL       |
| DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR   |
| SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER   |
| CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT           |
| LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY    |
| OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  |
| DAMAGE.                                                                      |
|==============================================================================}

{$mode objfpc}{$H+}

interface

uses  Classes,
      FileUtil,
      LazUTF8,
      LazFileUtils,
      httpsend,
      ssl_openssl,
      SysUtils,
      SynaCode,
      laz2_DOM,
      laz2_XMLRead;

const DPDUrl='https://dpdservicesdemo.dpd.com.pl/DPDPackageXmlServicesService/DPDPackageXmlServices';
  //const DPDUrl='https://dpdservices.dpd.com.pl/DPDPackageXmlServicesService/DPDPackageXmlServices';


type  TAuthData              =record
        Login                :String;
        Passwd               :String;
        MasterFid            :string;
      end;

type  TRef                   =record
        Ref1                 :String;
        Ref2                 :String;
        Ref3                 :String;
      end;

type  TParcel                =record
        SizeX                :Integer;
        SizeY                :Integer;
        SizeZ                :Integer;
        Weight               :Real;
        Content              :String;
        Cust_Data1           :String;
        Waybill              :String;
      end;

type  TReceiver              =record
        Company              :String;
        Name                 :String;
        Address              :String;
        City                 :String;
        CountryCode          :String;
        PostalCode           :String;
        Phone                :String;
        Email                :String;
      end;

type  TSender                =record
        Company              :String;
        Name                 :String;
        Address              :String;
        City                 :String;
        CountryCode          :String;
        PostalCode           :String;
        Phone                :String;
        Email                :String;
      end;

type  TParcels=class
        Items                :array of TParcel;
        procedure Add(Value:TParcel);
        function Count:Integer;
        constructor Create;
        end;

type  TDPD= class
      public
        Parcels              :TParcels;
        AuthData             :TAuthData;
        Receiver             :TReceiver;
        Sender               :TSender;
        Ref                  :TRef;
        PickupDate           :String;
        PickupTimeFrom       :String;
        PickupTimeTo         :String;
        PDF_SpeedLabels      :String;
        PDF_Protocol         :String;
        OrderNumber          :String;
        Status               :String;
        constructor Create(Log_Enabled:Boolean);
        destructor Destroy;override;
        function Run:String;
        function PackagesPickupCallXV2:boolean;
      private
        Log                  :Boolean;
        Log_File             :TextFile;
        SessionId            :String;
        function GeneratePackagesNumbersXV1:boolean;
        function GenerateSpedLabelsXV1:boolean;
        function GenerateProtocolXV1:boolean;
        procedure WriteToLog(Value:AnsiString);
        function Make_WS(var XML:AnsiString):Boolean;
        function Parse_XML(var XML:Ansistring;Node:String):Boolean;
        function TKDate:String;
        function TKTime:String;
      end;

implementation

constructor TParcels.Create;
begin
  SetLength(Items,0);
end;

procedure TParcels.Add(Value:TParcel);
begin
  SetLength(Items,Length(Items)+1);
  Items[Length(Items)-1]:=Value;
end;

function TParcels.Count:Integer;
begin
  Result:=Length(Items);
end;

constructor TDPD.Create(Log_Enabled:Boolean);
begin
  Parcels:=TParcels.Create;
  Log:=Log_Enabled;
  if Log then
    begin
      AssignFile(Log_File,GetCurrentDirUTF8+PathDelim+'dpd.log');
      Rewrite(Log_File);
    end;
end;

function TDPD.Parse_XML(var XML:Ansistring;Node:String):Boolean;
var      Doc                 :TXMLDocument;
         Members             :TDOMNodeList;
         Member              :TDOMNode;
         I                   :integer;
         Temp                :TStringList;
begin
  ReadXMLFile(doc,TStringStream.Create(XML));
  Members:=Doc.GetElementsByTagName(Node);
  if Members.Count=0 then
    begin
      Result:=False;
      Exit;
    end;

  Temp:=TStringList.Create;

  for i:= 0 to Members.Count - 1 do
    begin
      Member:= Members[i];
      Temp.Add(Member.TextContent);
    end;

  if Members.Count=1 then
    begin
      XML:=Temp[0];
    end else
    begin
      XML:=Temp.Text;
    end;
  Temp.Free;

  Result:=True;
end;

function TDPD.Run:String;
begin
  if Parcels.Count=0 then
    begin
      Result:='NO_PARCELS';
      Exit;
    end;

  if not GeneratePackagesNumbersXV1 then
    begin
      Result:='ERROR_GENERATING_PACKAGES_NUMBERS';
      Exit;
    end;

  if not GenerateSpedLabelsXV1 then
    begin
      Result:='ERROR_GENERATING_SPEED_LABELS';
      Exit;
    end;

  if not GenerateProtocolXV1 then
    begin
      Result:='ERROR_GENERATING_PRTOCOL';
      Exit;
    end;

  Result:='OK';
end;

function TDPD.PackagesPickupCallXV2:boolean;
var      I_XML               :AnsiString;
         XML                 :AnsiString;
         Temp                :AnsiString;
         Loop                :Integer;
         ParcelsWeight       :Real;
         MaxParcelWeight     :Real;
         MaxParcelIndex      :Integer;
         MaxParcel           :Integer;
         TempI               :Integer;
         TempR               :Real;
begin
  ParcelsWeight:=0;
  For Loop:=0 to Parcels.Count-1 do
    begin
      ParcelsWeight:=ParcelsWeight+Parcels.Items[Loop].Weight;
    end;

  MaxParcelWeight:=0;
  For Loop:=0 to Parcels.Count-1 do
    begin
      TempR:=Parcels.Items[Loop].Weight;
      If TempR>MaxParcelWeight then
        begin
          MaxParcelWeight:=TempR;
        end;
    end;

  MaxParcel:=0;
  For Loop:=0 to Parcels.Count-1 do
    begin
      TempI:=Parcels.Items[Loop].SizeX+Parcels.Items[Loop].SizeY+Parcels.Items[Loop].SizeZ;
      If TempI>MaxParcel then
        begin
          MaxParcel:=TempI;
          MaxParcelIndex:=Loop;
        end;
    end;

  I_XML:=
  '<DPDPickupCallParamsV2>'+LineEnding+
  '  <OperationType>INSERT</OperationType>'+LineEnding+
  '  <PickupDate>'+PickupDate+'</PickupDate>'+LineEnding+
  '  <PickupTimeFrom>'+PickupTimeFrom+':00</PickupTimeFrom>'+LineEnding+
  '  <PickupTimeTo>'+PickupTimeTo+':00</PickupTimeTo>'+LineEnding+
  '  <OrderType>DOMESTIC</OrderType>'+LineEnding+
  '  <WaybillsReady>true</WaybillsReady>'+LineEnding+
  '  <PickupCallSimplifiedDetails>'+LineEnding+
  '      <PickupPayer>'+LineEnding+
  '          <PayerNumber>'+AuthData.MasterFid+'</PayerNumber>'+LineEnding+
  '          <PayerName>'+Sender.Company+'</PayerName>'+LineEnding+
  '          <PayerCostCenter></PayerCostCenter>'+LineEnding+
  '      </PickupPayer>'+LineEnding+
  '      <PickupCustomer>'+LineEnding+
  '          <CustomerName>'+Sender.Name+'</CustomerName>'+LineEnding+
  '          <CustomerFullName>'+Sender.Company+'</CustomerFullName>'+LineEnding+
  '          <CustomerPhone>'+Sender.Phone+'</CustomerPhone>'+LineEnding+
  '      </PickupCustomer>'+LineEnding+
  '      <PickupSender>'+LineEnding+
  '          <SenderName>'+Sender.Name+'</SenderName>'+LineEnding+
  '          <SenderFullName>'+Sender.Company+'</SenderFullName>'+LineEnding+
  '          <SenderAddress>'+Sender.Address+'</SenderAddress>'+LineEnding+
  '          <SenderCity>'+Sender.City+'</SenderCity>'+LineEnding+
  '  <!--SenderPostalCode>02495</SenderPostalCode-->'+LineEnding+
  '          <SenderPostalCode>'+Sender.PostalCode+'</SenderPostalCode>'+LineEnding+
  '          <SenderPhone>'+Sender.Phone+'</SenderPhone>'+LineEnding+
  '      </PickupSender>'+LineEnding+
  '      <PackagesParams>'+LineEnding+
  '          <DOX>false</DOX>'+LineEnding+
  '          <StandardParcel>true</StandardParcel>'+LineEnding+
  '          <Pallet>false</Pallet>'+LineEnding+
  '          <ParcelsCount>'+IntToStr(Parcels.Count)+'</ParcelsCount>'+LineEnding+
  '          <PalletsCount>0</PalletsCount>'+LineEnding+
  '          <DOXCount>0</DOXCount>'+LineEnding+
  '          <ParcelsWeight>'+FloatToStr(ParcelsWeight)+'</ParcelsWeight>'+LineEnding+
  '          <ParcelMaxWeight>'+FloatToStr(MaxParcelWeight)+'</ParcelMaxWeight>'+LineEnding+
  '          <ParcelMaxWidth>'+IntToStr(Parcels.Items[MaxParcelIndex].SizeX)+'</ParcelMaxWidth>'+LineEnding+
  '          <ParcelMaxHeight>'+IntToStr(Parcels.Items[MaxParcelIndex].SizeY)+'</ParcelMaxHeight>'+LineEnding+
  '          <ParcelMaxDepth>'+IntToStr(Parcels.Items[MaxParcelIndex].SizeZ)+'</ParcelMaxDepth>'+LineEnding+
  '          <PalletsWeight>0</PalletsWeight>'+LineEnding+
  '          <PalletMaxWeight>0</PalletMaxWeight>'+LineEnding+
  '          <PalletMaxHeight>0</PalletMaxHeight>'+LineEnding+
  '      </PackagesParams>'+LineEnding+
  '  </PickupCallSimplifiedDetails>'+LineEnding+
  '</DPDPickupCallParamsV2>'                 ;

  Temp:=EncodeBase64(I_XML);

  XML:=
  '<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">'+LineEnding+
  '<S:Header/>'+LineEnding+
  '<S:Body>'+LineEnding+
  '  <ns2:packagesPickupCallXV2 xmlns:ns2="http://dpdservices.dpd.com.pl/">'+LineEnding+
  '  <dpdPickupParamsXV2>'+Temp+'</dpdPickupParamsXV2>'+LineEnding+
  '  <pkgNumsGenerationPolicyV1>IGNORE_ERRORS</pkgNumsGenerationPolicyV1>'+LineEnding+
  '  <authDataV1>'+LineEnding+
  '   <login>'+AuthData.Login+'</login>'+LineEnding+
  '   <masterFid>'+AuthData.MasterFid+'</masterFid>'+LineEnding+
  '   <password>'+AuthData.Passwd+'</password>'+LineEnding+
  '  </authDataV1>'+LineEnding+
  '  </ns2:packagesPickupCallXV2>'+LineEnding+
  '</S:Body>'+LineEnding+
  '</S:Envelope>';

  WriteToLog('');
  WriteToLog(UTF8PadRight('packagesPickupCallXV2',40)+':XML');
  WriteToLog('');
  WriteToLog(XML);
  WriteToLog('');

  if not Make_WS(XML) then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);

  if not Parse_XML(XML,'return') then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);
  WriteToLog('');

  Temp:=DecodeBase64(XML);

  WriteToLog(Temp);
  WriteToLog('');

 if not Parse_XML(Temp,'Status') then
    begin
      Result:=False;
      Exit;
    end;

 Status:=Temp;

 Temp:=DecodeBase64(XML);

  if not Parse_XML(Temp,'OrderNumber') then
    begin
      Result:=False;
      Exit;
    end;
  OrderNumber:=Temp;
  WriteToLog(UTF8PadRight('OrderNumber',40)+':'+Temp);
  WriteToLog('');
  Result:=True;

end;

function TDPD.Make_WS(var XML:AnsiString):Boolean;
var     HttpResult           :TStringList;
        HTTP                 :THTTPSend;
begin
  Result:=True;
  Http :=THttpSend.Create;
  Http.Clear;
  Http.Sock.SSLDoConnect;
  Http.Headers.Clear;
  Http.MimeType := 'text/xml;charset="utf-8"';
  Http.KeepAlive := True;
  Http.Protocol:='1.1';
  Http.UserAgent := 'Mozilla/5.0';
  Http.Document.Write(Pointer(XML)^,Length(XML));
  if not Http.HTTPMethod('POST', DPDUrl) then
    begin
      WriteToLog(UTF8PadRight('HTTPS REQUEST ERROR',40)+ ':');
      Result:=False;
      Exit;
    end;
  HttpResult:=TStringList.Create;
  HttpResult.LoadFromStream(HTTP.Document);
  XML:=HttpResult.Text;
  WriteToLog(UTF8PadRight('HTTPS RESULTCODE',40)+ ':'+IntToStr(Http.ResultCode));
  WriteToLog(UTF8PadRight('HTTPS RESULT',40)+ ':'+XML);
  HttpResult.Free;

  if Http.ResultCode<>200 then
    begin
      Result:=False;
    end;
  Http.Free;
end;

function TDPD.GeneratePackagesNumbersXV1:boolean;
Var      I_XML               :AnsiString;
         XML                 :AnsiString;
         Temp                :AnsiString;
         Loop                :Integer;
         WayBills            :TStringList;

begin
  Result:=True;

  Temp:='';
  For Loop:=0 to Parcels.Count-1 do
    begin
      Temp:=Temp+
      '   <Parcel>'+LineEnding+
      '    <Weight>'+FloattoStr(Parcels.Items[Loop].Weight)+ '</Weight>'+LineEnding+
      '    <SizeX>'+IntToStr(Parcels.Items[Loop].SizeX)+'</SizeX>'+LineEnding+
      '    <SizeY>'+IntToStr(Parcels.Items[Loop].SizeY)+'</SizeY>'+LineEnding+
      '    <SizeZ>'+IntToStr(Parcels.Items[Loop].SizeZ)+'</SizeZ>'+LineEnding+
      '    <Content>'+Parcels.Items[Loop].Content+'</Content>'+LineEnding+
      '    <CustomerData1>'+Parcels.Items[Loop].Cust_Data1+'</CustomerData1>'+LineEnding+
      '    <CustomerData2></CustomerData2>'+LineEnding+
      '    <CustomerData3></CustomerData3>'+LineEnding+
      '    </Parcel>'+LineEnding;
    end;

  I_XML:=
  '<Packages>'+LineEnding+
  ' <Package>'+LineEnding+
  '  <PayerType>SENDER</PayerType>'+LineEnding+
  '   <Receiver>'+LineEnding+
  '    <Company>'+Receiver.Company+'</Company>'+LineEnding+
  '    <Name>'+Receiver.Name+'</Name>'+LineEnding+
  '    <Address>'+Receiver.Address+'</Address>'+LineEnding+
  '    <City>'+Receiver.City+'</City>'+LineEnding+
  '    <CountryCode>'+Receiver.CountryCode+'</CountryCode>'+LineEnding+
  '    <PostalCode>'+Receiver.PostalCode+'</PostalCode>'+LineEnding+
  '    <Phone>'+Receiver.Phone+'</Phone>'+LineEnding+
  '    <Email>'+Receiver.Email+'</Email>'+LineEnding+
  '  </Receiver>'+LineEnding+
  '  <Sender>'+LineEnding+
  '   <FID>'+AuthData.MasterFid+'</FID>'+LineEnding+
  '   <Company>'+Sender.Company+'</Company>'+LineEnding+
  '   <Name>'+Sender.Name+'</Name>'+LineEnding+
  '   <Address>'+Sender.Address+'</Address>'+LineEnding+
  '   <City>'+Sender.City+'</City>'+LineEnding+
  '   <CountryCode>'+Sender.CountryCode+'</CountryCode>'+LineEnding+
  '   <PostalCode>'+Sender.PostalCode+'</PostalCode>'+LineEnding+
  '   <Phone>'+Sender.Phone+'</Phone>'+LineEnding+
  '   <Email>'+Sender.Email+'</Email>'+LineEnding+
  '  </Sender>'+LineEnding+
  '  <Ref1>'+Ref.Ref1+'</Ref1>'+LineEnding+
  '  <Ref2>'+Ref.Ref2+'</Ref2>'+LineEnding+
  '  <Ref3>'+Ref.Ref3+'</Ref3>'+LineEnding+
  '  <Parcels>'+LineEnding+
  Temp+
  '  </Parcels>'+LineEnding+
  ' </Package>'+LineEnding+
  '</Packages>';

  Temp:=EncodeBase64(I_XML);

  XML:=
  '<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">'+LineEnding+
  '<S:Header/>'+LineEnding+
  '<S:Body>'+LineEnding+
  '  <ns2:generatePackagesNumbersXV1 xmlns:ns2="http://dpdservices.dpd.com.pl/">'+LineEnding+
  '  <openUMLXV1>'+Temp+'</openUMLXV1>'+LineEnding+
  '  <pkgNumsGenerationPolicyV1>STOP_ON_FIRST_ERROR</pkgNumsGenerationPolicyV1>'+LineEnding+
  '  <authDataV1>'+LineEnding+
  '   <login>'+AuthData.Login+'</login>'+LineEnding+
  '   <masterFid>'+AuthData.MasterFid+'</masterFid>'+LineEnding+
  '   <password>'+AuthData.Passwd+'</password>'+LineEnding+
  '  </authDataV1>'+LineEnding+
  '  </ns2:generatePackagesNumbersXV1>'+LineEnding+
  '</S:Body>'+LineEnding+
  '</S:Envelope>';

  WriteToLog('');
  WriteToLog(UTF8PadRight('GeneratePackagesNumbersXV1',40)+':XML');
  WriteToLog('');
  WriteToLog(XML);
  WriteToLog('');

  if not Make_WS(XML) then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);
  WriteToLog('');

  if not Parse_XML(XML,'return') then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);
  WriteToLog('');

  Temp:=DecodeBase64(XML);

  WriteToLog(Temp);
  WriteToLog('');

  //SessionId
  if not Parse_XML(Temp,'SessionId') then
    begin
      Result:=False;
      Exit;
    end;
  WriteToLog(UTF8PadRight('SessionId',40)+':'+Temp);
  WriteToLog('');
  SessionId:=Temp;

  //Waybills
  Temp:=DecodeBase64(XML);

  if not Parse_XML(Temp,'Waybill') then
    begin
      Result:=False;
      Exit;
    end;

  WayBills:=TStringList.Create;
  WayBills.SetText(PChar(Temp));

  For Loop:=0 to WayBills.Count-1 do
    begin
      WriteToLog(UTF8PadRight('WayBill',40)+':'+WayBills[Loop]);
      Parcels.Items[Loop].Waybill:=WayBills[Loop];
    end;

  WayBills.Free;

  Result:=True;
end;

function TDPD.GenerateSpedLabelsXV1:boolean;
Var      I_XML               :AnsiString;
         XML                 :AnsiString;
         Temp                :AnsiString;
         Path                :String;
         File_Name           :String;
         T                   :TStringStream;
         fsOut               :TFileStream;

begin
  Result:=True;

  I_XML:=
  '<DPDServicesParamsV1>'+LineEnding+
  '<Policy>STOP_ON_FIRST_ERROR</Policy>'+LineEnding+
  '<Session>'+LineEnding+
  '  <SessionType>DOMESTIC</SessionType>'+LineEnding+
  '  <SessionId>'+SessionId+'</SessionId>'+LineEnding+
  '</Session>'+LineEnding+
  '</DPDServicesParamsV1>';

  Temp:=EncodeBase64(I_XML);

  XML:=
  '<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">'+LineEnding+
  '  <S:Header/>'+LineEnding+
  '  <S:Body>'+LineEnding+
  '  <ns2:generateSpedLabelsXV1 xmlns:ns2="http://dpdservices.dpd.com.pl/">'+LineEnding+
  '  <dpdServicesParamsXV1>'+Temp+'</dpdServicesParamsXV1>'+LineEnding+
  '  <outputDocFormatV1>PDF</outputDocFormatV1>'+LineEnding+
  '  <outputDocPageFormatV1>A4</outputDocPageFormatV1>'+LineEnding+
  '  <authDataV1>'+LineEnding+
  '   <login>'+AuthData.Login+'</login>'+LineEnding+
  '   <masterFid>'+AuthData.MasterFid+'</masterFid>'+LineEnding+
  '   <password>'+AuthData.Passwd+'</password>'+LineEnding+
  '  </authDataV1>'+LineEnding+
  '  </ns2:generateSpedLabelsXV1>'+LineEnding+
  '  </S:Body>'+LineEnding+
  '</S:Envelope>';

  WriteToLog('');
  WriteToLog(UTF8PadRight('generateSpedLabelsXV1',40)+':XML');
  WriteToLog('');
  WriteToLog(XML);

  if not Make_WS(XML) then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);
  WriteToLog('');

  if not Parse_XML(XML,'return') then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);
  WriteToLog('');

  XML:=DecodeBase64(XML);

  WriteToLog(XML);
  WriteToLog('');

  if not Parse_XML(XML,'DocumentData') then
    begin
      Result:=False;
      Exit;
    end;

  XML:=DecodeBase64(XML);

  Path:=GetCurrentDirUTF8+PathDelim+'temp';
  ForceDirectoriesUTF8(Path);
  File_Name:=Path+PathDelim+'SpeedLabels'+'_'+TkDate+'_'+TkTime+'_'+StringReplace(Receiver.City, '', '_',[rfReplaceAll, rfIgnoreCase])+'.pdf';
  pdf_SpeedLabels:=File_name;
  T:=TStringStream.Create(XML);
  fsOut:=TFileStream.Create( File_Name, fmCreate);
  fsOut.CopyFrom(T,T.Size);
  FsOut.Free;
  T.Free;

  Result:=True;
end;

function TDPD.generateProtocolXV1:boolean;
Var      I_XML               :AnsiString;
         XML                 :AnsiString;
         Temp                :AnsiString;
         Path                :String;
         File_Name           :String;
         T                   :TStringStream;
         fsOut               :TFileStream;

begin
  Result:=True;

  I_XML:=
  '<DPDServicesParamsV1>'+LineEnding+
  '<Policy>IGNORE_ERRORS</Policy>'+LineEnding+
  ' <PickupAddress>'+LineEnding+
  '   <Company>'+Sender.Company+'</Company>'+LineEnding+
  '   <Name>'+Sender.Name+'</Name>'+LineEnding+
  '   <Address>'+Sender.Address+'</Address>'+LineEnding+
  '   <City>'+Sender.City+'</City>'+LineEnding+
  '   <CountryCode>'+Sender.CountryCode+'</CountryCode>'+LineEnding+
  '   <PostalCode>'+Sender.PostalCode+'</PostalCode>'+LineEnding+
  '   <Phone>'+Sender.Phone+'</Phone>'+LineEnding+
  '   <Email>'+Sender.Email+'</Email>'+LineEnding+
  '  </PickupAddress>'+LineEnding+
  '  <Session>'+LineEnding+
  '    <SessionType>DOMESTIC</SessionType>'+LineEnding+
  '    <SessionId>'+SessionId+'</SessionId>'+LineEnding+
  '  </Session>'+LineEnding+
  '</DPDServicesParamsV1>';

  Temp:=EncodeBase64(I_XML);

  XML:=
  '<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">'+LineEnding+
  '  <S:Header/>'+LineEnding+
  '  <S:Body>'+LineEnding+
  '  <ns2:generateProtocolXV1 xmlns:ns2="http://dpdservices.dpd.com.pl/">'+LineEnding+
  '  <dpdServicesParamsCV1>'+Temp+'</dpdServicesParamsCV1>'+LineEnding+
  '  <outputDocFormatV1>PDF</outputDocFormatV1>'+LineEnding+
  '  <outputDocPageFormatV1>A4</outputDocPageFormatV1>'+LineEnding+
  '  <authDataV1>'+LineEnding+
  '   <login>'+AuthData.Login+'</login>'+LineEnding+
  '   <masterFid>'+AuthData.MasterFid+'</masterFid>'+LineEnding+
  '   <password>'+AuthData.Passwd+'</password>'+LineEnding+
  '  </authDataV1>'+LineEnding+
  '  </ns2:generateProtocolXV1>'+LineEnding+
  '  </S:Body>'+LineEnding+
  '</S:Envelope>';

  WriteToLog('');
  WriteToLog(UTF8PadRight('generateProtocolXV1',40)+':XML');
  WriteToLog('');
  WriteToLog(XML);

  if not Make_WS(XML) then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);
  WriteToLog('');

  if not Parse_XML(XML,'return') then
    begin
      Result:=False;
      Exit;
    end;

  WriteToLog(XML);
  WriteToLog('');

  XML:=DecodeBase64(XML);

  WriteToLog(XML);
  WriteToLog('');

  if not Parse_XML(XML,'DocumentData') then
    begin
      Result:=False;
      Exit;
    end;

  XML:=DecodeBase64(XML);

  Path:=GetCurrentDirUTF8+PathDelim+'temp';
  ForceDirectoriesUTF8(Path);
  File_Name:=Path+PathDelim+'Protocol'+'_'+TkDate+'_'+TkTime+'_'+StringReplace(Receiver.City, '', '_',[rfReplaceAll, rfIgnoreCase])+'.pdf';
  pdf_protocol:=File_name;
  T:=TStringStream.Create(XML);
  fsOut:=TFileStream.Create( File_Name, fmCreate);
  fsOut.CopyFrom(T,T.Size);
  FsOut.Free;
  T.Free;

  Result:=True;
end;


function TDPD.TKDate:String;
begin
  TKDate:=FormatDateTime('yyyy-mm-dd',Date);
end;

function TDPD.TKTime:String;
begin
  TKTime:=FormatDateTime('hh-mm-ss',Now);
end;

procedure TDPD.WriteToLog(Value:AnsiString);
begin
  if Log Then WriteLn(Log_File,Value);
end;

destructor TDPD.Destroy;
begin
  if Log then
    begin
      CloseFile(Log_File)
    end;

  Parcels.Free;
  inherited Destroy;
end;

initialization

end.

