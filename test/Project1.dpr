program Project1;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  MFP.Types in '..\Unit\MFP.Types.pas',
  MFP.Package in '..\Unit\MFP.Package.pas',
  Mu.Crc in '..\Unit\Mu.Crc.pas',
  frmCrud in 'frmCrud.pas' {Form2},
  MFP.Index in '..\Unit\MFP.Index.pas',
  MFP.Files in '..\Unit\MFP.Files.pas',
  MFP.Index.hash in '..\Unit\MFP.Index.hash.pas',
  MFP.Index.rbtree in '..\Unit\MFP.Index.rbtree.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
 Application.CreateForm(TForm1, Form1);
 //  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
