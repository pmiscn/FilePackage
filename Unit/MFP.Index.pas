unit MFP.Index;

interface

uses sysutils, system.hash, system.Classes, system.zlib, qrtti.map, Mu.AnsiStr, MFP.package, MFP.Types, SyncObjs;

type
  TMFPos = uint64;

  /// 查找结果 索引序号和hash及位置
  TMFPosFinded = record
    Index: Cardinal;
    Pos: uint64;
    filename: ansistring;
  end;

  TMFPosFindedArray = TArray<TMFPosFinded>;

  TMFPosFindedArray_help = record helper for TMFPosFindedArray
    function Add(const aIndex: Cardinal; const aPos: uint64): uint64; overload;
    procedure Clear;
  end;

  TEachFileEventSim = reference to procedure(const aIndex: Cardinal; const afileName: ansistring; const aPos: uint64;
    var AContinue: Boolean);
  TEachFileEvent = reference to procedure(const aIndex: Cardinal; const afileName: ansistring; const aPos: uint64;
    aFileDesp: TMFFileDesp; aOutput: TBytes; var AContinue: Boolean);

  TMFIndex = class
    private
      procedure SetStream(const Value: TBufferedFileStream);

    protected
      FFileName     : String;
      FOnwerStream  : Boolean;
      FFixToFile    : Boolean;
      FIndexFileExt : String;
      FIndexFileName: String;
      FIndexFileSize: uint64;
      FAutoRebuild  : Boolean;

      FFStream  : TBufferedFileStream;
      FIdxStream: TStream;

      FPackHeader  : TMPackHeader;
      FOnProgress  : TMFOnProgress;
      FChangedCount: Cardinal;
      FRebuildEnd  : Boolean;

      function GetFileCount(): Cardinal; virtual; abstract;
    public
      constructor Create(const afileName: string; aAutoRebuild: Boolean = true; aOnwerStream: Boolean = true;
        aRebuildProgress: TMFOnProgress = nil); virtual;
      destructor Destroy; override;
      function Rebuild: Boolean; virtual; abstract;

      procedure LoadFromFile(afileName: String = ''); virtual;
      procedure LoadFromStream(aStream: TStream); virtual; abstract;
      procedure SaveToFile(afileName: String = ''); virtual;
      procedure SaveToStream(aStream: TStream); virtual; abstract;

      function Delete(aIndex: integer): Cardinal; overload; virtual; abstract;
      function Delete(afileName: ansistring): Cardinal; overload; virtual; abstract;

      function Find(const afileName: ansistring; var aResult: TMFPosFindedArray): uint64; overload; virtual; abstract;

      function Find(const afileName: ansistring; var aResult: TMFPosFindedArray; var APriorValues: TMFPosFindedArray;
        var ANextValues: TMFPosFindedArray; aPriorCount: integer = 0; aNextCount: integer = 0): uint64; overload;
        virtual; abstract;

      { function Find(const afileName: ansistring; var aResult: TMFPosFindedArray; var APriorValues: TMFPosFindedArray;
        var ANextValues: TMFPosFindedArray; var APriorFileanmes, ANextFilenames: TArray<String>;
        aPriorCount: integer = 0; aNextCount: integer = 0): uint64; overload; virtual; abstract;
      }
      procedure Each(AeachEvent: TEachFileEventSim); overload; virtual; abstract;
      procedure Each(AeachEvent: TEachFileEvent); overload; virtual; abstract;

      function GetOne(const aPos: uint64; var aOutput: TBytes): longint; overload; virtual; // abstract;

      function GetOne(const aPos: uint64; var aOutput: TBytes; var aExt: String): longint; overload; virtual;
      // abstract;
      function GetOne(const aPos: uint64; var aFileDesp: TMFFileDesp; var aOutput: TBytes): longint; overload; virtual;

      // abstract;
      function GetOne(const aPos: uint64): TBytes; overload; virtual; // abstract;

      function GetFileDesp(const aPos: uint64): TMFFileDesp; overload; virtual; // abstract;
      function GetFileName(const aPos: uint64): ansistring; overload; virtual; // abstract;
      function GetFileName(const aPos: uint64; var aExt: ansistring): ansistring; overload; virtual; // abstract;
      function GetItemByIndex(aIndex: Cardinal): TMFPosFinded; overload; virtual; abstract;

      procedure flush(); virtual; abstract;

      property ChangedCount: Cardinal read FChangedCount;
      property RebuildEnd: Boolean read FRebuildEnd;

      property OnRebuildProgress: TMFOnProgress read FOnProgress write FOnProgress;
      property Stream: TBufferedFileStream read FFStream write SetStream;
      property IndexStream: TStream read FIdxStream;

      property FixToFile: Boolean read FFixToFile write FFixToFile;
      property IndexFileExt: String read FIndexFileExt write FIndexFileExt;

      property FileCount: Cardinal read GetFileCount;
      property ItemCount: Cardinal read GetFileCount;

      property ItemByIndex[aIndex: Cardinal]: TMFPosFinded read GetItemByIndex;

      property IndexFileName: String read FIndexFileName;
      property IndexFileSize: uint64 read FIndexFileSize;
  end;

  TMFIndexClass = class of TMFIndex;

