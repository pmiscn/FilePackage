unit Unit_logs;

interface

uses
  Windows, Messages, SysUtils, // uConsoleClass, Unit_Console_Ext,
  Variants, Classes, SyncObjs, Generics.Collections,
  // unit_public,

  qlog;

type

  TStatusValue = record
    StatusStr: String;
    StatusID: Integer;
  end;

  TMLog = class
    protected
      FIndex: Integer;
      Fmark : String;
    public
      procedure log(s: String; l: Integer = 9); overload;
      procedure log(s: String; p: array of const; l: Integer = 9); overload;
      procedure log(ll: TQLogLevel; s: String; p: array of const); overload;
      procedure log(ll: TQLogLevel; s: String); overload;

      property index: Integer read FIndex write FIndex default -1;
      property mark: String read Fmark write Fmark;
  end;

procedure public_addLogs(s: string; level: Integer = 0);
procedure addLogs(s: string; level: Integer = 0); overload;
procedure addLogs(s: string; p: Array of const; level: Integer = 0); overload;

// var
// pubLogLevel: Integer = 9;

implementation

uses unit_pub, mu.fileinfo;

procedure addLogs(s: string; p: Array of const; level: Integer = 0);
begin
  public_addLogs(format(s, p), level);
end;

procedure addLogs(s: string; level: Integer = 0);
begin
  public_addLogs(s, level);
end;
{
  procedure public_addLogs(s: string; level: Integer = 0);
  begin
  if localsetup.showlog or (level <= 0) then
  begin
  writeln(formatdatetime('hh:mm:ss', now()) + '  ' + s);
  logs.Post();
  end;
  end;
}

procedure public_addLogs(s: string; level: Integer = 0);
var
  ll: TQLogLevel;
begin
  if localsetup.showlevel >= level then
    if localsetup.showlog or (level <= 0) then
    begin
      try
        writeln(formatdatetime('hh:mm:ss', now()) + '  ' + s);
      except
      end;
    end;

  if localsetup.logsLevel < level then
    exit;
  case level of
    9:
      ll := lldebug;
    8:
      ll := lldebug;
    7:
      ll := llMessage;
    6:
      ll := llMessage;
    5:
      ll := llHint;
    4:
      ll := llWarning;
    3:
      ll := llError;
    2:
      ll := llFatal;
    1:
      ll := llAlert;
    0:
      ll := llError;
  end;
  logs.Post(ll, s);
end;

{ TMLog }

procedure TMLog.log(s: String; p: array of const; l: Integer);
begin
  try
    log(format(s, p), l);
  except
  end;
end;

procedure TMLog.log(s: String; l: Integer);
  function ls(ss: String): string;
  begin
    while length(ss) < 3 do
      ss   := ' ' + ss;
    result := ss;
  end;

begin
  if FIndex >= 0 then
  begin
    if self.Fmark <> '' then
      addLogs(format('%s %3d %s', [self.Fmark, self.index, s]), l)
    else
      addLogs(format('%s %s', [self.Fmark, s]), l);
  end else begin
    if self.Fmark <> '' then
      addLogs(self.Fmark + ' ' + s, l)
    else
      addLogs(s, l);
  end;
end;

function qlevel2level(ll: TQLogLevel): Integer;
var
  level: Integer;
begin
  case ll of
    lldebug:
      level := 8;
    llMessage:
      level := 7;
    llHint:
      level := 5;
    llWarning:
      level := 4;
    llFatal:
      level := 2;
    llAlert:
      level := 1;
    llError:
      level := 0;
  end;
  result := level;
end;

procedure TMLog.log(ll: TQLogLevel; s: String);
begin
  log(s, qlevel2level(ll));
end;

procedure TMLog.log(ll: TQLogLevel; s: String; p: array of const);
begin
  log(s, p, qlevel2level(ll));
end;

initialization

qlog.SetDefaultLogFile(getexepath() + 'logs\log.log', 20000000);

finalization

end.
