unit MFP.Index.hash;

interface

uses sysutils, system.hash, system.Classes, Mu.AnsiStr, MFP.Index, MFP.package, MFP.Types;

var
  PubIndexExt_Hash: String = '.hidx';

type

  PMFHashPos = ^TMFHashPos;

  TMFHashPos = packed record
    hash: Cardinal;
    Pos: uint64;
  end;

  TMFHashPoss = TArray<TMFHashPos>;

  TMFHashPoss_help = record helper for TMFHashPoss
    public
      function Add(const aHash: Cardinal; const aPos: Cardinal): Cardinal; overload;
      function Add(const aHashPos: TMFHashPos): Cardinal; overload;
      procedure Clear;
  end;

  TMFHashPosData = record
    DataCount: Cardinal;
    Data: TMFHashPoss;
  end;

  TMFHashPosData_help = record helper for TMFHashPosData
    private
      function GetLength: Cardinal;
      procedure QuickSort(l, R: Cardinal);
      function GetItem(aIndex: Cardinal): TMFHashPos;
    public
      property Count: Cardinal read GetLength;

      property items[aIndex: Cardinal]: TMFHashPos read GetItem; default;
      procedure Read(aStream: TStream);
      procedure Write(aStream: TStream);
      function Add(aHash: Cardinal; aPos: uint64): Cardinal; overload;
      function Add(aHashPos: TMFHashPos): Cardinal; overload;

      procedure Clear;
      procedure Sort;
      // 返回值 数量
      function Find(aHash: Cardinal; var aResult: TMFPosFindedArray): integer; overload;
      function Find(aHash: Cardinal; var aResult: TMFPosFindedArray; var APriorValues: TMFPosFindedArray;
        var ANextValues: TMFPosFindedArray; aPriorCount: integer = 0; aNextCount: integer = 0): integer; overload;
  end;

  TMFIndexHash = class(TMFIndex)
    private
      function GetHashItem(aIndex: Cardinal): TMFHashPos; overload;
      function GetHashItem(aFileName: ansistring): TMFHashPos; overload;
    protected
      FNodes: TMFHashPosData;
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
      // 返回值 找到的数量
      function Find(const aHash: Cardinal; var aResult: TMFPosFindedArray): uint64; overload;
      function Find(const aFileName: ansistring; var aResult: TMFPosFindedArray): uint64; overload;
      function Find(const aFileName: ansistring; var aResult: TMFPosFindedArray; var APriorValues: TMFPosFindedArray;
        var ANextValues: TMFPosFindedArray; aPriorCount: integer = 0; aNextCount: integer = 0): uint64; overload;

      procedure Each(AeachEvent: TEachFileEventSim); overload;
      procedure Each(AeachEvent: TEachFileEvent); overload;

      function GetItemsByIndex(aIndex: Cardinal; aCount: Cardinal; var aResult: TMFPosFindedArray): Cardinal;
      function GetItemByIndex(aIndex: Cardinal): TMFPosFinded; override;

      function Has(const aFileName: ansistring; var aResult: TMFPosFindedArray): Boolean;

      function Add(aHash: Cardinal; aPos: Cardinal): Cardinal; overload;
      function Add(aHashPos: TMFHashPos): Cardinal; overload;

      // property itemByIndex[aIndex: Cardinal]: TMFHashPos read GetHashItem;
      property items[aaFileName: ansistring]: TMFHashPos read GetHashItem;

      procedure flush();
      ///
      property Nodes: TMFHashPosData read FNodes;
  end;

function HashOf(p: Pointer; l: integer): Cardinal; overload;
function HashOf(s: ansistring): Cardinal; overload;

implementation

function HashOf(p: Pointer; l: integer): Cardinal;
{$IFDEF WIN32}
label A00, A01;
begin
  asm
    push ebx
    mov eax,l
    mov ebx,0
    cmp eax,ebx
    jz A01
    xor    eax, eax
    mov    edx, p
    mov    ebx,edx
    add    ebx,l
    A00:
    imul   eax,131
    movzx  ecx, BYTE ptr [edx]
    inc    edx
    add    eax, ecx
    cmp   ebx, edx
    jne    A00
    A01:
    pop ebx
    mov Result,eax
  end;
{$ELSE}
var
  pe: PByte;
  ps: PByte absolute p;
