unit MFP.Index.rbtree;

interface

uses sysutils, system.hash, system.Classes, system.generics.collections, qrtti.map, qrtti.map.helper,
  Mu.AnsiStr, MFP.Index, MFP.package, MFP.Types;

var
  PubIndexExt_rbtree: String = '.rbidx';

type
  TMFNamePos = TPair<ansistring, UInt64>;

  TMFNamePos_help = record helper for TMFNamePos
    public
      procedure Read(aStream: TStream);
      procedure Write(aStream: TStream);
  end;

  TMIndexMap = TQMapExt<ansistring, UInt64>;

  TMFIndexRBTree = class(TMFIndex)
    private
      function GetItem(aFileName: ansistring): TMFNamePos;
    protected
      FMap: TMIndexMap;
      function GetFileCount(): Cardinal; override;
    public
      constructor Create(const aFileName: string; aAutoRebuild: Boolean = true; aOnwerStream: Boolean = true;
        aRebuildProgress: TMFOnProgress = nil); override;
      destructor Destroy; override;

      function Rebuild: Boolean; override;

      procedure LoadFromStream(aStream: TStream); override;
      procedure SaveToFile(aFileName: String = ''); override;
      procedure SaveToStream(aStream: TStream); override;

      function Delete(aIndex: integer): Cardinal; overload; override;
      function Delete(aFileName: ansistring): Cardinal; overload; override;

      // 返回值 返回的数量
      function Find(const aFileName: ansistring; var aResult: TMFPosFindedArray; aOffset: integer = 0;
        aLimit: integer = 0): Cardinal; overload;
      procedure Each(AEachEvent: TEachFileEventSim); overload;
      procedure Each(AEachEvent: TEachFileEvent); overload;

      function GetItemsByIndex(aIndex: Cardinal; aCount: Cardinal; var aResult: TMFPosFindedArray): Cardinal;
      function GetItemByIndex(aIndex: Cardinal): TMFPosFinded; override;
      //
      function between(const aFileName1, aFileName2: ansistring; var aResult: TMFPosFindedArray): Cardinal; overload;
      function between(const aFileName1, aFileName2: ansistring): TMFPosFindedArray; overload;

      function Has(const aFileName: ansistring; var aResult: TMFPosFindedArray): Boolean;

      //
      function Add(aName: ansistring; aPos: UInt64): UInt64; overload;
      function Add(aNamePos: TMFNamePos): UInt64; overload;

      property items[aFileName: ansistring]: TMFNamePos read GetItem;

      // property itemsByIndex[aIndex: Cardinal; aCount: Cardinal]: TMFPosFindedArray read GetItemsByIndex;

      procedure flush();
      ///
      property Nodes: TMIndexMap read FMap;

  end;

implementation

{ TMFIndexRBTree }

function TMFIndexRBTree.Add(aName: ansistring; aPos: UInt64): UInt64;
var
  aNamePos: TMFNamePos;
begin
  if FMap.Add(aName, aPos) then
  begin
    result := FMap.Count;
    if FixToFile then
    begin
      aNamePos.Key   := aName;
      aNamePos.Value := aPos;
      aNamePos.Write(FIdxStream);
    end;
  end;
end;

function TMFIndexRBTree.Add(aNamePos: TMFNamePos): UInt64;
begin
  if FMap.Add(aNamePos.Key, aNamePos.Value) then
  begin
    if FixToFile then
      aNamePos.Write(FIdxStream);
    result := FMap.Count;
  end;
end;

function TMFIndexRBTree.between(const aFileName1, aFileName2: ansistring): TMFPosFindedArray;
var
  r: TMFPosFindedArray;
begin
  self.FMap.ForRange(aFileName1, aFileName2,
    procedure(ASender: TObject; const AValue: TMFNamePos; var AContinue: Boolean)
    begin
      r.Add(0, AValue.Value);
      AContinue := true;

      r[high(r)].filename := AValue.Key;
    end, true, true);
  result := r;
end;

function TMFIndexRBTree.between(const aFileName1, aFileName2: ansistring; var aResult: TMFPosFindedArray): Cardinal;
var
  r: TMFPosFindedArray;
