unit MFP.Types;

{
  以前狠早就想实现文件打包存储的东西，实现起来很简单，想了好几年，疫情期间在家闭关2个月，主要时间更新了网页模版，用2个周时间写了这个代码。
  基本实现了文件的打包和检索，但是不能删除。

  文件类型声明单元。

  阿木，2020年1月
  QQ：345148965
}
interface

uses sysutils, System.Classes, Mu.Crc, Mu.AnsiStr, System.zlib;

Type
  TBytesArray      = TArray<TBytes>;
  TBytesArraies    = TArray<TBytesArray>;
  TStringArray     = TArray<String>;
  TAnsiStringArray = TArray<ansiString>;
  {
    CRC 校验
    每个块3部分 1、头部 8个字节 2、文件信息部 3 文件内容  4 停止位

    xxxxxxxx xxxxxxxxxxxx xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx 00

  }

  TWordOfInt       = array [0 .. 1] of WORD;
  TByteOfInt       = array [0 .. 3] of Byte;
  TCardinalOfInt64 = array [0 .. 1] of Cardinal;
  TWordOfInt64     = array [0 .. 1] of WORD;
  TByteOfInt64     = array [0 .. 7] of Byte;

  // 文件头部第一个部分，1个字节，存放基本信息标志位
  // bb : TBits ;
  // index 7    6   5    4     3   2   1   0
  // bits  0    0   0    0     0   0   0   0
  // act   del  0   ext  desp  aes crc zip head
  // v     128  64  32   16    8   4   2   1

  TMFSwitch = packed record
    Body: Byte;
  end;

  // 支持8个标志位
  TMFSwitch_help = record helper for TMFSwitch
    private

      function GetHead: Boolean;
      function GetZip: Boolean;
      function GetHasCRC: Boolean;
      function GetAes: Boolean;
      function GetDeleted: Boolean;

      procedure Sethead(const Value: Boolean);
      procedure SetZip(const Value: Boolean);
      procedure SetHasCRC(const Value: Boolean);
      procedure SetAes(const Value: Boolean);
      procedure SetDeleted(const Value: Boolean);

      function GetPos(aPos: smallint): Boolean;
      procedure SetPos(aPos: smallint; Value: Boolean);
      function GetDesp: Boolean;
      procedure SetDesp(const Value: Boolean);
      function GetExt: Boolean;
      procedure SetExt(const Value: Boolean);

    public
      procedure Read(aStream: TStream);
      procedure Write(aStream: TStream);
    public

      property Head          : Boolean Read GetHead Write Sethead;
      property Zip           : Boolean Read GetZip Write SetZip;
      property HasCRC        : Boolean Read GetHasCRC Write SetHasCRC;
      property Aes           : Boolean read GetAes write SetAes;
      property HasDescription: Boolean read GetDesp write SetDesp;
      // property HasExt        : Boolean read GetExt write SetExt;

      property Deleted            : Boolean read GetDeleted Write SetDeleted;
      property Switch[i: smallint]: Boolean read GetPos write SetPos;
  end;

  // 一共8个字节的头部信息
  // 8个文件头信息 前8位是开关 第二字节是  第三    第四是 head的长度
  // bbbbbbbb  x  xx  xxxx
  TMFHead = packed record
    case integer of
      0:
        (Int64: uint64); // uint64
      1:
        (Low, High: Cardinal);
      2:
        (Cardinals: TCardinalOfInt64);
      3:
        (Words: TWordOfInt64);
      4:
        (Bytes: TByteOfInt64);
      5:
        (Switch: TMFSwitch;   // 开关       8
          ExtSize: Byte;      // Ext大小    8   //目前当做扩展名的长度。
          HeadSize: WORD;     // 头部大小  16   //主要是文件描述大小，最大支持65535个字节空间
          FileSize: Cardinal; // 文件大小  32   //单个文件最大3.4G。
        );
  end;

  TMFHead_help = record helper for TMFHead
    private
      function GetFilePos: Cardinal;
      function GetHeadPos: Cardinal;
    public
      class function Create: TMFHead; static;
      procedure Read(aStream: TStream); overload;
      procedure Read(aBytes: TBytes); overload;
      procedure Write(aStream: TStream); overload;
      procedure Write(aBytes: TBytes); overload;
      procedure Clear;

      property FilePos: Cardinal Read GetFilePos;
      property HeadPos: Cardinal Read GetHeadPos;

  end;

  // 第2部分，文件信息  这个长度是可变。最大 65535 个字节

  TMFFileCRC = packed record
    case integer of
      0:
        (Crc: Cardinal);
      1:
        (Bytes: TByteOfInt)
  end;

  // xxxx xxxxxxxx
  TMFFileInfo = packed record
    // Size : WORD ;          // 本身的大小
    // FileSize : Cardinal ;  // 文件的大小
    Crc: TMFFileCRC;   // CRC校验4个字节
    FileName: TMAChar; // 4字节长度 后面是文本
    FileExt: TMAChar;
    // FileDesp: TMAChar;     // 文件描述，4字节长度，后面是文本
  end;

  TMFFileInfo_help = record helper for TMFFileInfo
    private
      function GetSize: Cardinal;
      function GetFileNameSize: Cardinal;
      function GetFileExtSize: Cardinal;
    public
      procedure From(aCrc: Cardinal; aFileName: TMAChar); overload;
      procedure From(aCrc: Cardinal; aFileName, aFileExt: TMAChar); overload;
      procedure From(aCrc: Cardinal; aFileName: ansiString); overload;
      procedure From(aCrc: Cardinal; aFileName, aFileExt: ansiString); overload;

      // procedure Read(aStream: TStream; afileSize: Cardinal); overload;
      // procedure Read(aBytes: TBytes; afileSize: Cardinal); overload;

      procedure Read(aStream: TStream; afileSize: Cardinal; aFileExtSize: Byte); overload;
      procedure Read(aBytes: TBytes; afileSize: Cardinal; aFileExtSize: Byte); overload;

      procedure Write(aStream: TStream); overload;
      procedure Write(aBytes: TBytes); overload;
      procedure Clear;
      property Size: Cardinal read GetSize;
      property FileNameSize: Cardinal read GetFileNameSize;
      property FileExtSize: Cardinal read GetFileExtSize;

  end;

  // 一个2字节的停止位信息；
  TMFStop = packed record
    case integer of
      0:
        (Stop: WORD);
      1:
        (Low: Byte;
          High: Byte;
        )
  end;

  TMFStop_help = record helper for TMFStop
    public
      procedure Init();
  end;

  TOnGetFileName = reference to procedure(const aFileName: ansiString; var aNewFileName: ansiString;
    var aExt: ansiString);


  // 文件块，包括 头部，文件描述，文件内容和停止位，四个部分；

  TFMFFile = record
    Head: TMFHead;
    FileInfo: TMFFileInfo;
    FileBytes: TBytes;
    Stop: TMFStop;

    OnGetFileName: TOnGetFileName;
  end;

  TFMFFile_help = record helper for TFMFFile
    private
      function GetSize: Cardinal;
    protected

    public
      procedure Read(aStream: TStream); overload;
      procedure Write(aStream: TStream); overload;
      // procedure Write(aBytes: TBytes); overload;
      procedure LoadFromBytes(aBytes: TBytes; aFileName: ansiString = ''; aIsCrc: Boolean = false;
        aIsZip: Boolean = false; aIsExt: Boolean = true; aExt: ansiString = '');
      procedure LoadFromStream(aStream: TStream; aFileName: ansiString = ''; aIsCrc: Boolean = false;
        aIsZip: Boolean = false; aIsExt: Boolean = true; aExt: ansiString = '');
      procedure LoadFromFile(aFileName: ansiString; aIsCrc: Boolean = false; aIsZip: Boolean = false;
        aIsExt: Boolean = true; aExt: ansiString = '');

      procedure SaveToFile(aFileName: ansiString);
      procedure SaveToStream(aStream: TStream);

      property Size: Cardinal read GetSize;

  end;

  // 文件描述块，也就是文件内容的前2部分和对应的位置信息，主要是给搜索用
  TMFFileDesp = record
    Head: TMFHead;
    FileInfo: TMFFileInfo;
    Position: Cardinal;
  end;

  TMFFileDesps = TArray<TMFFileDesp>;

  TMFFileDesp_help = record helper for TMFFileDesp
    procedure Read(aStream: TStream);
    procedure Clear;
  end;

  // 文件包的头部信息；208 32 16 8  一共256个字节；
  // 压缩算法 zip gzip lzma lz4 zstd  应该有个压缩算法选项
  TMPackHeader = packed record
    Index: Array [0 .. 207] of Byte;
    Desp: Array [0 .. 30] of Byte; // 文件描述 30个字节;
    CompresType: Byte;
    Version: Array [0 .. 15] of Byte;
    FileCount: Cardinal;
  end;

  TMPackHeader_help = record helper for TMPackHeader

    private
      function GetDesp: ansiString;
      function GetVersion: ansiString;
      procedure SetDesp(const Value: ansiString);
      procedure SetVersion(const Value: ansiString);
      function GetIndex: ansiString;
      procedure SetIndex(const Value: ansiString);
    public
      procedure Read(aStream: TStream);
      procedure Write(aStream: TStream);
      procedure Clear;

      property VersionStr: ansiString read GetVersion write SetVersion;
      property DespStr: ansiString read GetDesp write SetDesp;
      property IndexStr: ansiString read GetIndex write SetIndex;

  end;

  TMFOnFileAppendSucc = reference to procedure(Const aFileName: ansiString; const aPosition: Cardinal;
    aFileCount, aTotalCount: Cardinal);
  TMFOnProgress = reference to procedure(aCurent, aTotal: Cardinal);

  // 读写等级，只读，可读写，只读。
  TMRWLevel = (rwlRead, rwlReadWrite, rwlWrite);