const
  seed = 131;
  // 31 131 1313 13131 131313 etc..
begin
  pe := p;
  inc(pe, l);
  Result := 0;
  while IntPtr(ps) < IntPtr(pe) do
  begin
    Result := Result * seed + ps^;
    inc(ps);
  end;
  Result := Result and $7FFFFFFF;
{$ENDIF}
end;

function HashOf(s: ansistring): Cardinal; overload;
begin
  Result := HashOf(pansichar(s), length(s));
end;

{ TMFIndexHash }

function TMFIndexHash.Add(aHashPos: TMFHashPos): Cardinal;
begin
  Result := self.FNodes.Add(aHashPos);
  AtomicIncrement(FChangedCount);
  if self.FFixToFile then
  begin
    FIdxStream.Write(aHashPos.hash, 4);
    FIdxStream.Write(aHashPos.Pos, 8);

  end;
end;

function TMFIndexHash.Add(aHash, aPos: Cardinal): Cardinal;
begin
  Result := self.FNodes.Add(aHash, aPos);
  AtomicIncrement(FChangedCount);
  if self.FFixToFile then
  begin
    FIdxStream.Write(aHash, 4);
    FIdxStream.Write(aPos, 8);
  end;
end;

constructor TMFIndexHash.Create(const aFileName: string; aAutoRebuild: Boolean = true; aOnwerStream: Boolean = true;
  aRebuildProgress: TMFOnProgress = nil);
begin
  inherited;
  self.FIndexFileExt := PubIndexExt_Hash;

  if fileexists(FFileName + PubIndexExt_Hash) then
  begin
    self.LoadFromFile(FFileName + self.FIndexFileExt);
  end else begin
    if self.FOnwerStream then
    begin
      FPackHeader.Read(self.FFStream);
      setlength(FNodes.Data, self.FPackHeader.FileCount);
      if aAutoRebuild then
        self.Rebuild;
    end;
  end;
end;

function TMFIndexHash.Delete(aIndex: integer): Cardinal;
begin
  self.FNodes.Data[aIndex].hash := 0; //
  Result                        := 1;
  AtomicIncrement(FChangedCount);
end;

function TMFIndexHash.Delete(aFileName: ansistring): Cardinal;
var
  fd: TMFPosFindedArray;
  i : integer;
begin
  Result := 0;
  self.Find(aFileName, fd);
  for i := High(fd) downto Low(fd) do
  begin
    Delete(fd[i].Index);
    inc(Result);
  end;
end;

destructor TMFIndexHash.Destroy;
begin
  if self.FChangedCount > 0 then
  begin
    self.flush;
  end;
  inherited;
end;

procedure TMFIndexHash.Each(AeachEvent: TEachFileEventSim);
var
  i        : Cardinal;
  p        : uint64;
  AContinue: Boolean;
begin
  for i := 0 to self.FNodes.Count - 1 do
  begin
    p := FNodes[i].Pos;
    AeachEvent(i, self.GetFileDesp(p).FileInfo.FileName.AsString, p, AContinue);
    if not AContinue then
      break;
    // (const aIndex: Cardinal; const afileName: ansistring; const aPos: uint64;
    // var AContinue: Boolean)
  end;
end;

procedure TMFIndexHash.Each(AeachEvent: TEachFileEvent);
var
  i        : Cardinal;
  p        : uint64;
  AContinue: Boolean;
  mfd      : TMFFileDesp;
  output   : TBytes;
