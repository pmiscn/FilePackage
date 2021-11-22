unit unit_Login;

interface

uses
  winapi.Windows, Messages, SysUtils, Variants, Classes,
  Mu.Pool.QJson, db, adodb, // unit_db,
  Mu.ShareMemory, System.Hash, unit_Encry, QJson;

var
  // LoginUserID: String = '';
  publicVars: TQJson;
  UserSession: TQJson;
  SessionTimeOutHour: Integer = 4;
  LoginUserRoleID: Integer = -1; // 0 1 2

type

  TServerStatus = record
    DBServer: Integer;
    FileServer: Integer;
    HttpServer: Integer;
    EncodeServer: Integer;
  end;

  TShortString = String[255];

  TUserInfo = record
    UserNO: TShortString;
    UserName: TShortString;
    PassWord: TShortString;
    SessionID: TShortString;
    Role: TShortString;
    Level: Integer;
    // Referer: TShortString;
  end;

  // 给http用的
  TLogin = Record
  public
    class function Login(aUID, aPwd, aReferer, aIP: String; var aName: String;
      var aSID: String): String; static;
    class function changpwd(aUID, aPwd, apwdnew, aReferer, aIP: String)
      : String; static;

    class function Logout(assid, aUID: String): String; static;
    class function GetNowUserLevel: Integer; static;
    class function getSid(aUID, aReferer: String): String; static;
    class function getUidBySid(aSID: String): String; static;
    class function LoginUid(): String; static;

    class procedure ClearTimeoutSession(); static;
  end;

type
  TLoginFuc = function(aCheckServer: Cardinal; loginRole: Pchar)
    : Integer; stdcall;

var
  userinfo: TUserInfo;
  FLoginInfo: TMuShareMem<TUserInfo>;
  ServerConfig: TQJson;
function LoadUserInfoFromMM(var ui: TUserInfo): bool;
function SaveUserInfoToMM(ui: TUserInfo): bool;

function ShareLogin(aCheckServer: Cardinal; loginRole: string): Integer;

implementation

uses math, mu.fileinfo, Mu.DBHelp, dateutils;

function LoadUserInfoFromMM(var ui: TUserInfo): bool;
begin
  Result := false;
  ui := FLoginInfo.getValue();
  if ui.UserNO <> '' then
  begin
    ui.UserNO := TDEncry.Dencry(ui.UserNO);
    ui.UserName := TDEncry.Dencry(ui.UserName);
    ui.PassWord := TDEncry.Dencry(ui.PassWord);
    ui.SessionID := TDEncry.Dencry(ui.SessionID);
    ui.Role := TDEncry.Dencry(ui.Role);
    Result := true;
  end;
end;

function SaveUserInfoToMM(ui: TUserInfo): bool;
begin
  Result := false;
  if ui.UserNO <> '' then
  begin
    ui.UserNO := TDEncry.Encry(ui.UserNO);
    ui.UserName := TDEncry.Encry(ui.UserName);
    ui.PassWord := TDEncry.Encry(ui.PassWord);
    ui.SessionID := TDEncry.Encry(ui.SessionID);
    ui.Role := TDEncry.Encry(ui.Role);
  end;
  FLoginInfo.setValue(ui);
  Result := true;
end;

function ShareLogin(aCheckServer: Cardinal; loginRole: string): Integer;
var
  Hnd: THandle;
  fn: String;
  loginfunc: TLoginFuc;
  i: Integer;
begin

  Result := 0;
  if LoadUserInfoFromMM(userinfo) then
  begin
    if userinfo.Role = loginRole then
    begin
      Result := 1;
      publicVars.ForcePath('LoginUserID').AsString :=
        unit_Login.userinfo.UserNO;
      exit;
    end;
  end;

  fn := extractfilepath(paramstr(0)) + 'login.dll';
  if not fileExists(fn) then
  begin
    messagebox(0, Pchar('登录模块' + fn + '没有找到，请重新安装程序！'), '错误', MB_ICONERROR);
    exit;
  end;
  Hnd := LoadLibrary(Pchar(fn));

  if Hnd > 32 then
  begin
    try
      @loginfunc := GetProcAddress(Hnd, 'dologin');
      if Assigned(@loginfunc) then
      begin
        i := loginfunc(aCheckServer, Pchar(loginRole));
        if i > 0 then
        begin
          // 一定要在dll释放之前，读取信息。
          if LoadUserInfoFromMM(userinfo) then
            publicVars.ForcePath('LoginUserID').AsString :=
              unit_Login.userinfo.UserNO;
        end;
        Result := i;
      end;
    finally
      FreeLibrary(Hnd);
    end;
  end
  else
    RaiseLastOSError;
end;

{ TLogin }
function newSID(): String;
var
  s: String;
