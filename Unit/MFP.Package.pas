unit MFP.Package;

interface

uses sysutils, system.hash, system.Classes, qrtti.map,
  // ,Generics.Collections
  Mu.AnsiStr, MFP.Types;

var

  PubPackageExt: String     = '.mpkg';
  PubVersion   : ansistring = '0.0.1.3';

type

  TMFPackage = class(TObject)
    private
      procedure SetDesp(const Value: ansistring);
      procedure SetIndexStr(const Value: ansistring);

    protected
      FMRWLevel     : TMRWLevel;
      FFileName     : String;
      FFStream      : TBufferedFileStream;
      FOnGetFileName: TOnGetFileName;
      FPackHeader   : TMPackHeader;
      FIndexStr     : ansistring;
      FDesp         : ansistring;
      FIsCrc        : boolean;
      FIsExt        : boolean;
      FIsZip        : boolean;

      FWriteRangeStart: int64;
      FWriteRangeCount: int64;

      FOnFileAppendSucc: TMFOnFileAppendSucc;

      function GetFileName(const aPosition: uint64): ansistring;
      function GetFileDesp(const aPosition: uint64): TMFFileDesp;
      function GetFileInfo(const aPosition: uint64): TMFFileInfo;

    public
      constructor Create(const aFileName: string; aMRWLevel: TMRWLevel; aWriterbuffer: cardinal = 1024 * 1024 * 10);
      destructor Destroy; override;

      function ReadPackage(): cardinal;
      procedure SavePackageHeader();
      // 返回最后文件的文件的其实地址指针
      function AppendFile(const aFileName: String): cardinal;
      function AppendStream(const aStream: TStream; aFileName: string): cardinal;
      function AppendDir(const aDir: String; const aFilter: string = '*.*'): cardinal;
      function AppendBytes(const aBytes: Tbytes; aFileName: string): cardinal; overload;
      function AppendBytes(const aBytes: Tbytes; aFileName: string; iscrc, iszip: boolean; aExt: String = '')
        : cardinal; overload;

      /// 删除文件
      /// aPos文件的位置，是文件头的位置。
      function DeleteFile(const aPos: uint64): cardinal; overload;

      /// 检索
      /// 根据位置，取得文件名
      property FileNames[const aPosition: uint64]: ansistring read GetFileName;
      /// 根据 位置取得头部
      property FileDesps[const aPosition: uint64]: TMFFileDesp read GetFileDesp;
      property FileInfos[const aPosition: uint64]: TMFFileInfo read GetFileInfo;

      ///
      property Stream: TBufferedFileStream read FFStream;
      property WriteRangeStart: int64 read FWriteRangeStart;
      property WriteRangeCount: int64 read FWriteRangeCount;
      property PackHeader: TMPackHeader read FPackHeader;
      ///
      property IndexStr: ansistring read FIndexStr write SetIndexStr;
      property Desp: ansistring read FDesp write SetDesp;
      property OnGetFileName: TOnGetFileName read FOnGetFileName write FOnGetFileName;
      property OnFileAppendSucc: TMFOnFileAppendSucc read FOnFileAppendSucc write FOnFileAppendSucc;

  end;

implementation

uses Mu.fileinfo, Mu.BytesHelper;

{ TMFPackage }

function TMFPackage.AppendBytes(const aBytes: Tbytes; aFileName: string): cardinal;
begin
  AppendBytes(aBytes, aFileName, true, false);
end;

function TMFPackage.AppendBytes(const aBytes: Tbytes; aFileName: string; iscrc, iszip: boolean; aExt: String): cardinal;
var
  MFFile: TFMFFile;