implementation

uses Mu.pool.st;

{ TMFSwitch_help }

function TMFSwitch_help.GetPos(aPos: smallint): Boolean;
begin
  result := ((1 shl aPos) and Body) <> 0
end;

function TMFSwitch_help.GetHead: Boolean;
begin
  result := self.GetPos(0);
end;

function TMFSwitch_help.GetZip: Boolean;
begin
  result := self.GetPos(1);
end;

function TMFSwitch_help.GetHasCRC: Boolean;
begin
  result := self.GetPos(2);
end;

function TMFSwitch_help.GetAes: Boolean;
begin
  result := self.GetPos(3);
end;

function TMFSwitch_help.GetDesp: Boolean;
begin
  result := self.GetPos(4);
end;

function TMFSwitch_help.GetExt: Boolean;
begin
  result := self.GetPos(5);
end;

function TMFSwitch_help.GetDeleted: Boolean;
begin
  result := self.GetPos(7);
end;

procedure TMFSwitch_help.SetPos(aPos: smallint; Value: Boolean);
begin
  if Value then
    Body := Body or (1 shl aPos)
  else
    Body := Body and (not(1 shl aPos))

    // Body := Body and ($FF xor (1 shl aPos))
end;

procedure TMFSwitch_help.Sethead(const Value: Boolean);
begin
  self.SetPos(0, Value);
