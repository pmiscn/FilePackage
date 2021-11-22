unit Mu.TimerTask;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,

  Mu.LookPool, Mu.Task1, Mu.Pool.qJson, Mu.Pool.st, Mu.MSSQL.Exec, Mu.LockJson, QSimplePool, qtimetypes, unit_DB,
  Generics.Collections, unit_logs, qstring, qJson, qlog, qworker;

type

  TTaskGet = class(TMlog)
    private
      FGetCount          : int64;
      FTimerType         : String;
      FIsGetting         : boolean;
      FTimerIntevalCount : int64;
      FEmptySleep        : integer;
      FConfigJson        : TQJSON;
      FPlanJobHandle     : THandle;
      FIntervalJobHandle : THandle;
      FDefaultSiteJobName: String;
      procedure planJob(ajob: PQJob);
      procedure IntervalJob(ajob: PQJob);
    protected
      FLockJson: TLockJson;

      procedure initTimer;
      procedure getfrompNone;
      procedure getfromdb;
      procedure getfromhttp;
      procedure getfromFile;
      procedure getfromplugin;

      procedure addTaskStr(resjs: TQJSON);
    public
      constructor Create(aLockJson: TLockJson; aConfigJson: TQJSON; aInitTime: boolean = true);
      destructor Destroy; override;
      procedure GetOne();
      function Stop(): boolean;
      property GetCount: int64 read FGetCount;
  end;

implementation

{ TTaskGet }

constructor TTaskGet.Create(aLockJson: TLockJson; aConfigJson: TQJSON; aInitTime: boolean = true);
begin
  FTimerIntevalCount := 0;
  FPlanJobHandle     := 0;
  FIntervalJobHandle := 0;
  FGetCount          := 0;

  FLockJson   := aLockJson;
  FConfigJson := TQJSON.Create;
  FConfigJson.Assign(aConfigJson);

  self.FIsGetting := false;
  if aInitTime then
    initTimer;
end;

destructor TTaskGet.Destroy;
begin
  if FPlanJobHandle > 0 then
    workers.ClearSingleJob(FPlanJobHandle);
  if FIntervalJobHandle > 0 then
    workers.ClearSingleJob(FIntervalJobHandle);
  FConfigJson.Free;
  inherited;
end;

procedure TTaskGet.GetOne;
var

  Tstr: String;
begin
  Tstr := self.FConfigJson.ValueByPath('Get.Type', 'DB').ToUpper;

  try
    FIsGetting := true;

    if (Tstr = 'DB') or (Tstr = 'DATABASE') then
    begin
      self.getfromdb;
    end else if (Tstr = 'HTTP') then
    begin
      getfromhttp;
    end else if (Tstr = 'FILE') then
    begin
      getfromFile;
    end else if (Tstr = 'PLUGIN') then
    begin
      getfromplugin;
    end else if (Tstr = 'NONE') then
    begin
      getfrompNone;
    end;
  finally
    FIsGetting := false;
  end;
end;

procedure TTaskGet.addTaskStr(resjs: TQJSON);
begin
  if resjs.DataType = jdtarray then
  begin
    FLockJson.AddArray(resjs);
    inc(FGetCount, resjs.Count);
  end else begin
    FLockJson.Add(resjs);
    inc(FGetCount, 1);
  end;
end;

procedure TTaskGet.getfromdb;
var
  dbconfig            : TQJSON;
  resjs, ajs, vjs, tjs: TQJSON;
  s, es               : String;
begin
  if not FConfigJson.HasChild('Get.Config', dbconfig) then
    exit;
  vjs := FConfigJson.ItemByPath('Get.ParamesValues');
  if vjs = nil then
  begin

  end;
  s := TDB.Exec(dbconfig, vjs);

  resjs := qjsonpool.Get;
  try
    if TDB.getResponseJson(s, resjs, es) then
    begin

      if es <> '' then
      begin
        exit;
      end;

      if resjs.Count = 0 then
      begin
        if FEmptySleep > 0 then
          sleep(FEmptySleep);
      end
      else
        addTaskStr(resjs);

    end;
  finally
    qjsonpool.return(resjs);
  end;

end;

procedure TTaskGet.getfromhttp;
begin

end;

procedure TTaskGet.getfromFile;
begin

end;

procedure TTaskGet.getfromplugin;
begin

end;

procedure TTaskGet.getfrompNone;
var
  dbconfig            : TQJSON;
  resjs, ajs, vjs, tjs: TQJSON;
  s, es               : String;
begin

  resjs := qjsonpool.Get;
  try

    addTaskStr(resjs);

  finally
    qjsonpool.return(resjs);
  end;

end;

procedure TTaskGet.initTimer;
var
  js, ajs: TQJSON;
  procedure initPlanJob(pstr: String);
  var
    AMask: TQPlanMask;
  begin
    AMask := TQPlanMask.Create;

    AMask.asString  := pstr;
    AMask.StartTime := now;
    AMask.StopTime  := now + 3650;
    FPlanJobHandle  := workers.Plan(planJob, AMask, nil, false, jdfFreeAsObject);
    log(llmessage, 'get task %s', [pstr]);
  end;
  procedure initIntervalTimer(cjs: TQJSON);
  var
    aInterval: integer;
  begin
    // ajs.IntByName('EmptySleep', 300000)
    if ajs.HasChild('Interval', js) then
    begin
      aInterval               := js.AsInteger;
      self.FIntervalJobHandle := workers.Delay(IntervalJob, aInterval, cjs, false, jdfFreeByUser, true);
    end;
  end;

begin
  if self.FConfigJson.HasChild('Timer', ajs) then
  begin
    FTimerType  := ajs.ValueByName('Type', '');
    FEmptySleep := ajs.IntByName('EmptySleep', 0);
    if FTimerType.ToUpper = 'PLAN' then
    begin
      if ajs.HasChild('Plan', js) then
      begin
        initPlanJob(js.asString);
      end;
    end else if FTimerType.ToUpper = 'INTERVAL' then
    begin
      initIntervalTimer(ajs);
    end;
  end;
end;

procedure TTaskGet.IntervalJob(ajob: PQJob);
begin
  if self.FLockJson.Count = 0 then
    if not FIsGetting then
      GetOne;
end;

procedure TTaskGet.planJob(ajob: PQJob);
begin
  if self.FLockJson.Count = 0 then
    if not FIsGetting then
      GetOne;
end;

function TTaskGet.Stop: boolean;
begin

end;

end.
