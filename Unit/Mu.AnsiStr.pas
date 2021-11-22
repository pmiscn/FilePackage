unit Mu.AnsiStr;

interface

uses sysutils, windows;

type
  // TAnsiStringArray = TArray<AnsiString>;
  TAnsiCharArray = TArray<AnsiChar>;
  TAnsiCharSet   = set of AnsiChar;

  // TlineStr = AnsiString; // array [0 .. lineBufferSize - 1] of AnsiChar;
  // TFieldStr = array [0 .. OneFieldSize - 1] of AnsiChar;

  TMPAChar = packed record
    Char: PAnsiChar;
    Size: Cardinal;
    public
      function GetString(): AnsiString;
      procedure SetString(aValue: AnsiString);
      function Cat(aValue: TMPAChar): TMPAChar;
      procedure Clear();
      function Clone(): TMPAChar;
      function Compare(V2: TMPAChar): integer;
      function ToString(): AnsiString;
      procedure CopyFrom(V2: TMPAChar);
    public
      class function Create(const aFrom: AnsiString): TMPAChar; overload; static;
      class function Create(const aSize: Cardinal; const aFillChar: AnsiChar): TMPAChar; overload; static;

      property AsString: AnsiString read GetString write SetString;

  end;

  TMAChar = record
    FSize: Cardinal; //
    Char: TBytes;    // TArray<AnsiChar>;
  end;

  TMACharHelper = record helper for TMAChar
    private
      function GetSize: Cardinal;
      procedure SetSize(const Value: Cardinal);
    public
      function GetBufferSize(): Cardinal;
      procedure SetBufferSize(aValue: Cardinal);
      function GetString(): AnsiString;
      procedure SetString(aValue: AnsiString);

      constructor Create(aFrom: AnsiString); overload;
      constructor Create(aBufferSize: Cardinal); overload;
      // class function Create(aBufferSize: integer): TMAChar; overload; static;

      // class operator Implicit(const S: TMAChar): AnsiString;
      // class operator Add(const S1, S2: TMAChar): TMAChar;

      function Cat(aValue: TMAChar): TMAChar; overload;
      function Cat(aValue: AnsiString): TMAChar; overload;
      function Cat(aValue: TMPAChar): TMAChar; overload;
      function Cat(aSep: AnsiString; aValue: TMPAChar): TMAChar; overload;

      procedure Clear();
      procedure ClearAll();
      function Clone(): TMAChar;
      function Compare(V2: TMAChar): integer; overload;
      function Compare(V2: TMPAChar): integer; overload;
      function ToString(): AnsiString; overload;
      procedure ToString(var aStr: AnsiString); overload;
      // procedure ToString(aStr: PAnsiChar); overload;

      procedure CopyFrom(V2: TMAChar);
      procedure From(pc: PAnsiChar; aLen: Cardinal); overload;
      procedure From(pc: TMPAChar); overload;
      procedure From(V2: TMAChar); overload;
      procedure From(s: AnsiString); overload;

      property AsString: AnsiString read GetString write SetString;
      property BufferSize: Cardinal read GetBufferSize write SetBufferSize;
      // 类大小
      property Size: Cardinal read GetSize write SetSize;
  end;

function SkipSpaceA(var p: PAnsiChar): integer;
function IsSpaceA(c: PAnsiChar): boolean;

implementation