begin
  try

    MFFile.OnGetFileName := self.FOnGetFileName;
    MFFile.LoadFromBytes(aBytes, aFileName, iscrc, iszip, true, aExt);

    AtomicExchange(FWriteRangeStart, FFStream.Position);
    AtomicExchange(self.FWriteRangeCount, MFFile.Head.FileSize);

    Result := FFStream.Seek(0, soFromEnd);
    MFFile.Write(FFStream);

    inc(FPackHeader.FileCount);
    FPackHeader.DespStr  := self.FDesp;
    FPackHeader.IndexStr := self.FIndexStr;
    FPackHeader.Write(FFStream);

    if FFStream is TBufferedFileStream then
      TBufferedFileStream(FFStream).FlushBuffer;

    if assigned(FOnFileAppendSucc) then
      OnFileAppendSucc(aFileName, Result, 1, 1);
  finally
    AtomicExchange(self.FWriteRangeStart, -1);
    AtomicExchange(self.FWriteRangeCount, -1);
  end;

end;

function TMFPackage.AppendDir(const aDir: String; const aFilter: string): cardinal;
var
  st    : Tstringlist;
  i     : integer;
  MFFile: TFMFFile;
  fn    : String;
  c, tc : integer;
  function addone(fn: String; OnFileAppendSucc: TMFOnFileAppendSucc): cardinal;
  begin
    MFFile.OnGetFileName := self.FOnGetFileName;
    MFFile.LoadFromFile(fn, self.FIsCrc, self.FIsZip, self.FIsExt);
    Result := FFStream.Position;

    AtomicExchange(FWriteRangeStart, Result);
    AtomicExchange(self.FWriteRangeCount, MFFile.Head.FileSize);

    MFFile.Write(FFStream);
    inc(c);
    if assigned(FOnFileAppendSucc) then
      FOnFileAppendSucc(fn, Result, c, tc);
    Result := 1;
    // Result := c + FPackHeader.FileCount;
  end;

begin
  Result    := 0;
  c         := 0;
  st        := Tstringlist.Create;
  st.Sorted := false;
  try
    FileFind(aDir, aFilter, st);
    // FFStream.Position := FFStream.Size;
    FFStream.Seek(0, soFromEnd);

    tc := st.Count;

    for i := 0 to tc - 1 do
    begin
      addone(st[i], OnFileAppendSucc);
    end;

    inc(FPackHeader.FileCount, c);
    Result := c;

    // FPackHeader.DespStr  := self.FDesp;
    // FPackHeader.IndexStr := self.FIndexStr;
    FPackHeader.Write(FFStream);

    if FFStream is TBufferedFileStream then
      TBufferedFileStream(FFStream).FlushBuffer;

  finally
    AtomicExchange(self.FWriteRangeStart, -1);
    AtomicExchange(self.FWriteRangeCount, -1);
    st.Free;
  end;
end;

function TMFPackage.AppendFile(const aFileName: String): cardinal;
var
  MFFile: TFMFFile;
begin

  try
    MFFile.OnGetFileName := self.FOnGetFileName;
    MFFile.LoadFromFile(aFileName, true);

    Result := FFStream.Seek(0, soFromEnd);

    AtomicExchange(FWriteRangeStart, FFStream.Position);
    AtomicExchange(self.FWriteRangeCount, MFFile.Head.FileSize);

    MFFile.Write(FFStream);

    inc(FPackHeader.FileCount);

    // FPackHeader.DespStr  := self.FDesp;
    // FPackHeader.IndexStr := self.FIndexStr;
    FPackHeader.Write(FFStream);

    if FFStream is TBufferedFileStream then
      TBufferedFileStream(FFStream).FlushBuffer;

    if assigned(FOnFileAppendSucc) then
      OnFileAppendSucc(aFileName, Result, 1, 1);
  finally
    AtomicExchange(self.FWriteRangeStart, -1);
    AtomicExchange(self.FWriteRangeCount, -1);
  end;
end;

function TMFPackage.AppendStream(const aStream: TStream; aFileName: string): cardinal;
var
  MFFile: TFMFFile;
