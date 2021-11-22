unit MFP.importSQL;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  MFP.Types, MFP.Utils, MFP.Crud, MFP.index, MFP.index.hash, MFP.index.rbtree, MFP.Package,
  Mu.LookPool, Mu.Task1, Mu.Pool.qJson, Mu.Pool.st, Mu.MSSQL.Exec, Mu.TimerTask, Mu.LockJson,
  QSimplePool, qtimetypes, unit_DB,
  Generics.Collections, unit_logs, qstring, qJson, qlog, qworker;

type
  TMFTaskElec = record
    fn: String;
    data: String;
  end;

  TMFLockList = TMuLockList<TMFTaskElec>;

  TMFPWriter = class
    protected
      FWriteCount : int64;
      FFileName   : string;
      FExt        : String;
      FStoped     : boolean;
      FConfig     : TQJson;
      FWirteHandle: THandle;
      MFElec      : TMFElec;
      FTask       : TLockJson;

      // FTask: TMFLockList;

      FDataField, FFilenameField, FFileExtField: String;
      FZipContent                              : boolean;
      procedure WriteJob(ajob: PQJob);
      procedure WriteOne(aJs: TQJson);
    public
      constructor Create(aTask: TLockJson; aConfig: TQJson; aStart: boolean = true);
      destructor Destroy; override;
      procedure stop;
      procedure start;
      property WriteCount: int64 read FWriteCount;
  end;

  TMFPSQLImport = class(TMlog)
    private
      function getGetCount: int64;
      function GetPoolCount: int64;
      function GetWriteCount: int64;
    protected

      FTasks    : TLockJson;
      FTaskGet  : TTaskGet;
      FConfig   : TQJson;
      FMFPWriter: TMFPWriter;
    public
      constructor Create(aConfig: TQJson);
      destructor Destroy; override;

      property GetCount: int64 read getGetCount;
      property PoolCOunt: int64 read GetPoolCount;
      property WriteCount: int64 read GetWriteCount;

  end;

  TMFPSQLImports = Array of TMFPSQLImport;

  TMFPSQLImports_ = record helper for TMFPSQLImports
    private
      function getGetCount: int64;
      function GetPoolCount: int64;
      function GetWriteCount: int64;
    public
      property GetCount  : int64 read getGetCount;
      property PoolCOunt : int64 read GetPoolCount;
      property WriteCount: int64 read GetWriteCount;
  end;

implementation

uses Mu.fileinfo, System.IOUtils;
{ TMFPSQLImport }

constructor TMFPSQLImport.Create(aConfig: TQJson);
begin
  FConfig := TQJson.Create;
  FConfig.Assign(aConfig);
  // FConfig.LoadFromFile(getexepath + 'config/config.json');
  FTasks     := TLockJson.Create(getexepath + 'tasks.json');
  FMFPWriter := TMFPWriter.Create(FTasks, FConfig);;
  FTaskGet   := TTaskGet.Create(FTasks, FConfig);
end;

destructor TMFPSQLImport.Destroy;
begin
  FTaskGet.Free;
  FMFPWriter.Free;
  FTasks.Free;

  inherited;
end;

function TMFPSQLImport.getGetCount: int64;
begin
  if assigned(FTaskGet) then
    result := FTaskGet.GetCount;
end;

function TMFPSQLImport.GetPoolCount: int64;
begin
  if assigned(FTasks) then
    result := self.FTasks.Count;
end;

function TMFPSQLImport.GetWriteCount: int64;
begin
  if assigned(FMFPWriter) then
    result := self.FMFPWriter.WriteCount;
end;

{ TMFPWriter }

procedure TMFPWriter.WriteJob(ajob: PQJob);
var
  djs: TQJson;
begin

  while not self.FStoped do
  begin
    djs := TQJson.Create;
    try
      if FTask.pop(djs) then
      begin
        WriteOne(djs);
      end else begin
        sleep(10);
      end; { }

    finally
      djs.Free;
    end;
  end;
end;

procedure TMFPWriter.WriteOne(aJs: TQJson);
var
  d       : string;
  fn, aExt: String;

begin
  d    := aJs.ValueByName(FDataField, '');
  fn   := aJs.ValueByName(FFilenameField, '');
  aExt := aJs.ValueByName(FFilenameField, FExt);
  if aExt = '' then
    aExt := FExt;
  if (d <> '') and (fn <> '') then
  begin
    MFElec.AppendBytes(TEncoding.UTF8.GetBytes(d), fn, false, self.FZipContent, aExt);
    inc(FWriteCount, 1);
  end;
end;

constructor TMFPWriter.Create(aTask: TLockJson; aConfig: TQJson; aStart: boolean);
begin
  FStoped        := not aStart;
  FWriteCount    := 0;
  FTask          := aTask;
  FConfig        := aConfig;
  FFileName      := FConfig.ValueByPath('Package.FileName', 'db.mpkg');
  FExt           := FConfig.ValueByPath('Package.FileExt', 'json');
  FDataField     := FConfig.ValueByPath('Package.DataField', 'data');
  FFilenameField := FConfig.ValueByPath('Package.FilenameField', 'fn');
  FFileExtField  := FConfig.ValueByPath('Package.FilenameField', 'json');

  FZipContent := FConfig.boolByPath('Package.Zip', false);

  FFileName := TPath.Combine(getexepath, FFileName);

  MFElec               := TMFElec.Create(FFileName, rwlReadWrite);
  MFElec.OnGetFileName := procedure(const aFileName: ansiString; var aNewFileName: ansiString; var aExt: ansiString)
    begin
      aNewFileName := aFileName;
      aExt         := FExt;
    end;

  FWirteHandle := workers.LongtimeJob(WriteJob, nil);
end;

destructor TMFPWriter.Destroy;
begin
  stop;
  workers.ClearSingleJob(FWirteHandle, false);
  inherited;
end;

procedure TMFPWriter.start;
begin

end;

procedure TMFPWriter.stop;
begin

end;

{ TMFPSQLImports_ }

function TMFPSQLImports_.getGetCount: int64;
var
  i: integer;
  c: int64;
begin
  c     := 0;
  for i := Low(self) to High(self) do
    inc(c, self[i].getGetCount);
  result := c;
end;

function TMFPSQLImports_.GetPoolCount: int64;
var
  i: integer;
  c: int64;
begin
  c     := 0;
  for i := Low(self) to High(self) do
    inc(c, self[i].PoolCOunt);
  result := c;

end;

function TMFPSQLImports_.GetWriteCount: int64;
var
  i: integer;
  c: int64;
begin
  c     := 0;
  for i := Low(self) to High(self) do
    inc(c, self[i].WriteCount);
  result := c;

end;

end.