function IsSpaceA(c: PAnsiChar): boolean;
begin
  Result := c^ in [#9, #10, #13, #32];
end;

function SkipSpaceA(var p: PAnsiChar): integer;
var
  ps: PAnsiChar;
begin
  ps := p;
  while p^ <> #0 do
  begin
    if IsSpaceA(p) then
      Inc(p)
    else
      Break;
  end;
  Result := IntPtr(p) - IntPtr(ps);

end;

function TMPAChar.Cat(aValue: TMPAChar): TMPAChar;
// var
// p: PAnsiChar;
begin
  // p := Char;
  if aValue.Size > 0 then
    ReallocMem(Char, Size + aValue.Size + 1);
  Inc(Char, Size);
  Size := aValue.Size + Size;
  Move(aValue.Char^, Char^, aValue.Size);
  Inc(Char, aValue.Size);
  Char^ := #0;
  dec(Char, Size);
end;

procedure TMPAChar.CopyFrom(V2: TMPAChar);
var
  p: PAnsiChar;
  l: integer;
begin

  l := Size - V2.Size;
  if l < 0 then
  begin
    ReallocMem(Char, V2.Size + 1);
  end;
  Size := V2.Size;
  // fillchar(P2,size+1,#0);
  Move(V2.Char^, Char^, Size);
  p := Char;
  Inc(p, Size);
  p^ := #0;
  // char:=p2;
end;

class function TMPAChar.Create(const aSize: Cardinal; const aFillChar: AnsiChar): TMPAChar;
begin
  Result.Size := aSize;
  getmem(Result.Char, aSize);
  fillchar(Result.Char^, aSize, aFillChar);
end;

class function TMPAChar.Create(const aFrom: AnsiString): TMPAChar;
begin
  Result.AsString := aFrom;
end;

procedure TMPAChar.Clear;
begin
  if Size > 0 then
  begin
    // freemem(Char, Size);
    Char := nil;
    Size := 0;
  end;
end;

function TMPAChar.Clone: TMPAChar;
begin
  Result.Size := Size;
  getmem(Result.Char, Size + 1);
  // zeromemory(Result.Char, Size + 1);
  fillchar(Result.Char[0], Size + 1, #0);
  Move(Char^, Result.Char^, Size);
end;

function TMPAChar.Compare(V2: TMPAChar): integer;
var
  P1, P2: PAnsiChar;
begin
  // 还要加上长度
  P1 := Char;
  P2 := V2.Char;
  while true do
  begin
    if (P1^ <> P2^) or (P1^ = #0) or (P2^ = #0) then
      exit(Ord(P1^) - Ord(P2^));
    Inc(P1);
    Inc(P2);
  end;

end;

function TMPAChar.GetString: AnsiString;
begin
  // result:=AnsiString(self.Char);
  setlength(Result, Size);
  Move(Char^, PAnsiChar(Result)^, Size);
end;

procedure TMPAChar.SetString(aValue: AnsiString);
begin
  Size := length(aValue);
  Char := AnsiStrAlloc(Size + 1);
  Move(PAnsiChar(aValue)^, Char^, Size);
end;

function TMPAChar.ToString: AnsiString;
begin
  Result := Char;
end;

{ TMAChar }
{
  class operator TMACharHelper.Implicit(const S: TMAChar): AnsiString;
  begin
  Result := S.ToString;
  end;

  class operator TMACharHelper.Add(const S1, S2: TMAChar): TMAChar;
  begin
  Result := S1.Cat(S2);
  end;
}
function TMACharHelper.Cat(aValue: TMAChar): TMAChar;
begin
  if BufferSize < Size + aValue.Size then
    BufferSize := Size + aValue.Size + 1;

  Move(aValue.Char[0], Char[Size], aValue.Size);

  Size   := Size + aValue.Size;
  Result := self;
end;

function TMACharHelper.Cat(aValue: AnsiString): TMAChar;
var
  l: integer;
begin
  l := System.length(aValue);
  if BufferSize < Size + l then
    BufferSize := Size + l + 1;

  Move(PAnsiChar(aValue)^, Char[Size], l);

  Size   := Size + l;
  Result := self;
end;

function TMACharHelper.Cat(aValue: TMPAChar): TMAChar;
begin
  if BufferSize < Size + aValue.Size then
    BufferSize := Size + aValue.Size + 1;

  Move(aValue.Char^, Char[Size], aValue.Size);

  Size   := Size + aValue.Size;
  Result := self;
end;

function TMACharHelper.Cat(aSep: AnsiString; aValue: TMPAChar): TMAChar;
var
  l1, l2: integer;
begin
  l1 := System.length(aSep);
  l2 := aValue.Size;

  if BufferSize <= Size + l1 + l2 then
    BufferSize := Size + l1 + l2 + 1;

  Move(PAnsiChar(aSep)^, Char[Size], l1);
  Move(aValue.Char^, Char[Size + l1], l2);

  Size   := Size + l1 + l2;
  Result := self;
end;

procedure TMACharHelper.Clear;
begin
  // zeromemory(@Char[0], BufferSize);
  fillchar(Char[0], BufferSize, #0);
  Size := 0;
end;

procedure TMACharHelper.ClearAll;
begin
  // Size := 0 ;
  BufferSize := 0;
end;

function TMACharHelper.Clone: TMAChar;
begin
  Result.Size       := Size;
  Result.BufferSize := BufferSize;
  setlength(Result.Char, Size + 1);
  Move(Char[0], Result.Char[0], Size);
  Result.Char[Size] := 0;
end;

function TMACharHelper.Compare(V2: TMPAChar): integer;
var
  P1, P2: PAnsiChar;
begin
  // 还要加上长度
  P1 := PAnsiChar(Char);
  // P1 := PAnsiChar(@Char[0]);

  P2 := V2.Char;
  while true do
  begin
    if (P1^ <> P2^) or (P1^ = #0) or (P2^ = #0) then
      exit(Ord(P1^) - Ord(P2^));
    Inc(P1);
    Inc(P2);
  end;

end;

function TMACharHelper.Compare(V2: TMAChar): integer;
var
  P1, P2: PAnsiChar;
begin
  // 还要加上长度
  P1 := PAnsiChar(Char);
  P2 := PAnsiChar(V2.Char);
  while true do
  begin
    if (P1^ <> P2^) or (P1^ = #0) or (P2^ = #0) then
      exit(Ord(P1^) - Ord(P2^));
    Inc(P1);
    Inc(P2);
  end;

end;

procedure TMACharHelper.CopyFrom(V2: TMAChar);
begin
  Size       := V2.Size;
  BufferSize := V2.BufferSize;

  Move(V2.Char[0], Char[0], Size);
  Char[Size] := 0;
end;

procedure TMACharHelper.From(V2: TMAChar);
begin
  Size := V2.Size;
  Move(V2.Char[0], Char[0], Size);
  Char[Size] := 0;
end;

{
  class function TMAChar.Create(aBufferSize: integer): TMAChar;
  begin
  // getmem(PAnsiChar(Result.Char), aBufferSize);
  Result.BufferSize := aBufferSize;
  Result.Size := 0;
  end;
}
procedure TMACharHelper.From(pc: TMPAChar);
begin
  From(pc.Char, pc.Size);
end;

procedure TMACharHelper.From(pc: PAnsiChar; aLen: Cardinal);
begin
  if self.BufferSize < aLen then
  begin
    BufferSize := aLen + 1;
  end;

  // if Size > aLen then
  begin
    // zeromemory(@Char[aLen - 1], Size - aLen + 1);
    fillchar(Char[aLen - 1], Size - aLen + 1, #0);
    // zeromemory(PAnsiChar(Char), aLen + 1); // 不用全部清空
  end;
  Move(pc^, Char[0], aLen);
  Size := aLen;
end;

constructor TMACharHelper.Create(aFrom: AnsiString);
var
  l: integer;
begin
  l := System.length(aFrom);
  // getmem(PAnsiChar(Result.Char), l + 1);
  setlength(Char, l + 1);
  Move(PAnsiChar(aFrom)^, Char[0], l);
  Size    := l;
  Char[l] := 0;
end;

constructor TMACharHelper.Create(aBufferSize: Cardinal);
begin
  Size       := 0;
  BufferSize := aBufferSize;
end;

procedure TMACharHelper.From(s: AnsiString);
begin
  self.SetString(s);
end;

function TMACharHelper.GetBufferSize: Cardinal;
begin
  Result := System.length(Char);
end;

procedure TMACharHelper.SetBufferSize(aValue: Cardinal);
begin
  // if aValue <= System.length(Char) then
  // aValue := Size + 1;
  if aValue > 0 then
    FSize := aValue + 1
  else
    FSize := aValue;

  setlength(Char, FSize);
  if FSize > 0 then
    Char[FSize-1] := 0;
end;

function TMACharHelper.GetSize: Cardinal;
begin
  Result := self.FSize;
end;

function TMACharHelper.GetString: AnsiString;
begin
  if Size = 0 then
  begin
    Result := '';
    exit;
  end;
  System.setlength(Result, self.BufferSize - 1);
  Move(Char[0], PAnsiChar(Result)^, BufferSize - 1);
end;

procedure TMACharHelper.SetSize(const Value: Cardinal);
begin
  // self.FSize := Value ;
  self.BufferSize := Value - 1;
end;

procedure TMACharHelper.SetString(aValue: AnsiString);
var
  l, i: integer;
  s   : String;
begin

  l := length(aValue);

  if l >= self.BufferSize then
  begin
    BufferSize := l;
  end;

  if l = 0 then
  begin
    exit;
  end;

  // 先清空，这个有没有区别不大；
  fillchar(Char[0], BufferSize, 0);
  Move(aValue[Low(RawByteString)], Char[0], l);
  // Move(PAnsiChar(aValue)^, Char[0], l);

  // 后面的清空，其时这个有没有都一样 ，因为最后把后面一位给填空了。
  // if (BufferSize - l > 1) then
  // begin
  // fillchar(PAnsiChar(PAnsiChar(Char) + l)^, BufferSize - l, 0);
  // end;
  Char[l] := 0;

end;

{
  procedure TMAChar.ToString(aStr: PAnsiChar);
  begin
  if Size = 0 then
  begin
  ReallocMem(aStr, 1);
  aStr^ := #0;
  exit;
  end;
  ReallocMem(aStr, Size + 1);
  Move(Char[0], aStr^, Size);
  end;
}
procedure TMACharHelper.ToString(var aStr: AnsiString);
begin
  if Size = 0 then
  begin
    aStr := '';
    exit;
  end;
  System.setlength(aStr, self.Size);
  Move(Char[0], PAnsiChar(aStr)^, Size);
end;

function TMACharHelper.ToString: AnsiString;
begin
  Result := GetString();
end;

{ TMAChar }

end.
