unit unit_DB;

interface

uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys.MSSQL, FireDAC.Moni.RemoteClient,
  FireDAC.Phys, FireDAC.Stan.Intf,
  FireDAC.Stan.ExprFuncs, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, FireDAC.Comp.Client, Data.DB, FireDAC.Comp.DataSet,
  Mu.DBhelp,
  qmacros, qjson, qstring, Mu.Pool.qjson, qrbtree, Mu.MSSQL.Exec;

var
  DBServerConfig: TQjson;
  FMuMSSQLExec: TMuMSSQLExec;
  // FSQLDBHelp: TSQLDBHelp;

type
  TCmdReturn = record
    ReturnCode: integer;
    Result: String;
    Error: String;
  public
    class function create(rc: integer; rs, err: String): TCmdReturn; static;
  end;

  TDB = class
  public

    class function getErrorInfoFromResponseStr(ResStr: String): string; static;
    class function getErrorInfoFromResponseJson(respjs: TQjson): string; static;
    class function getResultFromResponseStr(ResStr: String): TCmdReturn; static;

    class function getResponseJson(ResponseStr: String; aResJson: TQjson)
      : boolean; overload; static;
    class function getResponseJson(ResponseStr: String; aResJson: TQjson;
      var Errstr: String): boolean; overload; static;
    class procedure initRequestJson(ajs: TQjson); static;
    class procedure SetRequestJsonValue(cmdjs, Vjs: TQjson); static;
    class procedure ResponseJsonToStrings(aReq: TQjson; Fields: String;
      rs: TStrings);
    class procedure RequestToStrings(aReq: TQjson; Fields: String;
      rs: TStrings);

    class function getconn: TFDConnection;
    class procedure retrunconn(aConn: TFDConnection);
    class function Exec(aReqParams: TQjson): String; overload;
    class function Exec(aType, aSql: String; aValue: TQjson): String; overload;
    class function Exec(aType, aSql, aValue: String): String; overload;

    class function Exec(aConfig: TQjson; aType, aSql: String; aValue: TQjson)
      : String; overload;
    class function Exec(aConfig: TQjson; aValue: TQjson): String; overload;
  end;

implementation

uses mu.fileinfo , unit_login;

function loadconfig(): boolean;
var
  fn: String;
begin
  DBServerConfig := TQjson.create;
  fn := getexepath + 'config\msdb.json';
  if fileexists(fn) then
    DBServerConfig.LoadFromFile(fn);
end;

class function TDB.getErrorInfoFromResponseJson(respjs: TQjson): string;
var
  ejs: TQjson;
  es, s: String;
  i: integer;

  function isErrResult(rs: String; var es: String): boolean;
  var
    js, ejs: TQjson;
  begin
    Result := false;
    rs := trim(rs);
    es := '';

    if rs.Length > 0 then
    begin
      if rs[1] in ['{', '['] then
      begin

        js := TQjson.create;
        try
          if js.TryParse(rs) then
          begin
            if js.HasChild('Error', ejs) then
            begin
              es := ejs.AsString;
              exit(true);
            end;
            if js.HasChild('ERROR', ejs) then
            begin
              es := ejs.AsString;
              exit(true);
            end;
          end
          else
            messagebox(0, pchar(rs), 'Error', 0);
        finally
          js.Free;
        end;
      end;
    end;
    if copy(rs, 1, 5).ToUpper() = 'ERROR' then
    begin
      es := rs;
      exit(true);
    end;
  end;

begin

  if respjs.HasChild('Error', ejs) then
  begin
    exit(ejs.ToString);
  end
  else
  begin
    if respjs.HasChild('Error', ejs) then
    begin
      exit(ejs.ToString);
    end
    else if respjs.HasChild('@Result', ejs) then
    begin
      s := ejs.ToString;

      if Length(s) > 5 then
      begin
        if isErrResult(s, es) then
          exit(es);
      end;
    end;
    if respjs.Count > 0 then
    begin
      if respjs[0].HasChild('Error', ejs) then
      begin
        exit(ejs.ToString);
      end
      else if respjs[0].HasChild('@Result', ejs) then
      begin
        s := ejs.ToString;
        if Length(s) > 5 then
        begin
          if isErrResult(s, es) then
            exit(es);

        end;
      end;
    end;
  end;
