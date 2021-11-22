program mpkg;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  SysUtils,
  system.Console,
  Mu.Console.Params,
  EasyConsole.Input,
  EasyConsole.Output,
  EasyConsole.Types,
  MFP.Types, Mu.AnsiStr,
  MFP.Utils,
  MFP.Cmd in '..\Unit\MFP.Cmd.pas',
  MFP.HashSearch in '..\Unit\MFP.HashSearch.pas';

{$R *.res}

var
  Cmd: TMCmd;
  s  : String;
  c  : TMAChar;

begin

  Cmd := GetParams;
  if Cmd.Cmd <> '' then
  begin
    Console.WriteLine(Cmd.Cmd);
    if Cmd.Cmd = 'package' then
      PackageCmd(Cmd)
    else if Cmd.Cmd = 'rebuild' then
      RebuildCmd(Cmd)
    else if Cmd.Cmd = 'export' then
      ExportCmd(Cmd);
  end else begin
    while true do
    begin
      s := Input.ReadString('input command:');
      Cmd.parse(s);
      if Cmd.Cmd = 'package' then
        PackageCmd(Cmd)
      else if Cmd.Cmd = 'rebuild' then
        RebuildCmd(Cmd)
      else if Cmd.Cmd = 'export' then
        ExportCmd(Cmd)
      else if Cmd.Cmd = 'expfilename' then
        ExportFileNameCmd(Cmd)
      else if Cmd.Cmd = 'quit' then
        break;
    end;
  end;

end.