begin
  for i := 0 to self.FNodes.Count - 1 do
  begin
    p   := FNodes[i].Pos;
    mfd := GetFileDesp(p);
    self.GetOne(p, output);
    AeachEvent(i, mfd.FileInfo.FileName.AsString, p, mfd, output, AContinue);
    if not AContinue then
      break;
    // (const aIndex: Cardinal; const afileName: ansistring; const aPos: uint64;
    // aFileDesp: TMFFileDesp; aOutput: TBytes; var AContinue: Boolean)
  end;
end;

function TMFIndexHash.Find(const aFileName: ansistring; var aResult: TMFPosFindedArray): uint64;
var
  hs: Cardinal;
  i : integer;
begin
  Result := 0;
  hs     := HashOf(pansichar(aFileName), length(aFileName));

  if Find(hs, aResult) >= 0 then
  begin
    for i := Low(aResult) to High(aResult) do
    begin
      aResult[i].FileName := aFileName;
    end;
    Result := length(aResult);
  end;
end;

function TMFIndexHash.Find(const aHash: Cardinal; var aResult: TMFPosFindedArray): uint64;
var
  i: integer;
begin
  setlength(aResult, 0);
  if self.FNodes.Find(aHash, aResult) >= 0 then
  begin
    for i := Low(aResult) to High(aResult) do
    begin
      aResult[i].FileName := GetFileDesp(aResult[i].Pos).FileInfo.FileName.AsString;
    end;
    Result := length(aResult);
  end;
end;

function TMFIndexHash.Find(const aFileName: ansistring; var aResult, APriorValues, ANextValues: TMFPosFindedArray;
  aPriorCount, aNextCount: integer): uint64;
var
  hs: Cardinal;
  i : integer;
begin
  Result := 0;
  hs     := HashOf(pansichar(aFileName), length(aFileName));
  setlength(aResult, 0);
  if self.FNodes.Find(hs, aResult, APriorValues, ANextValues, aPriorCount, aNextCount) >= 0 then
  begin

    for i := Low(aResult) to High(aResult) do
    begin
      aResult[i].FileName := GetFileDesp(aResult[i].Pos).FileInfo.FileName.AsString;
    end;
    if aPriorCount > 0 then
      for i := Low(APriorValues) to High(APriorValues) do
      begin
        APriorValues[i].FileName := GetFileDesp(APriorValues[i].Pos).FileInfo.FileName.AsString;
      end;
    if aNextCount > 0 then
      for i := Low(ANextValues) to High(ANextValues) do
      begin
        ANextValues[i].FileName := GetFileDesp(ANextValues[i].Pos).FileInfo.FileName.AsString;
      end;
    Result := length(aResult);
  end;
end;

procedure TMFIndexHash.flush;
begin
  if self.FChangedCount > 0 then
  begin
    self.SaveToFile(FFileName + PubIndexExt_Hash);
    AtomicExchange(FChangedCount, 0);
  end;
end;

function TMFIndexHash.GetFileCount: Cardinal;
begin
  Result := FNodes.DataCount;
end;

function TMFIndexHash.GetHashItem(aFileName: ansistring): TMFHashPos;
var
  hs  : Cardinal;
  i, c: Cardinal;
  posa: TMFPosFindedArray;
begin
  hs := HashOf(pansichar(aFileName), length(aFileName));
  c  := Find(hs, posa);

  // setlength(Result, length(posa));
  for i := 0 to c - 1 do
  begin
    if posa[i].FileName = aFileName then
    begin
      Result.Pos  := posa[i].Pos;
      Result.hash := hs;
    end;
  end;
end;

function TMFIndexHash.GetHashItem(aIndex: Cardinal): TMFHashPos;
begin
  if aIndex <= high(FNodes.Data) then
    Result := FNodes.Data[aIndex]
  else
  begin

  end;
end;

function TMFIndexHash.GetItemByIndex(aIndex: Cardinal): TMFPosFinded;
var
  hp: TMFHashPos;
  fd: TMFFileDesp;