implementation

uses Mu.fileinfo, Mu.BytesHelper;

{ TMFIndex }

constructor TMFIndex.Create(const afileName: string; aAutoRebuild: Boolean = true; aOnwerStream: Boolean = true;
  aRebuildProgress: TMFOnProgress = nil);
var
  md: word;
begin
  FIndexFileExt := '.idx';
  FChangedCount := 0;
  FRebuildEnd   := false;
  md            := fmOpenRead or fmShareDenyRead;
  FOnProgress   := aRebuildProgress;
  FOnwerStream  := aOnwerStream;
  FAutoRebuild  := aAutoRebuild;

  if FOnwerStream then
  begin
    FFStream := TBufferedFileStream.Create(afileName, md, 10 * 1024);
    // FFStream := TFileStream.Create(afileName, md);    //当多线程读取的时候，内存猛涨
    FPackHeader.Read(FFStream);
  end;
  FFileName := afileName;
end;

destructor TMFIndex.Destroy;
begin

  if FOnwerStream then
    FFStream.Free;

  if assigned(FIdxStream) then
  begin
    // if self.FixToFile then
    if FIdxStream is TBufferedFileStream then
      TBufferedFileStream(FIdxStream).FlushBuffer;
    FIdxStream.Free;
  end;
  inherited;
end;

function TMFIndex.GetOne(const aPos: uint64; var aOutput: TBytes): longint;
var
  fd       : TMFFileDesp;
  aOutBytes: TBytes;
begin
  TMonitor.Enter(self);
  try
    Result                 := 0;
    self.FFStream.Position := aPos;
    fd.Read(FFStream);
    if fd.Head.Switch.Zip then
    begin
      setlength(aOutBytes, fd.Head.FileSize);
      Result := FFStream.Read(aOutBytes[0], fd.Head.FileSize);
      ZDecompress(aOutBytes, aOutput);
      Result := length(aOutput);
    end else begin
      setlength(aOutput, fd.Head.FileSize);
      Result := FFStream.Read(aOutput[0], fd.Head.FileSize);
    end;
    // setlength(aOutput, fd.Head.FileSize);
    // Result := FFStream.Read(aOutput[0], fd.Head.FileSize);
  finally
    TMonitor.Exit(self);

  end;
end;

function TMFIndex.GetOne(const aPos: uint64; var aOutput: TBytes; var aExt: String): longint;
var
  fd       : TMFFileDesp;
  aOutBytes: TBytes;
begin
  TMonitor.Enter(self);
  try
    Result                 := 0;
    self.FFStream.Position := aPos;
    fd.Read(FFStream);
    aExt := fd.fileinfo.FileExt.AsString;

    if fd.Head.Switch.Zip then
    begin
      setlength(aOutBytes, fd.Head.FileSize);
      Result := FFStream.Read(aOutBytes[0], fd.Head.FileSize);
      ZDecompress(aOutBytes, aOutput);
      Result := length(aOutput);
    end else begin
      setlength(aOutput, fd.Head.FileSize);
      Result := FFStream.Read(aOutput[0], fd.Head.FileSize);

    end;
  finally
    TMonitor.Exit(self);
  end;
end;

function TMFIndex.GetOne(const aPos: uint64; var aFileDesp: TMFFileDesp; var aOutput: TBytes): longint;
var
  aOutBytes: TBytes;
begin
  TMonitor.Enter(self);
  try

    Result                 := 0;
    self.FFStream.Position := aPos;
    aFileDesp.Read(FFStream);

    if aFileDesp.Head.Switch.Zip then
    begin
      setlength(aOutBytes, aFileDesp.Head.FileSize);
      Result := FFStream.Read(aOutBytes[0], aFileDesp.Head.FileSize);
      ZDecompress(aOutBytes, aOutput);
      Result := length(aOutput);
    end else begin
      setlength(aOutput, aFileDesp.Head.FileSize);
      Result := FFStream.Read(aOutput[0], aFileDesp.Head.FileSize);
    end;
  finally
    TMonitor.Exit(self);
  end;