end;

class function TDB.getErrorInfoFromResponseStr(ResStr: String): string;
var
  respjs, rpjs, ejs: TQjson;
  s: String;
  i: integer;
begin
  Result := '';
  if ResStr = '' then
    exit;
  respjs := qjsonpool.get;
  try
    respjs.parse(ResStr);
    Result := TDB.getErrorInfoFromResponseJson(respjs);
  finally
    // respjs.Free;
    qjsonpool.return(respjs);
  end;
end;

class function TDB.getResponseJson(ResponseStr: String; aResJson: TQjson;
  var Errstr: String): boolean;
var
  resjs, ajs: TQjson;
begin
  Result := true;
  resjs := qjsonpool.get; // TQjson.create;
  Errstr := '';
  try
    resjs.parse(ResponseStr);
    Errstr := TDB.getErrorInfoFromResponseJson(resjs);
    if Errstr <> '' then
    begin
      Result := false;
    end;

    if resjs.HasChild('Response', ajs) then
      aResJson.Assign(ajs)
    else
      aResJson.Assign(resjs);
  finally
    qjsonpool.return(resjs);
    // resjs.Free;
  end;
end;

class function TDB.getResultFromResponseStr(ResStr: string): TCmdReturn;
var
  respjs, rpjs, rjs, ejs: TQjson;
  s: String;
  i: integer;
  function getFromResJson(rpjs: TQjson): TCmdReturn;
  begin

  end;

begin
  Result.ReturnCode := 0;
  Result.Result := '';
  Result.Error := '';
  if ResStr = '' then
    exit;
  rpjs := nil;

  respjs := qjsonpool.get; // TQjson.create; ;
  try
    respjs.parse(ResStr);
    if respjs.HasChild('Error', ejs) then
    begin
      Result.Error := (ejs.ToString);
    end
    else if not respjs.HasChild('Response', rpjs) then

      rpjs := respjs;

    if rpjs.DataType = jdtarray then
      if rpjs.Count > 0 then
      begin
        rpjs := rpjs[0];
      end;

    if rpjs.HasChild('Error', ejs) then
    begin
      Result.Error := (ejs.ToString);
    end
    else
    begin
      if rpjs.HasChild('@Result', ejs) then
      begin
        s := ejs.ToString;
        Result.Result := s;

        if Length(s) > 5 then
        begin
          if copy(s.ToUpper, 1, 5) = 'ERROR' then
          begin
            Result.Error := s;
          end;
        end;
      end;
      if rpjs.HasChild('@RETURN_VALUE', ejs) then
      begin
        Result.ReturnCode := ejs.AsInteger;
      end;
    end;

  finally
    // respjs.Free;
    qjsonpool.return(respjs);
  end;
end;

class function TDB.getResponseJson(ResponseStr: String;
  aResJson: TQjson): boolean;
var
  resjs, ajs: TQjson;
  rs: String;
begin
  Result := true;
  resjs := qjsonpool.get; // TQjson.create;
  try
    rs := getErrorInfoFromResponseStr(ResponseStr);
    if rs <> '' then
    begin
      Result := false;
      // raise exception.CreateFmt('数据库请求时发生错误%s', [rs]);
    end;
    resjs.parse(ResponseStr);
    if resjs.HasChild('Response', ajs) then
      aResJson.Assign(ajs)
    else
      aResJson.Assign(resjs);

  finally
    qjsonpool.return(resjs); // resjs.Free;
  end;

end;

class procedure TDB.initRequestJson(ajs: TQjson);
begin
  ajs.Clear;
  ajs.parse('{Type:"",SQL:"",Value:{}}');
end;

