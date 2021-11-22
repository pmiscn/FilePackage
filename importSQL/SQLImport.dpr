program SQLImport;

uses
  Vcl.Forms,
  FrmSqlImport in 'FrmSqlImport.pas' {FSQLImport},
  MFP.importSQL in 'MFP.importSQL.pas',
  Mu.TimerTask in 'Mu.TimerTask.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFSQLImport, FSQLImport);
  Application.Run;
end.