begin
  try
    MFFile.OnGetFileName := self.FOnGetFileName;
    MFFile.LoadFromStream(aStream, aFileName, true);
    AtomicExchange(FWriteRangeStart, FFStream.Position);
    AtomicExchange(self.FWriteRangeCount, MFFile.Head.FileSize);

    Result := FFStream.Seek(0, soFromEnd);
    MFFile.Write(FFStream);

    inc(FPackHeader.FileCount);
    FPackHeader.DespStr  := self.FDesp;
    FPackHeader.IndexStr := self.FIndexStr;
    FPackHeader.Write(FFStream);

    if FFStream is TBufferedFileStream then
      TBufferedFileStream(FFStream).FlushBuffer;

    if assigned(FOnFileAppendSucc) then
      OnFileAppendSucc(aFileName, Result, 1, 1);
  finally
    AtomicExchange(self.FWriteRangeStart, -1);
    AtomicExchange(self.FWriteRangeCount, -1);
  end;
end;

constructor TMFPackage.Create(const aFileName: string; aMRWLevel: TMRWLevel;
  aWriterbuffer: cardinal = 1024 * 1024 * 10);
var
  md   : word;
  isnew: boolean;

begin
  FMRWLevel        := aMRWLevel;
  isnew            := false;
  FWriteRangeStart := -1;
  FWriteRangeCount := -1;
  FIsCrc           := true;
  FIsExt           := true;
  FIsZip           := false;

  md := fmOpenReadWrite or fmShareDenyRead;
  if not fileexists(aFileName) then
  begin
    md    := md or fmcreate;
    isnew := true;
  end;

  // rwlRead, rwlReadWrite, rwlWrite
  case FMRWLevel of
    rwlRead:
      FFStream := TBufferedFileStream.Create(aFileName, md );
    rwlReadWrite:
      FFStream := TBufferedFileStream.Create(aFileName, md, aWriterbuffer);
    rwlWrite:
      FFStream := TBufferedFileStream.Create(aFileName, md, 1024 * 1024 * 512);
  end;
  //

  FFileName := aFileName;

  if isnew then
  begin
    // FPackHeader.Version ;
    FPackHeader.IndexStr   := self.FIndexStr;
    FPackHeader.VersionStr := PubVersion;
    FPackHeader.DespStr    := self.FDesp;
    FPackHeader.FileCount  := 0;
    FPackHeader.Write(FFStream);

    if FFStream is TBufferedFileStream then
      TBufferedFileStream(FFStream).FlushBuffer;

  end
  else
    FPackHeader.Read(FFStream);
end;

function TMFPackage.DeleteFile(const aPos: uint64): cardinal;
var
  fd: TMFFileDesp;
  p : int64;
begin
  Result := 0;
  p      := self.FFStream.Position;
  try

    self.FFStream.Position := aPos;
    fd.Head.Read(FFStream);
    AtomicExchange(FWriteRangeStart, aPos);

    AtomicExchange(self.FWriteRangeCount, fd.Head.FileSize);

    fd.Head.Switch.Deleted := true;
    self.FFStream.Position := aPos;
    fd.Head.Write(FFStream);

    self.FFStream.Position := p;
  finally
    AtomicExchange(self.FWriteRangeStart, -1);
    AtomicExchange(self.FWriteRangeCount, -1);
  end;
end;

destructor TMFPackage.Destroy;
begin
  FPackHeader.Write(FFStream);

  FFStream.Free;
  inherited;
end;

function TMFPackage.GetFileDesp(const aPosition: uint64): TMFFileDesp;
begin
  self.FFStream.Position := aPosition;
  Result.Read(FFStream);
end;

function TMFPackage.GetFileInfo(const aPosition: uint64): TMFFileInfo;
begin
  Result := self.FileDesps[aPosition].fileinfo;
end;

function TMFPackage.GetFileName(const aPosition: uint64): ansistring;
begin
  Result := self.FileDesps[aPosition].fileinfo.FileName.AsString;
end;

function TMFPackage.ReadPackage: cardinal;
begin

end;

procedure TMFPackage.SavePackageHeader;
begin
  FPackHeader.Write(FFStream);
end;

procedure TMFPackage.SetDesp(const Value: ansistring);
begin
  FDesp                    := Value;
  self.FPackHeader.DespStr := Value;
end;

procedure TMFPackage.SetIndexStr(const Value: ansistring);
begin
  FIndexStr                 := Value;
  self.FPackHeader.IndexStr := Value;
end;

end.