class procedure TDB.SetRequestJsonValue(cmdjs, Vjs: TQjson);
var
  pjs: TQjson;
begin
  if cmdjs.DataType = jdtarray then
    pjs := cmdjs[2]
  else
    pjs := cmdjs.ForcePath('Value');
  pjs.Merge(Vjs, jmmReplace);
end;

class procedure TDB.RequestToStrings(aReq: TQjson; Fields: String;
  rs: TStrings);
var
  s: String;
  js, resjs: TQjson;
begin
  s := TDB.Exec(aReq);

  resjs := qjsonpool.get; // TQjson.create; ;
  try
    if not resjs.TryParse(s) then
    begin
      raise exception.create('错误！无法解析' + #13#10 + s);
      exit;
    end;

    if resjs.HasChild('Response', js) then
    begin
      ResponseJsonToStrings(js, Fields, rs);
    end;
  finally
    qjsonpool.return(resjs);
    // resjs.Free;
  end;

end;

class procedure TDB.ResponseJsonToStrings(aReq: TQjson; Fields: String;
  rs: TStrings);
var
  FMacroMgr: TQMacroManager;
  s: String;
  js: TQjson;
  i: integer;
begin
  FMacroMgr := TQMacroManager.create;
  try
    // if FMacroMgr.Count <> params.Count then
    FMacroMgr.Clear;
    for js in aReq do
    begin
      for i := 0 to js.Count - 1 do
      begin
        FMacroMgr.Push(js[i].Name, js[i].Value);
      end;
      s := FMacroMgr.Replace(Fields, '%', '%', MRF_ENABLE_ESCAPE);
      rs.Add(s);
    end;
  finally
    FMacroMgr.Free;
  end;
end;

{ TDB }
// aReqParams
// {
// SQL:"",
// Type:"",
// Value:{
//
// }
// }

class function TDB.Exec(aReqParams: TQjson): String;

var
  rq, ajson, Vjs, js: TQjson;
  aSql, aType, aErr: String;

begin

  if not aReqParams.HasChild('Request', rq) then
    rq := aReqParams;

  if rq.DataType = jdtarray then
  begin
    aType := rq.Items[0].AsString;
    aSql := rq.Items[1].AsString;
    Vjs := rq.Items[2];
  end
  else
  begin
    aType := rq.Valuebyname('Type', '');
    aSql := rq.Valuebypath('SQL', '');
    Vjs := rq.itembypath('Value');
    if Vjs = nil then
      rq.ForcePath('Value').parse('{}');
    Vjs := rq.itembypath('Value');

  end;
  if aType = '' then
  begin
    exit(('Error:"缺少请求类型！"'));
  end;
  if aSql = '' then
  begin
    exit(('Error:"缺少请求命令！"'));
  end;

  Result := TDB.Exec(aType, aSql, Vjs);

end;

class function TDB.Exec(aType, aSql: String; aValue: TQjson): String;
var
  ajson, js: TQjson;
  aErr: String;
  aV: String;
begin
  ajson := qjsonpool.get;
  try
    ajson.Assign(DBServerConfig);

    ajson.ForcePath('Type').AsString := aType;
    ajson.ForcePath('SQL').AsString := aSql;

    for js in aValue do
    begin
      aV := js.AsString.ToUpper();
      if (aV = uppercase('$$LoginUserID')) or (aV = uppercase('$$UserID')) or
        (aV = uppercase('$LoginUserID')) or (aV = uppercase('$UserID')) then
      begin
        js.AsString := userinfo.UserNO;
      end;
    end;

    Result := FMuMSSQLExec.Exec(ajson, aValue, aErr);

    if aErr <> '' then
    begin

      ajson.parse(Result);
      if ajson.DataType = jdtarray then
      begin
        if ajson.Count > 0 then
          ajson[0].ForcePath('Error').AsString := aErr
        else
          ajson.Add().ForcePath('Error').AsString := aErr;
      end
      else
        ajson.ForcePath('Error').AsString := aErr;
      Result := ajson.ToString();

      // messagebox(0, pchar(Result), '', 0);
    end;
  finally
    qjsonpool.return(ajson);
  end;

end;

class function TDB.Exec(aConfig: TQjson; aType, aSql: String;
  aValue: TQjson): String;
var
  ajson, js: TQjson;
  aErr: String;
  aV: String;
begin
  ajson := qjsonpool.get;
  try
    ajson.Assign(aConfig);

    ajson.ForcePath('Type').AsString := aType;
    ajson.ForcePath('SQL').AsString := aSql;

    for js in aValue do
    begin
      aV := js.AsString.ToUpper();
      if (aV = uppercase('$$LoginUserID')) or (aV = uppercase('$$UserID')) or
        (aV = uppercase('$LoginUserID')) or (aV = uppercase('$UserID')) then
      begin
        js.AsString := userinfo.UserNO;
      end;
    end;

    Result := FMuMSSQLExec.Exec(ajson, aValue, aErr);

    if aErr <> '' then
    begin

      ajson.parse(Result);
      if ajson.DataType = jdtarray then
      begin
        if ajson.Count > 0 then
          ajson[0].ForcePath('Error').AsString := aErr
        else
          ajson.Add().ForcePath('Error').AsString := aErr;
      end
      else
        ajson.ForcePath('Error').AsString := aErr;
      Result := ajson.ToString();

      // messagebox(0, pchar(Result), '', 0);
    end;
  finally
    qjsonpool.return(ajson);
  end;

end;

class function TDB.Exec(aConfig: TQjson; aValue: TQjson): String;
var
  ajson, js: TQjson;
  aErr: String;
  aV: String;
begin
  ajson := qjsonpool.get;
  try
    ajson.Assign(aConfig);
    for js in aValue do
    begin
      aV := js.AsString.ToUpper();
      if (aV = uppercase('$$LoginUserID')) or (aV = uppercase('$$UserID')) or
        (aV = uppercase('$LoginUserID')) or (aV = uppercase('$UserID')) then
      begin
        js.AsString := userinfo.UserNO;
      end;
    end;

    Result := FMuMSSQLExec.Exec(ajson, aValue, aErr);

    if aErr <> '' then
    begin

      ajson.parse(Result);
      if ajson.DataType = jdtarray then
      begin
        if ajson.Count > 0 then
          ajson[0].ForcePath('Error').AsString := aErr
        else
          ajson.Add().ForcePath('Error').AsString := aErr;
      end
      else
        ajson.ForcePath('Error').AsString := aErr;
      Result := ajson.ToString();

      // messagebox(0, pchar(Result), '', 0);
    end;
  finally
    qjsonpool.return(ajson);
  end;

end;

class function TDB.Exec(aType, aSql, aValue: String): String;
var
  ajson: TQjson;

begin
  ajson := qjsonpool.get;
  try
    if aValue = '' then
      aValue := '{}';
    ajson.parse(aValue);
    Result := TDB.Exec(aType, aSql, ajson);
  finally
    qjsonpool.return(ajson);
  end;
end;

class function TDB.getconn: TFDConnection;
begin
  // FSQLDBHelp.getconn;
end;

class procedure TDB.retrunconn(aConn: TFDConnection);
begin
  // FSQLDBHelp.returnConn(aConn);
end;

{ TCmdReturn }

class function TCmdReturn.create(rc: integer; rs, err: String): TCmdReturn;
begin
  Result.ReturnCode := rc;
  Result.Result := rs;
  Result.Error := err;
end;

initialization

loadconfig;

// FSQLDBHelp := TSQLDBHelp.Create(DBServerConfig.ItemByName('Server').asstring,
// DBServerConfig.ItemByName('Username').asstring,
// DBServerConfig.ItemByName('Password').asstring,
// DBServerConfig.ItemByName('Database').asstring);

 FMuMSSQLExec := TMuMSSQLExec.create;

finalization

 DBServerConfig.Free;

 FMuMSSQLExec.Free;

// FSQLDBHelp.Free;

end.
