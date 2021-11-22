unit MFP.Crud;

/// 本单元实现了文件包的接口部分，包括crud
///
interface

uses sysutils, system.hash, system.Classes
  // ,Generics.Collections
    , Mu.AnsiStr, MFP.Types, MFP.Index, MFP.Index.hash, MFP.Index.rbtree, MFP.package;

type
  TMFElec = class;

  TEachPackageFileEvent = reference to procedure(const aIndex: Cardinal; const afileName: ansistring;
    const aPos: uint64; aFileDesp: TMFFileDesp; aOutput: TBytes; var AContinue: Boolean);

  /// 吧 package和Index混合一起，同时crud
  TMFElec = class
    private
      function GetDesp: ansistring;
      function GetIndexStr: ansistring;
      procedure SetDesp(const Value: ansistring);
      procedure SetIndexStr(const Value: ansistring);
      function getFileNameByIndex(const aIndex: Cardinal): ansistring;
      function getFileDespsByIndex(const aIndex: Cardinal; const aCount: Cardinal): TMFFileDesps;
      function GetFileCount: Cardinal;
    protected
      FPackage: TMFPackage;
      // FIndex           : TMFIndexHash;
      FIndex           : TMFIndexRBTree;
      Flook            : TMREWSync;
      FOnGetFileName   : TOnGetFileName;
      FRWLevel         : TMRWLevel;
      FOnFileAppendSucc: TMFOnFileAppendSucc;
    public
      constructor Create(const afileName: string; aMRWLevel: TMRWLevel);
      // Add
      function AppendFile(const afileName: String; aUpdateIndex: Boolean = true): Cardinal;
      function AppendDir(const aDir: String; const aFilter: string = '*.*'; aUpdateIndex: Boolean = true): Cardinal;
      function AppendStream(const aStream: TStream; afileName: string; aUpdateIndex: Boolean = true): Cardinal;
      function AppendBytes(const aBytes: TBytes; afileName: string; aUpdateIndex: Boolean = true;
        aZipContent: Boolean = false; aExt: String = ''): Cardinal;

      /// 删除文件
      function DeleteFile(const afileName: String): Cardinal; overload;
      // function DeleteFile(const aIndex: cardinal): cardinal; overload;

      /// 查询 查询在stream里面
      // function Find(const aHash: cardinal; var aResult: TMFPosFindedArray): cardinal; overload;
      function Find(const afileName: ansistring; var aResult: TMFPosFindedArray): Cardinal; overload;

      procedure Each(aEachEvent: TEachPackageFileEvent);

      function GetOne(const aPos: uint64; var aOutput: TBytes): longint; overload;
      function GetOne(const aPos: uint64; var aFileDesp: TMFFileDesp; var aOutput: TBytes): longint; overload;

      // function GetFiles(const aHash: cardinal): TBytesArray; overload;
      function GetFiles(const afileName: ansistring): TBytesArray; overload;
      function GetFiles(const afileName: ansistring; var aResult: TBytesArray): integer; overload;
      function GetFiles(aIndex: Cardinal; aCount: Cardinal): TBytesArray; overload;

      function GetFileNames(const aIndex: Cardinal; aCount: Cardinal): TStringArray;

      function Has(const afileName: ansistring; var aResult: TMFPosFindedArray): Boolean;

      property Files[const afileName: ansistring]: TBytesArray read GetFiles;
      property FilesByIndex[aIndex: Cardinal; aCount: Cardinal]: TBytesArray read GetFiles;
      // property Files[const aHash: cardinal]: TBytesArray read GetFiles;
      /// 基本文件信息
      property FileNames[const aIndex: Cardinal]: ansistring read getFileNameByIndex;
      // property FileDesps[const aIndex: cardinal]: TMFFileDesp read getFileDespByIndex;

      property FileDesps[const aIndex: Cardinal; const aCount: Cardinal]: TMFFileDesps read getFileDespsByIndex;

      property IndexStr: ansistring read GetIndexStr write SetIndexStr;
      property Desp: ansistring read GetDesp write SetDesp;
      property OnFileAppendSucc: TMFOnFileAppendSucc read FOnFileAppendSucc write FOnFileAppendSucc;
      property FileCount: Cardinal read GetFileCount;
      property Package: TMFPackage read FPackage;
      property IndexHash: TMFIndexRBTree read FIndex;
      property OnGetFileName: TOnGetFileName read FOnGetFileName write FOnGetFileName;

      destructor Destroy; override;
  end;

implementation

{ TMFElec }

function TMFElec.AppendBytes(const aBytes: TBytes; afileName: string; aUpdateIndex: Boolean; aZipContent: Boolean;
  aExt: String): Cardinal;
var
  fn: ansistring;