begin
  self.FMap.ForRange(aFileName1, aFileName2,
    procedure(ASender: TObject; const AValue: TMFNamePos; var AContinue: Boolean)
    begin
      r.Add(0, AValue.Value);
      r[high(r)].filename := AValue.Key;
      AContinue := true;
    end, true, true);

  aResult := (r);
  result  := length(r);
end;

constructor TMFIndexRBTree.Create(const aFileName: string; aAutoRebuild, aOnwerStream: Boolean;
aRebuildProgress: TMFOnProgress);
begin
  inherited;
  FIndexFileExt := PubIndexExt_rbtree;
  FMap          := TMIndexMap.Create();
  if fileexists(FFileName + FIndexFileExt) then
  begin
    self.LoadFromFile(FFileName + FIndexFileExt);
  end else begin
    if self.FOnwerStream then
    begin
      FPackHeader.Read(self.FFStream);

      if aAutoRebuild then
        self.Rebuild;
    end;
  end;
end;

function TMFIndexRBTree.Delete(aIndex: integer): Cardinal;
begin
  inherited;

end;

function TMFIndexRBTree.Delete(aFileName: ansistring): Cardinal;
begin
  self.FMap.Delete(aFileName);
end;

destructor TMFIndexRBTree.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TMFIndexRBTree.Each(AEachEvent: TEachFileEvent);
var
  c: integer;
begin
  c := 0;
  FMap.ForEach(
    procedure(ASender: TObject; const AValue: TPair<ansistring, UInt64>; var AContinue: Boolean)
    var
      aFileDesp: TMFFileDesp;
      aOutput: TBytes;
    begin
      self.GetOne(AValue.Value, aFileDesp, aOutput);
      AEachEvent(c, AValue.Key, AValue.Value, aFileDesp, aOutput, AContinue);
      inc(c);
    end);
end;

procedure TMFIndexRBTree.Each(AEachEvent: TEachFileEventSim);
var
  c: integer;
begin
  c := 0;
  FMap.ForEach(
    procedure(ASender: TObject; const AValue: TPair<ansistring, UInt64>; var AContinue: Boolean)
    begin
      AEachEvent(c, AValue.Key, AValue.Value, AContinue);
      inc(c);
    end);
end;

function TMFIndexRBTree.Find(const aFileName: ansistring; var aResult: TMFPosFindedArray; aOffset: integer = 0;
aLimit: integer = 0): Cardinal;
var
  PosFinded: TMFPosFinded;
  pos      : UInt64;
begin
  if self.FMap.Find(aFileName, pos) then
    aResult.Add(0, pos);
  result := length(aResult);
end;

procedure TMFIndexRBTree.flush;
begin

end;

function TMFIndexRBTree.GetFileCount: Cardinal;
begin
  result := self.FMap.Count;
end;

function TMFIndexRBTree.GetItem(aFileName: ansistring): TMFNamePos;
var
  pos: UInt64;
begin

  if self.FMap.Find(aFileName, pos) then
  begin
    result.Key   := aFileName;
    result.Value := pos;
  end else begin
    result.Key   := '';
    result.Value := 0;
  end;
end;

function TMFIndexRBTree.GetItemByIndex(aIndex: Cardinal): TMFPosFinded;

var
  pidx, c, ct: Cardinal;
  AContinue  : Boolean;
  rr         : TMFPosFinded;
begin
  pidx       := 0;
  result.pos := 0;

  FMap.ForEach(
    procedure(ASender: TObject; const AValue: TPair<ansistring, UInt64>; var AContinue: Boolean)
    begin
      if pidx >= aIndex then
      begin
        rr.Index := pidx;
        rr.pos := AValue.Value;
        rr.filename := AValue.Key;

        AContinue := false;
      end;
      inc(pidx);
    end);
  result := rr;
end;

function TMFIndexRBTree.GetItemsByIndex(aIndex: Cardinal; aCount: Cardinal; var aResult: TMFPosFindedArray): Cardinal;

var
  pidx, c, ct: integer;
  AContinue  : Boolean;
  rr         : TMFPosFindedArray;