begin
  Result.Pos      := 0;
  Result.FileName := '';

  if aIndex <= high(FNodes.Data) then
  begin
    hp           := FNodes.Data[aIndex];
    Result.Pos   := hp.Pos;
    Result.Index := aIndex;

    // fd              := self.GetFileDesp(hp.Pos);      // fd.FileInfo.FileName.ToString;
    Result.FileName := GetFileDesp(hp.Pos).FileInfo.FileName.AsString;

  end;
end;

function TMFIndexHash.GetItemsByIndex(aIndex, aCount: Cardinal; var aResult: TMFPosFindedArray): Cardinal;
var
  idx, c, i: integer;
begin
  setlength(aResult, aCount);
  c     := self.FNodes.Count;
  idx   := 0;
  for i := aIndex to aIndex + aCount do
  begin
    if i >= c then
      break;
    aResult[idx].Index    := idx;
    aResult[idx].Pos      := FNodes[idx].Pos;
    aResult[idx].FileName := self.GetFileDesp(FNodes[idx].Pos).FileInfo.FileName.ToString;
    inc(idx);
  end;
end;

function TMFIndexHash.Has(const aFileName: ansistring; var aResult: TMFPosFindedArray): Boolean;
begin
  Result := self.Find(aFileName, aResult) > -1;
end;

{
  function TMFIndexHash.GetOne(const aPos: Cardinal; var aFileDesp: TMFFileDesp; var aOutput: TBytes): Cardinal;
  begin
  Result                 := 0;
  self.FFStream.Position := aPos;
  aFileDesp.Read(FFStream);
  setlength(aOutput, aFileDesp.Head.FileSize);
  Result := FFStream.Read(aOutput[0], aFileDesp.Head.FileSize);
  end;

  function TMFIndexHash.GetOne(const aPos: Cardinal): TBytes;
  var
  aFileDesp: TMFFileDesp;
  begin
  self.FFStream.Position := aPos;
  setlength(Result, aFileDesp.Head.FileSize);
  FFStream.Read(Result[0], aFileDesp.Head.FileSize);
  end;



  function TMFIndexHash.GetOne(const aPos: Cardinal; var aOutput: TBytes): Cardinal;
  var
  fd: TMFFileDesp;
  begin
  Result                 := 0;
  self.FFStream.Position := aPos;
  fd.Read(FFStream);
  setlength(aOutput, fd.Head.FileSize);
  Result := FFStream.Read(aOutput[0], fd.Head.FileSize);
  end;
}

procedure TMFIndexHash.LoadFromStream(aStream: TStream);
begin
  FIndexFileSize := aStream.size;
  self.FNodes.Read(aStream);
end;

function TMFIndexHash.Rebuild: Boolean;
var
  Pos     : uint64;
  stmSize : uint64;
  l       : integer;
  Head    : TMFHead;
  FileInfo: TMFFileInfo;
  fn      : ansistring;
  hs, c   : Cardinal;
begin
  stmSize := FFStream.size;

  FPackHeader.Read(self.FFStream);

  setlength(FNodes.Data, self.FPackHeader.FileCount);

  FNodes.Clear;
  l   := length(FNodes.Data);
  Pos := sizeof(self.FPackHeader);
  c   := 0;
  while true do
  begin
    if Pos >= stmSize then
      break;
    FFStream.Position := Pos;
    Head.Read(FFStream);
    FileInfo.Read(FFStream, Head.HeadSize, Head.ExtSize);
    fn := FileInfo.FileName.AsString;
    hs := HashOf(pansichar(fn), length(fn));

    FNodes.Add(hs, Pos);

    inc(c);
    if assigned(FOnProgress) then
      FOnProgress(c, FPackHeader.FileCount);

    Pos := Pos + Head.FileSize + Head.FilePos + sizeof(TMFStop);

  end;

  FNodes.Sort;

  self.SaveToFile(self.FFileName + PubIndexExt_Hash);

  FRebuildEnd := true;
end;

procedure TMFIndexHash.SaveToFile(aFileName: String);
var
  md      : word;
  delfalse: Boolean;