end;

function TMFIndex.GetFileDesp(const aPos: uint64): TMFFileDesp;
begin
  TMonitor.Enter(self);
  try
    FFStream.Position := aPos;
    Result.Read(FFStream);
  finally
    TMonitor.Exit(self);
  end;
end;

function TMFIndex.GetFileName(const aPos: uint64): ansistring; // abstract;
var
  desp: TMFFileDesp;
begin

  desp   := GetFileDesp(aPos);
  Result := desp.fileinfo.filename.AsString;

end;

function TMFIndex.GetFileName(const aPos: uint64; var aExt: ansistring): ansistring; // abstract;
var
  desp: TMFFileDesp;
begin

  desp   := GetFileDesp(aPos);
  Result := desp.fileinfo.filename.AsString;
  aExt   := desp.fileinfo.FileExt.AsString;

end;

function TMFIndex.GetOne(const aPos: uint64): TBytes;
var
  aFileDesp: TMFFileDesp;
  aOutBytes: TBytes;
begin
  TMonitor.Enter(self);
  try
    self.FFStream.Position := aPos;
    aFileDesp.Read(FFStream);
    // setlength(aOutBytes, aFileDesp.Head.FileSize);
    // FFStream.Read(aOutBytes[0], aFileDesp.Head.FileSize);

    if aFileDesp.Head.Switch.Zip then
    begin
      setlength(aOutBytes, aFileDesp.Head.FileSize);
      FFStream.Read(aOutBytes[0], aFileDesp.Head.FileSize);
      ZDecompress(aOutBytes, Result);
    end else begin
      setlength(Result, aFileDesp.Head.FileSize);
      FFStream.Read(Result[0], aFileDesp.Head.FileSize);
    end;
  finally
    TMonitor.Exit(self);
  end;
end;

procedure TMFIndex.LoadFromFile(afileName: String);
var
  md: word;
  // fstm: TBufferedFileStream;
  i: integer;
  // hp  : TMFHashPos;
begin
  TMonitor.Enter(self);
  try
    md := fmOpenRead; // Write or fmShareDenyRead ;
    if afileName = '' then
      afileName := self.FFileName + self.FIndexFileExt
    else if extractfileext(afileName).ToLower <> self.FIndexFileExt.ToLower() then
    begin
      afileName := self.FFileName + self.FIndexFileExt
    end;
    FIndexFileName := afileName;

    if assigned(FIdxStream) then
      FIdxStream.Free;
    FIdxStream := TMemoryStream.Create(); // TFileStream     aFileName, md
    TMemoryStream(FIdxStream).LoadFromFile(afileName);
    FIndexFileSize := FIdxStream.Size;
    try
      FIdxStream.Position := 0;
      self.LoadFromStream(FIdxStream);
    finally

    end;
  finally
    TMonitor.Exit(self);
  end;
end;

procedure TMFIndex.SaveToFile(afileName: String);
var
  md      : word;
  delfalse: Boolean;
begin
  TMonitor.Enter(self);
  try

    if afileName = '' then
      afileName := self.FFileName + FIndexFileExt;

    md := fmOpenReadWrite or fmShareDenyRead;

    md := md or fmcreate;
    try
      if assigned(FIdxStream) then //
        FIdxStream.Free;
      if fileexists(afileName) then
        if not DeleteFile(afileName) then
        begin
          delfalse := true;
        end;

      FIdxStream := TBufferedFileStream.Create(afileName, md);

      // FIdxStream.Position := 0;
      SaveToStream(FIdxStream);
      if FIdxStream is TBufferedFileStream then
        TBufferedFileStream(FIdxStream).FlushBuffer;
    finally

    end;
  finally
    TMonitor.Exit(self);
  end;
end;

procedure TMFIndex.SetStream(const Value: TBufferedFileStream);
begin
  TMonitor.Enter(self);
  try
    FFStream := Value;
    FPackHeader.Read(FFStream);
    if FAutoRebuild then
      Rebuild;
  finally
    TMonitor.Exit(self);
  end;
end;

{ TMFPosFindedArray_help }

function TMFPosFindedArray_help.Add(const aIndex: Cardinal; const aPos: uint64): uint64;
var
  l: Cardinal;
begin

  l := length(self);
  setlength(self, l + 1);
  self[l].Index := aIndex;
  // self[l].hash := aHash;
  self[l].Pos := aPos;
end;

procedure TMFPosFindedArray_help.Clear;
begin
  setlength(self, 0);
end;

end.
