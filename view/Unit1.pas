unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  MFP.Types, MFP.Utils, jpeg, MFP.Crud, MFP.index, MFP.index.hash, MFP.index.rbtree, MFP.Package,
  qstring,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Image1: TImage;
    Memo1: TMemo;
    Edit1: TEdit;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    Edit2: TEdit;
    Button11: TButton;
    Label1: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    private
      { Private declarations }
    public
      { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses mu.fileinfo;
{$R *.dfm}

procedure TForm1.Button10Click(Sender: TObject);
var
  IndexHash: TMFIndexHash;
  Finded   : TMFPosFindedArray;
  c        : integer;
  bt       : TBytes;
  stm      : TmemoryStream;

  fd: TMFFileDesp;
begin

  IndexHash := TMFIndexHash.Create('h:\1638.mpkg');
  try

    c := IndexHash.GetOne(strtoint64(Edit2.Text), fd, bt);

    Memo1.Lines.Add(format('%u,%u,%s', [fd.Position, fd.Head.FileSize, fd.fileinfo.FileName.Asstring]));
    if c > 0 then
    begin
      stm := TmemoryStream.Create;
      try
        stm.Write(bt, length(bt));
        stm.Position := 0;
        self.Image1.Picture.LoadFromStream(stm);
      finally
        stm.Free;
      end;
    end;
  finally

    IndexHash.Free;
  end;

end;

procedure TForm1.Button11Click(Sender: TObject);
var
  FFStream    : TfileStream;
  pos, stmSize: uint64;
  FPackHeader : TMPackHeader;
  Head        : TMFHead;
  fileinfo    : TMFFileInfo;
  fn          : ansistring;
  st          : TStringlist;
  c           : integer;
begin
  c        := 0;
  FFStream := TfileStream.Create('h:\1638.mpkg', fmOpenRead or fmShareDenyRead);
  FPackHeader.Read(FFStream);
  pos     := sizeof(FPackHeader);
  stmSize := FFStream.Size;
  st      := TStringlist.Create;
  try

    while true do
    begin
      if pos >= stmSize then
        break;
      FFStream.Position := pos;
      Head.Read(FFStream);

      fileinfo.Read(FFStream, Head.HeadSize);
      fn := fileinfo.FileName.Asstring;
      // hs := HashOf(pansichar(fn), length(fn));

      // FNodes.Add(hs, pos);

      // if assigned(FOnProgress) then
      // FOnProgress(c, FPackHeader.FileCount);

      st.Add(format('%u' + #9 + '%u' + #9 + '%s', [pos, Head.FileSize, fn]));

      pos := pos + Head.FileSize + Head.FilePos + sizeof(TMFStop);
      inc(c);
      if c mod 1000 = 0 then
      begin
        caption := c.ToString;
        application.ProcessMessages;
      end;
    end;
    caption := c.ToString;
    st.SaveToFile(getexepath + 'tmp.txt');
  finally
    st.Free;
    FFStream.Free;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  st    : TStringlist;
  stm   : TBufferedfileStream;
  i     : integer;
  MFFile: TFMFFile;
  md    : word;
  fn    : String;
begin
  st := TStringlist.Create;
  fn := getexepath + 'pb.mfpk';
  md := fmOpenReadWrite;
  if not fileexists(fn) then
    md := md or fmcreate;
  stm  := TBufferedfileStream.Create(fn, md);
  try
    FileFind(getexepath + 'files\', '*.jpg', st);
    stm.Position := stm.Size;
    for i        := 0 to st.Count - 1 do
    begin
      MFFile.LoadFromFile(st[i], true);
      MFFile.Write(stm);
    end;
    self.caption := 'end';

  finally
    st.Free;
    stm.Free;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  idx: TMFIndexHash;
begin
  idx := TMFIndexHash.Create(getexepath + 'pb.mfpk');
  try
    idx.Rebuild;
  finally
    idx.Free;
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  Package: TMFPackage;
begin
  Package               := TMFPackage.Create(getexepath + 'pb.mfpk');
  package.OnGetFileName := procedure(const aFileName: ansistring; var aNewFileName: ansistring)
    begin
      aNewFileName := extractfilename(changefileext(aFileName, ''));
    end;
  try
    Package.AppendDir(getexepath + 'files');

  finally
    package.Free;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  c, l: Cardinal;
  // Head: TMFHead;
  // fileinfo: TMFFileInfo;
  MFFile: TFMFFile;
  stm   : TmemoryStream;
  fd    : TMFFileDesp;
  fn    : String;

  ss: TArray<AnsiChar>;
  s : ansistring;
begin

  fn := getexepath + 'tmp.tmp';
  MFFile.LoadFromFile(getexepath + 'tmp.jpg', true, false);
  stm := TmemoryStream.Create;
  try

    stm.Position := 0;
    MFFile.Write(stm);
    stm.SaveToFile(fn);

    stm.Position := 0;
    fd.Read(stm);

    fn := fd.fileinfo.FileName.Asstring;

    // fd.Read(stm) ;

    // stm.Clear;
    // MFFile.fileinfo.Write(stm);
    // stm.SaveToFile(fn);

    // stm.LoadFromFile(fn);
    // stm.Position := 0;
    // fileinfo.Read(stm, MFFile.fileinfo.Size);

  finally
    stm.Free;
  end;

end;

procedure TForm1.Button5Click(Sender: TObject);
var
  IndexHash: TMFIndexHash;
  Finded   : TMFPosFindedArray;
  c        : integer;
  bt       : TBytes;
  stm      : TmemoryStream;
  t, i     : integer;
begin
  t         := GetTickCount;
  IndexHash := TMFIndexHash.Create('e:\1638.mpkg');
  Memo1.Lines.Add(format('%d', [GetTickCount - t]));

  t     := GetTickCount;
  for i := 0 to 200000 do
  begin
    setlength(Finded, 0);
    c := IndexHash.Find(Edit1.Text, Finded);
  end;
  Memo1.Lines.Add(format('findfile %d,used:%d', [c, GetTickCount - t]));

  if c > 0 then
  begin
    t := GetTickCount;
    c := IndexHash.GetOne(Finded[0].pos, bt);

    Memo1.Lines.Add(format('%d', [GetTickCount - t]));

    if c > 0 then
    begin
      stm := TmemoryStream.Create;
      try
        stm.Write(bt, length(bt));
        stm.Position := 0;
        self.Image1.Picture.LoadFromStream(stm);
      finally
        stm.Free;
      end;
    end;

  end;

  IndexHash.Free;
end;

procedure TForm1.Button6Click(Sender: TObject);
var
  IndexHash: TMFIndexRBTree;
  Finded   : TMFPosFindedArray;
  c        : integer;
  bt       : TBytes;
  stm      : TmemoryStream;
  t, i     : integer;
begin
  t         := GetTickCount;
  IndexHash := TMFIndexRBTree.Create('h:\1638.mpkg');
  Memo1.Lines.Add(format('%d', [GetTickCount - t]));

  t     := GetTickCount;
  for i := 0 to 100000 do
  begin
    setlength(Finded, 0);
    c := IndexHash.Find(Edit1.Text, Finded);
  end;
  Memo1.Lines.Add(format('findfile %d,used:%d', [c, GetTickCount - t]));

  if c > 0 then
  begin
    t := GetTickCount;
    c := IndexHash.GetOne(Finded[0].pos, bt);

    Memo1.Lines.Add(format('%d', [GetTickCount - t]));

    if c > 0 then
    begin
      stm := TmemoryStream.Create;
      try
        stm.Write(bt, length(bt));
        stm.Position := 0;
        self.Image1.Picture.LoadFromStream(stm);
      finally
        stm.Free;
      end;
    end;

  end;

  IndexHash.Free;

end;

procedure TForm1.Button7Click(Sender: TObject);
var
  IndexHash: TMFIndexRBTree;
  Finded   : TMFPosFindedArray;
  c        : integer;
  bt       : TBytes;
  stm      : TmemoryStream;
  t, i     : integer;
begin
  t         := GetTickCount;
  IndexHash := TMFIndexRBTree.Create('e:\1638.mpkg');
  Memo1.Lines.Add(format('%d', [GetTickCount - t]));
  try

    t     := GetTickCount;
    for i := 0 to 0 do
    begin
      setlength(Finded, 0);
      c := IndexHash.between(Edit1.Text, Edit1.Text + 'zzzz', Finded);
    end;
    Memo1.Lines.Add(format('findfile %d,used:%d', [c, GetTickCount - t]));

    if c > 0 then
    begin
      t := GetTickCount;
      c := IndexHash.GetOne(Finded[0].pos, bt);

      Memo1.Lines.Add(format('%d', [GetTickCount - t]));
      Memo1.Lines.Add(Finded[0].FileName);

      if c > 0 then
      begin
        stm := TmemoryStream.Create;
        try
          stm.Write(bt, length(bt));
          stm.Position := 0;
          self.Image1.Picture.LoadFromStream(stm);
        finally
          stm.Free;
        end;
      end;

    end;

  finally

    IndexHash.Free;
  end;
end;

procedure TForm1.Button8Click(Sender: TObject);
var
  IndexHash: TMFIndexHash;
  Finded   : TMFHashPos;
  FileDesp : TMFFileDesp;
  Head     : TMFHead;
  i        : integer;
  st       : TStringlist;
  bs       : uint64;
begin
  IndexHash := TMFIndexHash.Create('h:\1638.mpkg', false, true,
    procedure(aCurrent, aTotal: Cardinal)
    begin
      if aCurrent mod 1000 = 0 then
      begin
        Label1.caption := (format('Rebuild %d/%d', [aCurrent, aTotal]));
        application.ProcessMessages;
      end;
    end);

  st := TStringlist.Create;
  try
    IndexHash.Rebuild;
    for i := 0 to high(IndexHash.Nodes.Data) do
    begin
      Finded := IndexHash.Nodes.Data[i];
      // IndexHash.Stream.Position:=finded.Pos;
      // Head.Read(IndexHash.Stream);
      // FileDesp := IndexHash.GetFileDesp(Finded.pos);
      // if FileDesp.fileinfo.Size > 200000 then
      begin
        // try
        // st.Add(format('%d,%d,%s', [FileDesp.Position, FileDesp.fileinfo.Size, FileDesp.fileinfo.FileName.AsString]));
        // except
        // st.Add(format('%u,%u', [Finded.Pos, Head.FileSize]));

        st.Add(format('%u', [Finded.pos]));
        // end;

      end;

      if i mod 1000 = 0 then
      begin
        caption := inttostr(i);
        application.ProcessMessages;
      end;
    end;

    st.SaveToFile(getexepath + 'tmp.txt');
  finally
    st.Free;
    IndexHash.Free;
  end;

end;

procedure TForm1.Button9Click(Sender: TObject);
var
  FileDesp: TMFFileDesp;
  i       : integer;
begin
  for i := 0 to 10000 do
  begin
    FileDesp.fileinfo.FileName.Size := 255;
    begin
      caption := inttostr(i);
      application.ProcessMessages;
    end;
  end;
end;

end.