end;

procedure TMFSwitch_help.SetZip(const Value: Boolean);
begin
  self.SetPos(1, Value);
end;

procedure TMFSwitch_help.SetHasCRC(const Value: Boolean);
begin
  self.SetPos(2, Value);
end;

procedure TMFSwitch_help.SetAes(const Value: Boolean);
begin
  self.SetPos(3, Value);
end;

procedure TMFSwitch_help.SetDesp(const Value: Boolean);
begin
  self.SetPos(4, Value);
end;

procedure TMFSwitch_help.SetExt(const Value: Boolean);
begin
  self.SetPos(5, Value);
end;

procedure TMFSwitch_help.SetDeleted(const Value: Boolean);
begin
  self.SetPos(7, Value);
end;

procedure TMFSwitch_help.Read(aStream: TStream);
begin
  aStream.Read(self, sizeof(self));
end;

procedure TMFSwitch_help.Write(aStream: TStream);
begin
  aStream.Write(self, sizeof(self));
end;

{ TMFHead_help }

procedure TMFHead_help.Clear;
begin
  fillchar(self.Bytes[0], sizeof(self), #0);
end;

class function TMFHead_help.Create: TMFHead;
begin
  result.Clear;
end;

function TMFHead_help.GetFilePos: Cardinal;
begin
  result := sizeof(self) + self.HeadSize;
end;

function TMFHead_help.GetHeadPos: Cardinal;
begin
  result := sizeof(self);
end;

procedure TMFHead_help.Read(aBytes: TBytes);
begin
  move(aBytes[0], self.Bytes[0], sizeof(self));
end;

procedure TMFHead_help.Read(aStream: TStream);
begin
  aStream.Read(self.Bytes, sizeof(self))
end;

procedure TMFHead_help.Write(aBytes: TBytes);
begin
  move(self.Bytes[0], aBytes[0], sizeof(self));
end;

procedure TMFHead_help.Write(aStream: TStream);
begin
  aStream.Write(Bytes[0], sizeof(self))
end;

{ TMFFileInfo_help }

procedure TMFFileInfo_help.Clear;
begin
  self.FileName.ClearAll;
end;

procedure TMFFileInfo_help.From(aCrc: Cardinal; aFileName: ansiString);
begin
  self.Crc.Crc := aCrc;
  self.FileName.From(aFileName);
  self.FileExt.From('');
end;

procedure TMFFileInfo_help.From(aCrc: Cardinal; aFileName, aFileExt: ansiString);
begin
  self.Crc.Crc := aCrc;
  self.FileName.From(aFileName);
  self.FileExt.From(aFileExt);
end;

procedure TMFFileInfo_help.From(aCrc: Cardinal; aFileName: TMAChar);
begin
  self.Crc.Crc  := aCrc;
  self.FileName := aFileName;
end;

procedure TMFFileInfo_help.From(aCrc: Cardinal; aFileName, aFileExt: TMAChar);
begin
  self.Crc.Crc  := aCrc;
  self.FileName := aFileName;
  self.FileExt  := aFileExt;
end;

function TMFFileInfo_help.GetFileExtSize: Cardinal;
begin
  result := self.FileExt.Size;
end;

function TMFFileInfo_help.GetFileNameSize: Cardinal;
begin
  result := self.FileName.Size;
end;

function TMFFileInfo_help.GetSize: Cardinal;
begin
  result := sizeof(self.Crc) + self.FileName.Size + self.FileExt.Size;
end;

procedure TMFFileInfo_help.Read(aBytes: TBytes; afileSize: Cardinal; aFileExtSize: Byte);
begin

end;

procedure TMFFileInfo_help.Read(aStream: TStream; afileSize: Cardinal; aFileExtSize: Byte);
begin

  // 这2个必须减去1，因为本来 size会给最后一位加上一个0；
  aStream.Read(self.Crc, sizeof(self.Crc));
  FileName.Size := afileSize - sizeof(Crc) - aFileExtSize;
  FileExt.Size  := aFileExtSize;
  aStream.Read(FileName.Char, FileName.BufferSize);

  if aFileExtSize > 0 then
    aStream.Read(FileExt.Char, FileExt.BufferSize);

  // 拿到大小
  { aStream.Read(self.Crc, sizeof(self.Crc));
    setlength(self.FileName.Char, afileSize - sizeof(self.Crc));
    FileName.Size := length(FileName.Char);
    aStream.Read(self.FileName.Char, afileSize - sizeof(self.Crc) - 1);
  }
end;

{
  procedure TMFFileInfo_help.Read(aStream: TStream; afileSize: Cardinal);
  begin
  // 拿到大小
  aStream.Read(self.Crc, sizeof(self.Crc));
  setlength(self.FileName.Char, afileSize - sizeof(self.Crc));
  FileName.Size := length(FileName.Char);
  aStream.Read(self.FileName.Char, afileSize - sizeof(self.Crc) - 1);
  end;

  procedure TMFFileInfo_help.Read(aBytes: TBytes; afileSize: Cardinal);
  begin
  move(aBytes[0], self.Crc.Bytes[0], sizeof(self.Crc));
  self.FileName.Size := afileSize;
  move(aBytes[sizeof(self.Crc)], self.FileName.Char, afileSize)

  end;
}
procedure TMFFileInfo_help.Write(aStream: TStream);
begin
  aStream.Write(self.Crc.Bytes, sizeof(Crc.Bytes));
  aStream.Write(self.FileName.Char, self.FileName.Size);
  if FileExt.BufferSize > 0 then
    aStream.Write(self.FileExt.Char, self.FileExt.Size);
end;

procedure TMFFileInfo_help.Write(aBytes: TBytes);
begin
  move(Crc.Bytes[0], aBytes[0], sizeof(Crc));
  // Crc后面就是文件名
  move(self.FileName.Char[0], aBytes[sizeof(Crc)], self.FileName.Size);
  // 文明后面就是扩展名
  if FileExt.Size > 0 then
    move(self.FileExt.Char[0], aBytes[sizeof(Crc) + self.FileName.Size], self.FileExt.Size);

end;

{ TFMFFile_help }

function TFMFFile_help.GetSize: Cardinal;
begin
  result := sizeof(self.Head) + self.FileInfo.Size + length(self.FileBytes) + sizeof(self.Stop);
end;

// 这里都是小文件需求，直接加到内存了。
procedure TFMFFile_help.LoadFromBytes(aBytes: TBytes; aFileName: ansiString; aIsCrc, aIsZip, aIsExt: Boolean;
  aExt: ansiString);
var
  fs       : WORD;
  fss      : Cardinal;
  Crc      : longword;
  outBuffer: TBytes;
  l        : Cardinal;
begin

  self.Head.Clear;
  self.Head.Switch.Head   := true;
  self.Head.Switch.HasCRC := aIsCrc;
  self.Head.Switch.Zip    := aIsZip;
  self.Head.ExtSize       := 0;
  if aExt = '' then
    aIsExt := false;

  // self.Head.Switch.HasExt := aIsExt;

  if aIsCrc then
  begin
    if TMuCRC32.GetCRC32(aBytes, Crc) then
      self.FileInfo.Crc.Crc := Crc;
  end
  else
    self.FileInfo.Crc.Crc := 0;

  FileInfo.FileName.AsString := aFileName;

  if (aIsExt) then
  begin
    FileInfo.FileExt.AsString := aExt;
    self.Head.ExtSize         := FileInfo.FileExt.BufferSize; // length(aExt);
  end;

  self.Head.HeadSize := sizeof(self.FileInfo.Crc) + self.FileInfo.FileExt.BufferSize + FileInfo.FileName.BufferSize;
  // 预留一个结束

  if Head.Switch.Zip then
  begin

    try
      ZCompress(aBytes, outBuffer);

      l                  := length(outBuffer);
      self.Head.FileSize := l;
      setlength(FileBytes, l);

      move(outBuffer[0], FileBytes[0], l);
    finally

    end;
  end else begin
    l                  := length(aBytes);
    self.Head.FileSize := l;
    setlength(FileBytes, l);
    move(aBytes[0], FileBytes[0], l);
  end;

  self.Stop.Init;

end;

procedure TFMFFile_help.LoadFromFile(aFileName: ansiString; aIsCrc: Boolean = false; aIsZip: Boolean = false;
  aIsExt: Boolean = true; aExt: ansiString = '');
var
  // stm: TBufferedFileStream;
  stm         : TMemoryStream;
  fn, ext, nfn: ansiString;

begin
  // stm := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyWrite);
  stm := stmPool.get;
  stm.LoadFromFile(aFileName);
  try
    fn := aFileName;
    if assigned(OnGetFileName) then
      OnGetFileName(fn, nfn, ext);
    if aIsExt then
      if aExt = '' then
      begin
        if ext = '' then
          ext := extractfileext(fn);
        aExt  := ext;
      end;
    LoadFromStream(stm, nfn, aIsCrc, aIsZip, aIsExt, aExt);
  finally
    stmPool.return(stm);
    // stm.Free;
  end;
end;

procedure TFMFFile_help.LoadFromStream(aStream: TStream; aFileName: ansiString = ''; aIsCrc: Boolean = false;
  aIsZip: Boolean = false; aIsExt: Boolean = true; aExt: ansiString = '');
var
  fs : WORD;
  fss: Cardinal;
  Crc: longword;
  stm: TMemoryStream;
begin
  self.Head.Clear;
  self.Head.Switch.Head   := true;
  self.Head.Switch.HasCRC := aIsCrc;
  self.Head.Switch.Zip    := aIsZip;
  self.Head.ExtSize       := 0;
  if aExt = '' then
    aIsExt := false;

  // self.Head.Switch.HasExt := aIsExt;

  if aIsCrc then
  begin
    if TMuCRC32.GetCRC32(aStream, Crc) then
      self.FileInfo.Crc.Crc := Crc;
  end
  else
    self.FileInfo.Crc.Crc := 0;

  FileInfo.FileName.AsString := aFileName;
  if (aIsExt) then
  begin
    FileInfo.FileExt.AsString := aExt;
    self.Head.ExtSize         := FileInfo.FileExt.BufferSize; // length(aExt);
  end;

  self.Head.HeadSize := sizeof(self.FileInfo.Crc) + self.FileInfo.FileExt.BufferSize + FileInfo.FileName.BufferSize;
  // 预留一个结束

  aStream.Position := 0;
  if Head.Switch.Zip then
  begin
    stm := stmPool.get;
    try
      ZCompressStream(aStream, stm);
      stm.Position := 0;

      self.Head.FileSize := stm.Size;
      setlength(FileBytes, stm.Size);

      aStream.Read(FileBytes, stm.Size);
    finally
      stmPool.return(stm);
    end;
  end else begin
    self.Head.FileSize := aStream.Size;

    setlength(FileBytes, aStream.Size);
    aStream.Read(FileBytes, aStream.Size);
  end;

  self.Stop.Init;
end;

procedure TFMFFile_help.Read(aStream: TStream);
begin
  self.Head.Read(aStream);
  self.FileInfo.Read(aStream, self.Head.HeadSize, self.Head.ExtSize);
  setlength(self.FileBytes, self.Head.FileSize);
  aStream.Read(self.FileBytes, self.Head.FileSize);
  self.Stop.Init;
end;

procedure TFMFFile_help.SaveToFile(aFileName: ansiString);
var
  md  : WORD;
  fstm: TBufferedFileStream;
begin

  md := fmOpenReadWrite or fmShareDenyRead;
  if fileexists(aFileName) then
    deletefile(aFileName);
  md := md or fmcreate;

  fstm := TBufferedFileStream.Create(aFileName, md);
  try
    self.SaveToStream(fstm);
    fstm.FlushBuffer;
  finally
    fstm.Free;
  end;

end;

procedure TFMFFile_help.SaveToStream(aStream: TStream);
begin
  aStream.Write(self.FileBytes, length(self.FileBytes));
end;

{
  procedure TFMFFile_help.Write(aBytes: TBytes);
  var
  l: integer;
  begin
  self.Head.Write(aBytes);
  self.FileInfo.Write(aBytes);
  l := length(aBytes);
  setlength(FileBytes, l);
  move(aBytes[0], self.FileBytes[0], length(aBytes));
  // aStream.Write(self.FileBytes, self.Head.FileSize);

  // aStream.Write(self.Stop, sizeof(WORD));
  end;
}
procedure TFMFFile_help.Write(aStream: TStream);
begin
  self.Head.Write(aStream);
  self.FileInfo.Write(aStream);

  aStream.Write(self.FileBytes, self.Head.FileSize);

  aStream.Write(self.Stop, sizeof(WORD));
end;

{ TMFStop_help }

procedure TMFStop_help.Init;
begin
  self.low  := 0;
  self.high := 0;
end;

{ TMFFileDesp_help }

procedure TMFFileDesp_help.Clear;
begin
  self.Head.Clear;
  self.FileInfo.Clear;
  self.Position := 0;
end;

procedure TMFFileDesp_help.Read(aStream: TStream);
var
  a      : TBytes;
  sz     : integer;
  ExtSize: Cardinal;
begin
  self.Head.Read(aStream);
  aStream.Read(self.FileInfo.Crc, sizeof(FileInfo.Crc));

  // 这2个必须减去1，因为本来 size会给最后一位加上一个0；

  FileInfo.FileName.Size := Head.HeadSize - sizeof(FileInfo.Crc) - Head.ExtSize;
  FileInfo.FileExt.Size  := Head.ExtSize;
  aStream.Read(FileInfo.FileName.Char, FileInfo.FileName.BufferSize);

  if Head.ExtSize > 0 then
    aStream.Read(FileInfo.FileExt.Char, FileInfo.FileExt.BufferSize);
end;

{ TMPackHeader_help }

procedure TMPackHeader_help.Clear;
begin
  fillchar(Desp, length(Desp), 0);
  fillchar(Version, length(Version), 0);
  FileCount := 0;
end;

function TMPackHeader_help.GetDesp: ansiString;
begin
  // setlength(result, length(self.Desp));
  // move(Desp[0], result[1], length(self.Desp));
  result := pansichar(@Desp[0]);
end;

function TMPackHeader_help.GetIndex: ansiString;
begin
  result := pansichar(@Index[0]);
end;

function TMPackHeader_help.GetVersion: ansiString;
begin
  // setlength(result, length(self.Version));
  // move(Version[0], result[1], length(self.Version));
  result := pansichar(@Version[0]);
end;

procedure TMPackHeader_help.Read(aStream: TStream);
begin
  aStream.Position := 0;
  aStream.Read(self, sizeof(self));
end;

procedure TMPackHeader_help.SetDesp(const Value: ansiString);
var
  l: integer;
begin
  l := length(Value);
  if l > length(Desp) then
    l := length(Desp);
  move(Value[1], Desp[0], l);
end;

procedure TMPackHeader_help.SetIndex(const Value: ansiString);
var
  l: integer;
begin
  l := length(Value);
  if l > length(Index) then
    l := length(Index);
  move(Value[1], Index[0], l);
end;

procedure TMPackHeader_help.SetVersion(const Value: ansiString);
var
  l: integer;
begin
  l := length(Value);
  if l > length(Version) then
    l := length(Version);
  move(Value[1], Version[0], l);

end;

procedure TMPackHeader_help.Write(aStream: TStream);
begin
  aStream.Position := 0;
  aStream.Write(self, sizeof(self));
end;

end.