begin
  inherited;

  if aFileName = '' then
    aFileName := self.FFileName + PubIndexExt_Hash;

  md := fmOpenReadWrite or fmShareDenyRead;

  md := md or fmcreate;
  try
    if assigned(FIdxStream) then //
      FIdxStream.Free;
    if fileexists(aFileName) then
      if not DeleteFile(aFileName) then
      begin
        delfalse := true;
      end;

    FIdxStream := TBufferedFileStream.Create(aFileName, md);

    // FIdxStream.Position := 0;
    SaveToStream(FIdxStream);
    if FIdxStream is TBufferedFileStream then
      TBufferedFileStream(FIdxStream).FlushBuffer;
  finally

  end;

end;

procedure TMFIndexHash.SaveToStream(aStream: TStream);
begin
  aStream.Position := 0;
  self.FNodes.Write(aStream);
end;

{ TMFHashPoss_help }

procedure TMFHashPosData_help.Clear;
var
  l: integer;
begin
  l := length(Data);
  fillchar(self.Data[0], system.length(self.Data) * sizeof(TMFHashPos), 0);
  self.DataCount := 0;
end;

function TMFHashPosData_help.Find(aHash: Cardinal; var aResult, APriorValues, ANextValues: TMFPosFindedArray;
  aPriorCount, aNextCount: integer): integer;
var
  R, ci, i : integer;
  c, idx, l: Cardinal;
begin
  Result := Find(aHash, aResult);
  if Result <= 0 then
    exit;
  // 前面的
  if aPriorCount > 0 then
  begin
    idx := aResult[low(aResult)].Index;
    ci  := idx - aPriorCount; // 往前第几个；
    l   := aPriorCount;
    if (ci < 0) then
    begin
      l  := ci + l; // 重新设置长度
      ci := 0;
    end;
    if l > 0 then
    begin
      setlength(APriorValues, l);
      for i := 0 to l - 1 do
      begin
        // APriorValues[i].filename:=
        APriorValues[i].Index := ci + i;
        APriorValues[i].Pos   := Data[ci + i].Pos;
      end;
    end;
  end;

  // 后面的
  if aNextCount > 0 then
  begin
    idx := aResult[high(aResult)].Index;
    ci  := idx + 1; // 往后第1个开始；
    l   := aNextCount;
    if (idx + l > high(Data)) then
    begin
      l := high(Data) - idx; // 重新设置长度
    end;
    if l > 0 then
    begin
      setlength(ANextValues, l);
      for i := 0 to l - 1 do
      begin
        ANextValues[i].Index := ci + i;
        ANextValues[i].Pos   := Data[ci + i].Pos;
      end;
    end;
  end;

end;

function TMFHashPosData_help.Find(aHash: Cardinal; var aResult: TMFPosFindedArray): integer;
var
  l, istart, iend, middle: uint64;
  p                      : uint64;

begin

  istart := Low(Data);
  iend   := self.DataCount - 1;
  Result := -1;
  while (istart <= iend) do
  begin
    middle := Trunc((istart + iend) / 2);
    if Data[middle].hash = aHash then
    begin
      Result := middle;

      break;
    end else if Data[middle].hash > aHash then
    begin
      if middle = 0 then
        exit;
      iend := middle - 1
    end else if Data[middle].hash < aHash then
      istart := middle + 1;
  end;

  if Result > -1 then
  begin
    // 如果找到了就往前找看是否一样的值
    l := Result - 1;
    while l >= 0 do
    begin
      if Data[l].hash = aHash then
      begin
        aResult.Add(l, Data[l].Pos);

      end
      else
        break;
      dec(l);
    end;
    aResult.Add(Result, Data[Result].Pos);

    // 往后找
    l := Result + 1;
    while l <= self.DataCount do
    begin
      if Data[l].hash = aHash then
      begin
        aResult.Add(l, Data[l].Pos);
      end
      else
        break;
      inc(l);
    end;

  end;

  Result := length(aResult);
end;

function TMFHashPosData_help.GetItem(aIndex: Cardinal): TMFHashPos;
begin
  Result := self.Data[aIndex];