begin
  c      := 0;
  result := 0;

  ct   := self.FMap.Count;
  pidx := 1;
  setlength(rr, aCount);

  FMap.ForEach(
    procedure(ASender: TObject; const AValue: TPair<ansistring, UInt64>; var AContinue: Boolean)
    begin
      if pidx >= aIndex then
      begin
        rr[c].Index := c;
        rr[c].pos := AValue.Value;
        rr[c].filename := AValue.Key;

        inc(c);
        AContinue := c < aCount;
      end;
      inc(pidx);
    end);
  aResult := rr;
  result  := length(rr);
end;

function TMFIndexRBTree.Has(const aFileName: ansistring; var aResult: TMFPosFindedArray): Boolean;
var
  pos: UInt64;
begin
  result := FMap.Find(aFileName, pos);
  if result then
    aResult.Add(0, pos)
end;

procedure TMFIndexRBTree.LoadFromStream(aStream: TStream);
var
  p      : UInt64;
  sz     : UInt64;
  NamePos: TMFNamePos;
begin
  aStream.Position := 0;
  sz               := aStream.Size;
  FIndexFileSize   := sz;
  while aStream.Position < sz - 1 do
  begin
    NamePos.Read(aStream);
    self.FMap.Add(NamePos.Key, NamePos.Value);
  end;

end;

function TMFIndexRBTree.Rebuild: Boolean;
var
  pos     : int64;
  stmSize : int64;
  Head    : TMFHead;
  fileinfo: TMFFileInfo;
  fn      : ansistring;
  hs, c   : Cardinal;
begin
  stmSize := FFStream.Size;

  FPackHeader.Read(self.FFStream);

  if not FMap.IsEmpty then
    FMap.Clear;

  pos := sizeof(self.FPackHeader);
  c   := 0;
  while true do
  begin
    if pos >= stmSize then
      break;
    FFStream.Position := pos;
    Head.Read(FFStream);
    fileinfo.Read(FFStream, Head.HeadSize, Head.ExtSize);
    fn := fileinfo.filename.AsString;
    // hs := HashOf(pansichar(fn), length(fn));

    FMap.Add(fn, pos);
    inc(c);
    if assigned(FOnProgress) then
      FOnProgress(c, FPackHeader.FileCount);
    pos := pos + Head.FileSize + Head.FilePos + sizeof(TMFStop);

  end;

  self.SaveToFile(self.FFileName + self.FIndexFileExt);

  FRebuildEnd := true;

end;

procedure TMFIndexRBTree.SaveToFile(aFileName: String);
var
  Stream: TBufferedFileStream;
begin
  inherited;
  exit;
  Stream := TBufferedFileStream.Create(aFileName, fmOpenRead or fmcreate, 1024 * 1024 * 256);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TMFIndexRBTree.SaveToStream(aStream: TStream);
var
  NamePos: TMFNamePos;
begin
  aStream.Position := 0;
  self.FMap.ForEach(
    procedure(ASender: TObject; const AValue: TMFNamePos; var AContinue: Boolean)
    begin
      AValue.Write(aStream);
      AContinue := true;
    end);
end;

{ TMFNamePos_help }

procedure TMFNamePos_help.Read(aStream: TStream);
var
  l: word;
begin
  aStream.Read(l, 2);
  if l > 0 then
  begin
    setlength(Key, l);
    aStream.Read(Key[1], l);
  end;
  aStream.Seek(1, soFromCurrent);
  aStream.Read(Value, sizeof(UInt64));
  aStream.Seek(2, soFromCurrent);

end;

procedure TMFNamePos_help.Write(aStream: TStream);
var
  b: Byte;
  w: word;
begin
  w := length(Key);
  aStream.Write(w, 2);
  // b := 0;
  // aStream.Write(b, 1);
  aStream.Write(self.Key[1], length(self.Key));
  b := 0;
  aStream.Write(b, 1);
  aStream.Write(self.Value, sizeof(Value));
  b := 0;
  aStream.Write(b, 1);
  aStream.Write(b, 1);
end;

end.