begin
  Flook.BeginWrite;
  try
    result := FPackage.AppendBytes(aBytes, afileName, false, aZipContent, aExt);
    if (aUpdateIndex) then
    begin
      fn := afileName;
      FIndex.Add(fn, result)
    end;
  finally
    Flook.EndWrite;
  end;
end;

function TMFElec.AppendDir(const aDir, aFilter: string; aUpdateIndex: Boolean): Cardinal;
begin
  FPackage.AppendDir(aDir, aFilter);
end;

function TMFElec.AppendFile(const afileName: String; aUpdateIndex: Boolean): Cardinal;
var
  fn: ansistring;
begin
  Flook.BeginWrite;
  try
    result := FPackage.AppendFile(afileName);
    if (aUpdateIndex) then
    begin
      fn := afileName;
      FIndex.Add(fn, result)
    end;
  finally
    Flook.EndWrite;
  end;
end;

function TMFElec.AppendStream(const aStream: TStream; afileName: string; aUpdateIndex: Boolean): Cardinal;
var
  fn: ansistring;
begin
  try
    Flook.BeginWrite;
    result := FPackage.AppendStream(aStream, afileName);
    if (aUpdateIndex) then
    begin
      fn := afileName;
      FIndex.Add(fn, result)
    end;
    // FIndex.Add(HashOf(fn), result);
  finally
    Flook.EndWrite;
  end;
end;

constructor TMFElec.Create(const afileName: string; aMRWLevel: TMRWLevel);
var
  fn: String;
begin
  FRWLevel := aMRWLevel;

  Flook := TMREWSync.Create;
  fn    := afileName;

  if extractfileext(fn).ToLower <> PubPackageExt then
    fn := fn + PubPackageExt;

  FPackage               := TMFPackage.Create(fn, FRWLevel);
  FPackage.OnGetFileName := procedure(const afileName: ansistring; var aNewFileName: ansistring; var aExt: ansistring)
    begin
      if assigned(self.FOnGetFileName) then
        FOnGetFileName(afileName, aNewFileName, aExt);
    end;
  FPackage.OnFileAppendSucc :=
      procedure(Const afileName: ansistring; const aPosition: Cardinal; aFileCount, aTotalCount: Cardinal)
    var
      ext, fn: ansistring;
    begin
      // 文件更新完成后，添加到索引，这个地方暂时不考虑加锁。
      fn := afileName;
      if assigned(FPackage.OnGetFileName) then
      begin
        FPackage.OnGetFileName(fn, fn, ext);
      end;
      // FIndex.Add(HashOf(fn), aPosition);
      FIndex.Add(fn, aPosition);
      if assigned(self.FOnFileAppendSucc) then
        FOnFileAppendSucc(afileName, aPosition, aFileCount, aTotalCount);
    end;

  // FIndex        := TMFIndexHash.Create(fn, false, false);


  FIndex := TMFIndexRBTree.Create(fn, false, false);

  FIndex.Stream := FPackage.Stream;

end;

function TMFElec.DeleteFile(const afileName: String): Cardinal;
var
  aPos    : Cardinal;
  HashPoss: TMFPosFindedArray;
  i       : integer;
begin
  Flook.BeginWrite;
  try
    aPos := self.FIndex.Find(afileName, HashPoss);

    for i := High(HashPoss) downto Low(HashPoss) do
    begin
      self.FPackage.DeleteFile(HashPoss[i].Pos);
      self.FIndex.Delete(HashPoss[i].Index);
    end;
  finally
    Flook.EndWrite;
  end;
end;
{
  function TMFElec.DeleteFile(const aIndex: cardinal): cardinal;
  begin
  Flook.BeginWrite;
  try
  self.FPackage.DeleteFile(FIndex.Nodes.Data[aIndex].Pos);


  self.FIndex.Delete(aIndex);
  finally
  Flook.EndWrite;
  end;
  end;

}

destructor TMFElec.Destroy;
begin
  self.FPackage.Free;
  self.FIndex.Free;
  Flook.Free;
  inherited;
end;

procedure TMFElec.Each(aEachEvent: TEachPackageFileEvent);
begin
  self.FIndex.Each(
    procedure(const aIndex: Cardinal; const afileName: ansistring; const aPos: uint64; aFileDesp: TMFFileDesp;
      aOutput: TBytes; var AContinue: Boolean)
    begin
      aEachEvent(aIndex, afileName, aPos, aFileDesp, aOutput, AContinue);
    end);
end;

{
  function TMFElec.Find(const aHash: cardinal; var aResult: TMFPosFindedArray): cardinal;
  begin
  result := FIndex.Find(aHash, aResult);
  end;
}
function TMFElec.Find(const afileName: ansistring; var aResult: TMFPosFindedArray): Cardinal;
begin
  result := FIndex.Find(afileName, aResult);
