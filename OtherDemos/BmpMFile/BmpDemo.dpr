program BmpDemo;

uses
  Forms,
  BmpDemoUnit in 'BmpDemoUnit.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