end;

function TMFHashPosData_help.GetLength: Cardinal;
begin
  Result := system.length(self.Data);
end;

procedure TMFHashPosData_help.Read(aStream: TStream);
var
  c  : longint;
  stm: TBufferedFileStream;
var
  i: integer;
begin

  c              := aStream.size;
  self.DataCount := c div sizeof(TMFHashPos);
  setlength(Data, DataCount);
  aStream.Position := 0;
  // for i            := Low(Data) to High(Data) do
  // aStream.Read(self.Data[i], sizeof(TMFHashPos));

  if DataCount > 0 then
  begin
    c := aStream.Read(self.Data[0], aStream.size);
    // ifc > 0 then;
  end;
end;

procedure TMFHashPosData_help.QuickSort(l, R: Cardinal);
var
  i, J: integer;
  p, T: TMFHashPos;
begin
  if l < R then
  begin
    repeat
      if (R - l) = 1 then
      begin
        if Data[l].hash > Data[R].hash then
        begin
          T       := Data[l];
          Data[l] := Data[R];
          Data[R] := T;
        end;
        break;
      end;
      i := l;
      J := R;
      p := Data[(l + R) shr 1];
      repeat
        while Data[i].hash < p.hash do
          inc(i);
        while Data[J].hash > p.hash do
          dec(J);
        if i <= J then
        begin
          if i <> J then
          begin
            T       := Data[i];
            Data[i] := Data[J];
            Data[J] := T;

            // T       := Data[i];
            // Data[i] := Data[J];
            // Data[J] := T;
          end;
          inc(i);
          dec(J);
        end;
      until i > J;
      if (J - l) > (R - i) then
      begin
        if i < R then
          QuickSort(i, R);
        R := J;
      end else begin
        if l < J then
          QuickSort(l, J);
        l := i;
      end;
    until l >= R;
  end;
end;

procedure TMFHashPosData_help.Sort;
var
  T   : TMFHashPos;
  i, J: integer;
  flag: Boolean;
begin
  if DataCount = 0 then
    exit();
  QuickSort(0, self.DataCount - 1);

end;

procedure TMFHashPosData_help.Write(aStream: TStream);
var
  i: integer;
begin
  { for i := Low(Data) to High(Data) do
    begin
    aStream.Write(self.Data[i].hash, sizeof(Cardinal)); // TMFHashPos
    aStream.Write(self.Data[i].Pos, sizeof(uint64));
    end; }

  aStream.Write(self.Data[0], self.Count * sizeof(TMFHashPos));
end;

function TMFHashPosData_help.Add(aHash: Cardinal; aPos: uint64): Cardinal;
var
  l: integer;
begin
  l := length(Data);
  if l <= DataCount then
    setlength(Data, l + 1);;

  Data[self.DataCount].hash := aHash;
  Data[self.DataCount].Pos  := aPos;
  inc(DataCount);
  Result := DataCount;
end;

function TMFHashPosData_help.Add(aHashPos: TMFHashPos): Cardinal;
var
  l: integer;
begin
  l := length(Data);
  if l <= DataCount then
    setlength(Data, l + 1);

  Data[self.DataCount].hash := aHashPos.hash;
  Data[self.DataCount].Pos  := aHashPos.Pos;
  inc(DataCount);
  Result := DataCount;
end;

function TMFHashPoss_help.Add(const aHashPos: TMFHashPos): Cardinal;
var
  l: integer;
begin
  l := length(self);
  setlength(self, l + 1);
  self[l].hash := aHashPos.hash;
  self[l].Pos  := aHashPos.Pos;

end;

procedure TMFHashPoss_help.Clear;
begin
  fillchar(self, system.length(self) * sizeof(TMFHashPos), 0);
end;

function TMFHashPoss_help.Add(const aHash, aPos: Cardinal): Cardinal;
var
  l: integer;
begin
  l := length(self);
  setlength(self, l + 1);
  self[l].hash := aHash;
  self[l].Pos  := aPos;
end;

end.