end;

function TMFElec.GetDesp: ansistring;
begin
  result := FPackage.Desp;
end;

function TMFElec.GetFileCount: Cardinal;
begin
  result := self.FIndex.FileCount;
end;

function TMFElec.GetFileNames(const aIndex: Cardinal; aCount: Cardinal): TStringArray;
var
  i, c  : Cardinal;
  Finded: TMFPosFindedArray;
begin
  c := self.FIndex.GetItemsByIndex(aIndex, aCount, Finded);

  setlength(result, c);

  for i := Low(Finded) to High(Finded) do
  begin
    result[i] := Finded[i].filename;
  end;

end;

function TMFElec.GetFiles(const afileName: ansistring; var aResult: TBytesArray): integer;
var
  Finded: TMFPosFindedArray;
  i     : integer;
begin
  result := self.FIndex.Find(afileName, Finded);

  setlength(aResult, length(Finded));
  for i := Low(Finded) to High(Finded) do
  begin
    aResult[i] := FIndex.GetOne(Finded[i].Pos);
  end;

end;

function TMFElec.getFileDespsByIndex(const aIndex: Cardinal; const aCount: Cardinal): TMFFileDesps;
var
  Finded: TMFPosFindedArray;
  i, c  : Cardinal;
  ps    : uint64;
begin
  c := self.FIndex.GetItemsByIndex(aIndex, aCount, Finded);
  setlength(result, c);
  for i := Low(Finded) to High(Finded) do
  begin
    ps        := (Finded[i].Pos);
    result[i] := self.FPackage.FileDesps[ps];
  end;
end;

function TMFElec.getFileNameByIndex(const aIndex: Cardinal): ansistring;
var
  hp: TMFHashPos;
begin
  // hp     := self.FIndex.Nodes.Data[aIndex];
  // result := self.FPackage.FileNames[hp.Pos];
end;

{
  function TMFElec.getFileDespByIndex(const aIndex: cardinal): TMFFileDesp;
  var
  hp: TMFHashPos;
  begin
  hp     := FIndex.Hashitems[aIndex];
  result := self.FPackage.FileDesps[hp.Pos];
  end;

  function TMFElec.getFileNameByIndex(const aIndex: cardinal): ansistring;
  var
  hp: TMFHashPos;
  begin
  hp     := self.FIndex.Nodes.Data[aIndex];
  result := self.FPackage.FileNames[hp.Pos];
  end;
}
function TMFElec.GetFiles(const afileName: ansistring): TBytesArray;
var
  Finded: TMFPosFindedArray;
  i     : integer;
begin
  if self.FIndex.Find(afileName, Finded) > 0 then
  begin
    setlength(result, length(Finded));
    for i := Low(Finded) to High(Finded) do
    begin
      result[i] := FIndex.GetOne(Finded[i].Pos);
    end;
  end;
  // result := GetFiles(HashOf(aFileName));
end;

function TMFElec.GetFiles(aIndex, aCount: Cardinal): TBytesArray;
var
  i, c  : Cardinal;
  Finded: TMFPosFindedArray;
begin
  c := self.FIndex.GetItemsByIndex(aIndex, aCount, Finded);

  setlength(result, c);

  for i := Low(Finded) to High(Finded) do
  begin
    result[i] := FIndex.GetOne(Finded[i].Pos);
  end;
end;

{
  function TMFElec.GetFiles(const aHash: cardinal): TBytesArray;
  var
  Finded: TMFPosFindedArray;
  i     : integer;
  begin
  self.FIndex.Find(aHash, Finded);
  setlength(result, length(Finded));
  for i := Low(Finded) to High(Finded) do
  begin
  result[i] := FIndex.GetOne(Finded[i].Pos);
  end;
  end;

}
function TMFElec.GetIndexStr: ansistring;
begin
  result := self.FPackage.IndexStr;
end;

function TMFElec.GetOne(const aPos: uint64; var aOutput: TBytes): longint;
begin
  result := self.FIndex.GetOne(aPos, aOutput);
end;

function TMFElec.GetOne(const aPos: uint64; var aFileDesp: TMFFileDesp; var aOutput: TBytes): longint;
begin
  result := self.FIndex.GetOne(aPos, aFileDesp, aOutput);
end;

function TMFElec.Has(const afileName: ansistring; var aResult: TMFPosFindedArray): Boolean;
begin
  result := self.FIndex.Has(afileName, aResult);
end;

procedure TMFElec.SetDesp(const Value: ansistring);
begin
  FPackage.Desp := Value;
end;

procedure TMFElec.SetIndexStr(const Value: ansistring);
begin
  FPackage.IndexStr := Value;
end;

end.
