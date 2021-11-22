unit Unit_pub;

interface

uses messages;

const
  wm_resetThread = wm_user + 1026;

type
  TLocalsetup = record

    logsLevel: integer;

    showlog: boolean;
    showlevel: integer;
  end;

  TServerSetup = record
    Server: string;
    UserName: String;
    Password: String;
    dbname: String;
    ProcName: String;
  end;

var
  localsetup: TLocalsetup;
  ServerSetup: TServerSetup;

var
  successcount: integer;
  AppLicationClose: boolean = false;

procedure loadLocalsetup();

implementation

uses inifiles, mu.fileinfo;

procedure loadLocalsetup();
var
  inf: TIniFile;
begin
  inf := TIniFile.Create(getexepath + 'config\config.ini');
  try

    localsetup.showlog := inf.ReadBool('logs', 'showlog', true);
    localsetup.logsLevel := inf.ReadInteger('logs', 'logsLevel', 5);
    localsetup.showlevel := inf.ReadInteger('logs', 'showlevel', 9);



  finally
    inf.Free;
  end;
end;

initialization

successcount := 0;
loadLocalsetup();

finalization

end.