begin
  Result := formatdatetime('yymmddhhmmss', now());
  Result := Result + math.RandomRange(1000000, 9999999).tostring;

end;

class function TLogin.LoginUid: String;
begin

  Result := publicVars.ValueByName('LoginUserID', '');

end;

class function TLogin.Logout(assid, aUID: String): String;
var
  i: Integer;
begin
  if assid <> '' then
  begin
    UserSession.Delete(assid);
  end
  else
  begin
    for i := UserSession.count - 1 downto 0 do
    begin
      if (UserSession[i].ValueByName('UID', '') = aUID) then
        UserSession.Delete(i);
    end;
  end;
  Result := 'true';
end;

class function TLogin.changpwd(aUID, aPwd, apwdnew, aReferer,
  aIP: String): String;
var
  lv: Integer;
  ADOConnection1: TADOConnection;
  proc: TADOStoredProc;
begin
  Result := '';
  ADOConnection1 := TADOConnection.Create(nil);
  //

  try
    ADOConnection1.ConnectionString :=
      format('Provider=SQLOLEDB.1;Password=%s;Persist Security Info=True;User ID=%s;Initial Catalog=%s;Data Source=%s',
      [ServerConfig.ItemByPath('Server.Password').AsString,
      ServerConfig.ItemByPath('Server.Username').AsString,
      ServerConfig.ItemByPath('Server.Database').AsString,
      ServerConfig.ItemByPath('Server.Server').AsString]);

    // ADOConnection1.ConnectionString := 'FILE NAME=' + getexepath + 'dB.UDL';
    try
      ADOConnection1.Open;
    except
      on e: Exception do
      begin
        messagebox(0, Pchar('本地数据库连接错误。' + #13#10 + e.Message), '错误',
          MB_ICONERROR);
        exit;
      end;
    end;
    proc := TADOStoredProc.Create(nil);
    proc.Connection := ADOConnection1;
    proc.ProcedureName := 'P_Users_Pwd_reset';
    // proc.Prepared := true;

    if length(aPwd) <> 32 then
      aPwd := THashMD5.GetHashString(aPwd);

    with proc.Parameters.AddParameter do
    begin
      Name := '@RETURN_VALUE';
      DataType := ftInteger;
      Direction := pdReturnValue;
      value := 0;
    end;

    with proc.Parameters.AddParameter do
    begin
      Name := '@UserID';
      DataType := ftString;
      Direction := pdInput;
      size := 50;
      value := aUID;
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@Password';
      DataType := ftString;
      Direction := pdInput;
      size := 100;
      value := aPwd;
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@@Pwd_New';
      DataType := ftString;
      Direction := pdInput;
      size := 100;
      value := apwdnew;
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@Referer';
      DataType := ftString;
      Direction := pdInput;
      size := 200;
      value := '';
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@IP';
      DataType := ftString;
      Direction := pdInput;
      size := 100;
      value := aIP;
    end;

    with proc.Parameters.AddParameter do
    begin
      Name := '@Result';
      DataType := ftString;
      Direction := pdInputOutput;
      size := 1000;
      value := '';
    end;

    { proc.Parameters.ParamByName('@UserID').Value := aUID;
      proc.Parameters.ParamByName('@Password').Value := aPwd;
      proc.Parameters.ParamByName('@aReferer').Value := '';
      proc.Parameters.ParamByName('@aIP').Value := aIP;
    }
    try
      proc.ExecProc;

      Result := proc.Parameters.ParamByName('@Result').value;
      // if Result <> 'true' then

    except

    end;
    { @UserID VARCHAR(50),
      @Password VARCHAR(100),
      @Referer VARCHAR(200),
      @IP VARCHAR(100),
      @UserName NVARCHAR(100) OUTPUT,
      @Result NVARCHAR(1000) OUTPUT }
  finally
    proc.Free;
    ADOConnection1.Free;
  end;

end;

class procedure TLogin.ClearTimeoutSession;
var
  ajs, js: TQJson;
  i: Integer;
begin
  // for ajs in UserSession do
  for i := UserSession.count - 1 downto 0 do
  begin
    if (UserSession[i].DateTimeByName('Time', 0) < now() - OneHour *
      SessionTimeOutHour) then
      UserSession.Delete(i);
  end
end;

class function TLogin.GetNowUserLevel: Integer;
var
  vs, rs: String;
  js, jsd: TQJson;
begin
  Result := 0;

end;

class function TLogin.getSid(aUID, aReferer: String): String;
var
  ajs, js: TQJson;
  sid: String;
  i: Integer;
begin
  // {
  // sid :{UID:"",Time:"",Referer:""}
  // }
  sid := newSID();
  for i := UserSession.count - 1 downto 0 do
  begin
    if (UserSession[i].ValueByName('UID', '') = aUID) then
      UserSession.Delete(i);
  end;

  if UserSession.HasChild(sid, ajs) then
  begin
    // 超过4个小时的，都删除了。
    // for js in ajs do
    if (ajs.DateTimeByName('Time', 0) < now() - OneHour * SessionTimeOutHour)
    then
      ajs.Delete();
  end
  else
  begin
    ajs := UserSession.Add(sid);
  end;

  with ajs do
  begin
    Add('UID').AsString := aUID;
    Add('Time').AsDateTime := now();
    Add('Referer').AsString := aReferer;
  end;
  Result := sid;
end;

class function TLogin.getUidBySid(aSID: String): String;
var
  ajs: TQJson;
begin
  Result := '';
  if UserSession.HasChild(aSID, ajs) then
  begin
    Result := ajs.ValueByName('UID', '');
  end
end;

class function TLogin.Login(aUID, aPwd, aReferer, aIP: String;
  var aName: String; var aSID: String): String;
var
  lv: Integer;
  ADOConnection1: TADOConnection;
  proc: TADOStoredProc;
begin
  Result := '';
  aSID := '';
  ADOConnection1 := TADOConnection.Create(nil);

  try
    // ADOConnection1.ConnectionString := 'FILE NAME=' + getexepath + 'dB.UDL';
    ADOConnection1.ConnectionString :=
      format('Provider=SQLOLEDB.1;Password=%s;Persist Security Info=True;User ID=%s;Initial Catalog=%s;Data Source=%s',
      [ServerConfig.ItemByPath('Server.Password').AsString,
      ServerConfig.ItemByPath('Server.Username').AsString,
      ServerConfig.ItemByPath('Server.Database').AsString,
      ServerConfig.ItemByPath('Server.Server').AsString]);
    try
      ADOConnection1.Open;
    except
      on e: Exception do
      begin
        messagebox(0, Pchar('本地数据库连接错误。' + #13#10 + e.Message), '错误',
          MB_ICONERROR);
        exit;
      end;
    end;
    proc := TADOStoredProc.Create(nil);
    proc.Connection := ADOConnection1;
    proc.ProcedureName := 'P_Users_login';
    // proc.Prepared := true;

    if length(aPwd) <> 32 then
      aPwd := THashMD5.GetHashString(aPwd);

    with proc.Parameters.AddParameter do
    begin
      Name := '@RETURN_VALUE';
      DataType := ftInteger;
      Direction := pdReturnValue;
      value := 0;
    end;

    with proc.Parameters.AddParameter do
    begin
      Name := '@UserID';
      DataType := ftString;
      Direction := pdInput;
      size := 50;
      value := aUID;
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@Password';
      DataType := ftString;
      Direction := pdInput;
      size := 100;
      value := aPwd;
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@Referer';
      DataType := ftString;
      Direction := pdInput;
      size := 200;
      value := '';
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@IP';
      DataType := ftString;
      Direction := pdInput;
      size := 100;
      value := aIP;
    end;

    with proc.Parameters.AddParameter do
    begin
      Name := '@UserName';
      DataType := ftString;
      Direction := pdInputOutput;
      size := 100;
      value := '';
    end;
    with proc.Parameters.AddParameter do
    begin
      Name := '@Result';
      DataType := ftString;
      Direction := pdInputOutput;
      size := 1000;
      value := '';
    end;

    { proc.Parameters.ParamByName('@UserID').Value := aUID;
      proc.Parameters.ParamByName('@Password').Value := aPwd;
      proc.Parameters.ParamByName('@aReferer').Value := '';
      proc.Parameters.ParamByName('@aIP').Value := aIP;
    }
    try
      proc.ExecProc;

      Result := proc.Parameters.ParamByName('@Result').value;
      aName := proc.Parameters.ParamByName('@UserName').value;
      // if Result <> 'true' then

    except
      on e: Exception do
        Result := e.Message;
    end;
    { @UserID VARCHAR(50),
      @Password VARCHAR(100),
      @Referer VARCHAR(200),
      @IP VARCHAR(100),
      @UserName NVARCHAR(100) OUTPUT,
      @Result NVARCHAR(1000) OUTPUT }
  finally
    proc.Free;
    ADOConnection1.Free;
  end;
end;

initialization

publicVars := TQJson.Create;
publicVars.ForcePath('LoginUserID').AsString := 'amu';
UserSession := TQJson.Create;

FLoginInfo := TMuShareMem<TUserInfo>.Create('PangchengIMEILoginUser');

ServerConfig := TQJson.Create;
if fileExists(getexepath + 'config\msdb.json') then
  ServerConfig.LoadFromFile(getexepath + 'config\msdb.json');

finalization

publicVars.Free;
UserSession.Free;
FLoginInfo.Free;
ServerConfig.Free;

end.
