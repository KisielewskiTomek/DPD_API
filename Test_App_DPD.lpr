program Test_App_DPD;

{$mode objfpc}{$H+}

uses
  Classes, dpd;


var      My_DPD              :TDPD;
         MyParcel            :TParcel;
         Loop                :Integer;


begin
  My_DPD:=TDPD.Create(True);

  //AuthData
  My_DPD.AuthData.Login:='test';
  My_DPD.AuthData.Passwd:='thetu4Ee';
  My_DPD.AuthData.MasterFid:='1495';

  //Parcel 1
  MyParcel.SizeX:=20;
  MyParcel.SizeY:=30;
  MyParcel.SizeZ:=11;
  MyParcel.Weight:=1;
  MyParcel.Content:='';
  MyParcel.Cust_Data1:='';
  My_DPD.Parcels.Add(MyParcel);

  //Parcel 2
  MyParcel.SizeX:=20;
  MyParcel.SizeY:=21;
  MyParcel.SizeZ:=22;
  MyParcel.Weight:=1.2;
  MyParcel.Content:='Content 2';
  MyParcel.Cust_Data1:='Customer Data 2';
  My_DPD.Parcels.Add(MyParcel);

  //Receiver
  My_DPD.Receiver.Company:='Firma';
  My_DPD.Receiver.Name:='Jan Kowalski';
  My_DPD.Receiver.Address:='Żmigrodzka 41/49';
  My_DPD.Receiver.City:='Poznań';
  My_DPD.Receiver.PostalCode:='60171';
  My_DPD.Receiver.CountryCode:='PL';
  My_DPD.Receiver.Email:='';
  My_DPD.Receiver.Phone:='';

  //Sender
  My_DPD.Sender.Company:='ABC';
  My_DPD.Sender.Name:='Tomasz Kisielewski';
  My_DPD.Sender.Address:='Niciarniana 51/53';
  My_DPD.Sender.City:='Łódź';
  My_DPD.Sender.PostalCode:='92320';
  My_DPD.Sender.CountryCode:='PL';
  My_DPD.Sender.Email:='kisielewski.tomek@gmail.com';
  My_DPD.Sender.Phone:='22445566';

  My_DPD.Ref.Ref1:='2132097081';
  My_DPD.Ref.Ref2:='';
  My_DPD.Ref.Ref3:='';

  Writeln(My_DPD.Run);


  For Loop:=0 to My_DPD.Parcels.Count-1 do
    begin
      Writeln(My_DPD.Parcels.Items[Loop].Waybill);
    end;
  Writeln(My_DPD.PDF_SpeedLabels);
  Writeln(My_DPD.PDF_Protocol);

  My_DPD.PickupDate:='2018-02-08';
  My_DPD.PickupTimeFrom:='10';
  My_DPD.PickupTimeTo:='18';
  if My_DPD.PackagesPickupCallXV2 then
    Writeln(My_DPD.OrderNumber+' '+My_DPD.Status)
    else
    Writeln(My_DPD.Status);


  My_DPD.Free;
end.
