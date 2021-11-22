unit FrmMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  MFP.Types, MFP.Utils, jpeg, MFP.Crud, MFP.index, MFP.index.hash, MFP.index.rbtree, MFP.Package,
  Generics.Collections, qstring, qjson, qworker,
  Vcl.Controls, Vcl.ComCtrls, Vcl.ToolWin, System.ImageList, Vcl.forms, Vcl.ImgList, Vcl.Buttons, Vcl.StdCtrls,
  Vcl.ExtCtrls, System.Actions, Vcl.ActnList, Vcl.Menus, Vcl.Grids, Vcl.ValEdit, VirtualTrees, Vcl.Dialogs;

type
  PNamePath = ^TNamePath;

  TNamePath = record
    path: string[255];
  end;

  PNodeFile = ^TNodeFile;

  TNodeFile = record
    index: cardinal;
    pos: Uint64;
  end;

  TNodeFiles = TArray<TNodeFile>;

  TLoadedElecs = tdictionary<string, TMFElec>;

  TForm1 = class(TForm)
    ImageListTool: TImageList;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    StatusBar1: TStatusBar;
    Panel1: TPanel;
    Splitter1: TSplitter;
    tvPackage: TTreeView;
    ActionList1: TActionList;
    ImageListFiles: TImageList;
    acOpen: TAction;
    acNew: TAction;
    acExprotFile: TAction;
    AcDel: TAction;
    acRebuild: TAction;
    acAddFolder: TAction;
    ToolButton6: TToolButton;
    ToolButton7: TToolButton;
    PopupMenuFiles: TPopupMenu;
    PageControl1: TPageControl;
    Splitter2: TSplitter;
    TSFile: TTabSheet;
    vleFiles: TValueListEditor;
    vlePackage: TValueListEditor;
    ButtonedEdit1: TButtonedEdit;
    FileOpenDialog1: TFileOpenDialog;
    acExportFolder: TAction;
    tsPacakge: TTabSheet;
    SaveDialog1: TSaveDialog;
    acCopy: TAction;
    N1: TMenuItem;
    N2: TMenuItem;
    PopupMenuTree: TPopupMenu;
    N3: TMenuItem;
    PageControl2: TPageControl;
    ts_files: TTabSheet;
    sgFiles: TStringGrid;
    ts_fild: TTabSheet;
    sg_finded: TStringGrid;
    Panel2: TPanel;
    L_status: TLabel;
    Button1: TButton;
    ProgressBar1: TProgressBar;
    procedure Button11Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvPackageChange(Sender: TObject; Node: TTreeNode);
    procedure sgFilesTopLeftChanged(Sender: TObject);
    procedure vlePackageStringsChange(Sender: TObject);
    procedure vlePackageMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure acOpenExecute(Sender: TObject);
    procedure acAddFolderExecute(Sender: TObject);
    procedure sgFilesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure acExprotFileExecute(Sender: TObject);
    procedure acCopyExecute(Sender: TObject);
    procedure N3Click(Sender: TObject);
    procedure ButtonedEdit1RightButtonClick(Sender: TObject);
    procedure acExportFolderExecute(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    private
      FCurPackage  : String;
      FLoadEnd     : Boolean;
      FPackagesJson: TQjson;
      FLoadedElecs : TLoadedElecs;
      FCurElec     : TMFElec;
      FNodeFiles   : TNodeFiles;
      procedure loadDefault();
      procedure SaveDefault();
      procedure ShowCaption(aValue: String);
      procedure AddPackage(aPackagePath: String);
      procedure LoadPackage(aPackagePath: String);
      procedure ShowPackage(aElec: TMFElec);
      procedure ShowStatus(aStatus: String);
      procedure ShowGrid(aFileChanged: Boolean);
      procedure ShowFileHeader(dp: TMFFileDesp);
      procedure ShowPackageHeader(ph: TMPackHeader);
    public
      { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses CommCtrl, clipbrd, mu.fileinfo;
{$R *.dfm}

const
  OddLineColor  = $00EBEBEB;
  EvenLineColor = $00FFFFFF;

var
  iaContinue: Boolean = true;

procedure TForm1.acAddFolderExecute(Sender: TObject);
var
  st: TStringlist;
  fn: String;
  i : Integer;
begin
  with FileOpenDialog1 do
  begin
    options := options + [fdopickfolders];
    if execute then
    begin
      st := TStringlist.Create;
      try
        filefind(filename, '*.mpkg', st);
        for i := 0 to st.Count - 1 do
        begin
          AddPackage(st[i]);
        end;
      finally
        st.Free;
      end;

    end;
  end;
end;

procedure TForm1.acCopyExecute(Sender: TObject);
var
  bs  : TBytesArray;
  r, c: Integer;
  fn  : String;
  fa  : TMFPosFindedArray;
  i   : Integer;
  stm : TfileStream;
begin
  if not(screen.ActiveControl is TStringGrid) then
    exit;

  r := TStringGrid(screen.ActiveControl).Row;
  if r = 0 then
    exit;
  fn := TStringGrid(screen.ActiveControl).Cells[1, r];

  Clipboard.AsText := fn;
end;

procedure TForm1.acExportFolderExecute(Sender: TObject);
var

  path: String;
  p   : PNamePath;

begin
  with FileOpenDialog1 do
  begin
    options := options + [fdopickfolders];
    if execute then
    begin
      path := filename;
    end
    else
      exit;
  end;

  if path[length(path)] <> '\' then
    path := path + '\';
  Panel2.Show;
  new(p);
  p.path := path;
  workers.Post(
    procedure(AJob: PQJob)
    var
      p: string;
      c: cardinal;
      fn: String;
      stm: TfileStream;
    begin
      p := PNamePath(AJob.Data).path;
      c := self.FCurElec.FileCount;

      iaContinue := true;

      FCurElec.Each(
        procedure(const aIndex: cardinal; const afileName: ansistring; const aPos: Uint64; aFileDesp: TMFFileDesp;
          aOutput: TBytes; var AContinue: Boolean)
        begin
          AContinue := iaContinue;
          inc(c);
          fn := p + afileName + aFileDesp.fileinfo.FileExt.AsString;
          stm := TfileStream.Create(fn, fmcreate or fmOpenReadWrite);
          try
            stm.Position := 0;
            stm.Write(aOutput, length(aOutput));
            if c mod 100 = 0 then
            begin
              AJob.Synchronize(
                procedure()
                begin
                  self.ProgressBar1.Position := aIndex * 100 div c;
                  self.L_status.Caption := (format('%d/%d %s', [aIndex, c, afileName]));
                  application.ProcessMessages;
                end);
            end;
          finally
            stm.Free;
          end;

        end);
      AJob.Synchronize(
        procedure()
        begin
          Panel2.Hide;
        end);
    end, p, false, jdfFreeAsSimpleRecord);
end;

procedure TForm1.acExprotFileExecute(Sender: TObject);
var
  bs  : TBytesArray;
  r, c: Integer;
  fn  : String;
  fa  : TMFPosFindedArray;
  i   : Integer;
  stm : TfileStream;
begin
  if not(screen.ActiveControl is TStringGrid) then
    exit;

  r := TStringGrid(screen.ActiveControl).Row;
  if r = 0 then
    exit;
  fn := TStringGrid(screen.ActiveControl).Cells[1, r];

  bs    := self.FCurElec.Files[fn];
  for i := 0 to High(bs) do
  begin
    SaveDialog1.filename := fn;
    if not self.SaveDialog1.execute then
      continue;

    stm := TfileStream.Create(SaveDialog1.filename, fmcreate or fmOpenReadWrite);
    try
      stm.Position := 0;
      stm.Write(bs[i], length(bs[i]));

    finally
      stm.Free;
    end;
  end;

end;

procedure TForm1.acOpenExecute(Sender: TObject);
begin
  with FileOpenDialog1 do
  begin
    options := options - [fdopickfolders];

    if execute then
    begin
      AddPackage(filename);
    end;
  end;
end;

procedure TForm1.AddPackage(aPackagePath: String);
var
  js: TQjson;
begin

  for js in FPackagesJson do
  begin
    if js.ValueByName('package', '').ToLower = aPackagePath.ToLower then
    begin
      showmessage(format('%s 已经在列表中。', [aPackagePath]));
      exit;
    end;
  end;

  js := FPackagesJson.Add();

  js.Add('package').AsString := aPackagePath;
  with tvPackage.Items.Add(nil, extractfilename(changefileext(aPackagePath, ''))) do
  begin
    Data := js;
  end;
  SaveDefault;
end;

procedure TForm1.Button11Click(Sender: TObject);
var
  FFStream    : TfileStream;
  pos, stmSize: Uint64;
  FPackHeader : TMPackHeader;
  Head        : TMFHead;
  fileinfo    : TMFFileInfo;
  fn          : ansistring;
  st          : TStringlist;
  c           : Integer;
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
      fn := fileinfo.filename.AsString;
      // hs := HashOf(pansichar(fn), length(fn));

      // FNodes.Add(hs, pos);

      // if assigned(FOnProgress) then
      // FOnProgress(c, FPackHeader.FileCount);

      st.Add(format('%u' + #9 + '%u' + #9 + '%s', [pos, Head.FileSize, fn]));

      pos := pos + Head.FileSize + Head.FilePos + sizeof(TMFStop);
      inc(c);
      if c mod 1000 = 0 then
      begin
        Caption := c.ToString;
        application.ProcessMessages;
      end;
    end;
    Caption := c.ToString;
    st.SaveToFile(getexepath + 'tmp.txt');
  finally
    st.Free;
    FFStream.Free;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  iaContinue := false;
end;

procedure TForm1.ButtonedEdit1RightButtonClick(Sender: TObject);
var
  s: String;

  Finded : TMFPosFindedArray;
  i, c, r: Integer;
  ps     : Uint64;
  dps    : TMFFileDesp;
begin
  s := ButtonedEdit1.Text;
  self.ts_fild.Show;
  c := self.FCurElec.Find(s, Finded);

  self.sg_finded.RowCount := c + 1;

  for i := Low(Finded) to High(Finded) do
  begin
    r                     := i + 1;
    ps                    := (Finded[i].pos);
    dps                   := FCurElec.Package.FileDesps[ps];
    sg_finded.Cells[0, r] := r.ToString;

    sg_finded.Cells[1, r] := dps.fileinfo.filename.AsString;
    sg_finded.Cells[2, r] := qstring.RollupSize(dps.Head.FileSize);
    sg_finded.Cells[3, r] := dps.fileinfo.Crc.Crc.ToString;
    sg_finded.Cells[4, r] := dps.Head.Switch.Zip.ToString();
    sg_finded.Cells[5, r] := dps.Head.Switch.Aes.ToString();

    sg_finded.Cells[6, r] := dps.fileinfo.FileExt.AsString;
  end;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  self.sgFiles.Cells[1, 0] := '文件名';
  self.sgFiles.Cells[2, 0] := '大小';
  self.sgFiles.Cells[3, 0] := 'CRC';
  self.sgFiles.Cells[4, 0] := '压缩';
  self.sgFiles.Cells[5, 0] := '加密';
  self.sgFiles.Cells[6, 0] := '扩展';

  self.sg_finded.Cells[1, 0] := '文件名';
  self.sg_finded.Cells[2, 0] := '大小';
  self.sg_finded.Cells[3, 0] := 'CRC';
  self.sg_finded.Cells[4, 0] := '压缩';
  self.sg_finded.Cells[5, 0] := '加密';
  self.sg_finded.Cells[6, 0] := '扩展';

  // ToolButton1.ScaleForPPI(150);

  FPackagesJson := TQjson.Create;
  FLoadedElecs  := TLoadedElecs.Create;
  workers.Delay(
    procedure(AJob: PQJob)
    begin
      loadDefault();
    end, 400, nil, true);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FPackagesJson.Free;
  FLoadedElecs.Free;
end;

procedure TForm1.sgFilesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  r, c: Integer;
  fd  : TMFFileDesp;
var
  bs: TBytesArray;

  fn : String;
  fa : TMFPosFindedArray;
  i  : Integer;
  stm: TfileStream;

begin
  sgFiles.MouseToCell(X, Y, c, r);
  if (c > 0) and (c > 0) then
  begin
    self.TSFile.Show;
   exit;
    if not(screen.ActiveControl is TStringGrid) then
      exit;

    r := TStringGrid(screen.ActiveControl).Row;
    if r = 0 then
      exit;
    fn := TStringGrid(screen.ActiveControl).Cells[1, r];
  //  FCurElec.Find(fn) ;
//    bs    := self.FCurElec.Files[fn];
 //   for i := 0 to High(bs) do
    begin

    end;

  end;
end;

procedure TForm1.sgFilesTopLeftChanged(Sender: TObject);
begin
  self.ShowGrid(false);

end;

procedure TForm1.loadDefault;
var
  js: TQjson;
  fn: String;
  pn: String;
begin
  fn := getexepath + '\data\packages.json';
  if fileExists(fn) then
    FPackagesJson.LoadFromFile(fn);
  tvPackage.Items.BeginUpdate;
  try
    for js in FPackagesJson do
    begin
      pn := js.ValueByName('package', '');
      //
      with tvPackage.Items.Add(nil, extractfilename(changefileext(pn, ''))) do
      begin
        Data := js;
      end;

    end;
  finally
    tvPackage.Items.EndUpdate;
  end;
end;

procedure TForm1.LoadPackage(aPackagePath: String);
var
  elec: TMFElec;
begin
  if aPackagePath = FCurPackage then
    exit;
  FCurPackage := aPackagePath;

  if not self.FLoadedElecs.TryGetValue(aPackagePath, elec) then
  begin
    ShowStatus('加载中...');
    workers.Post(
      procedure(AJob: PQJob)
      begin
        FLoadEnd := false;
        elec := TMFElec.Create(aPackagePath, rwlReadWrite);
        FLoadedElecs.Add(aPackagePath, elec);
        ShowStatus('加载包完成');
        FCurElec := elec;
        ShowPackage(elec);
        self.FLoadEnd := true;
      end, nil, true);
  end else begin
    FCurElec := elec;
    ShowPackage(elec);
  end;
  self.ShowCaption(aPackagePath);
end;

procedure TForm1.N3Click(Sender: TObject);
var
  Node: TTreeNode;
  js  : TQjson;
  pn  : String;
begin
  Node := self.tvPackage.Selected;
  if Node = nil then
    exit;

  if messagebox(self.Handle, pchar('确定要从列表删除' + Node.Text + '吗？'), '确认', mb_YESNO) <> ID_YES then
    exit;
  Node.Delete;
  js := TQjson(Node.Data);
  js.Delete();
  SaveDefault;

end;

procedure TForm1.SaveDefault;
var
  fn: String;
begin
  fn := getexepath + '\data\packages.json';
  self.FPackagesJson.SaveToFile(fn);
end;

procedure TForm1.ShowCaption(aValue: String);
begin
  self.Caption := format('%s - %s', [aValue, application.Title]);
end;

procedure TForm1.ShowFileHeader(dp: TMFFileDesp);
begin
  //
end;

procedure TForm1.ShowGrid(aFileChanged: Boolean);
var
  i, r, c: Integer;
  dps    : TMFFileDesps;
begin
  r   := self.sgFiles.TopRow;
  c   := sgFiles.VisibleRowCount;
  dps := FCurElec.FileDesps[r, c];

  for i := 0 to High(dps) do
  begin

    if (sgFiles.Cells[0, r] = '') or (aFileChanged) then
    begin
      sgFiles.Cells[0, r] := r.ToString;

      sgFiles.Cells[1, r] := dps[i].fileinfo.filename.AsString;
      sgFiles.Cells[2, r] := qstring.RollupSize(dps[i].Head.FileSize);
      sgFiles.Cells[3, r] := dps[i].fileinfo.Crc.Crc.ToString;
      sgFiles.Cells[4, r] := dps[i].Head.Switch.Zip.ToString();
      sgFiles.Cells[5, r] := dps[i].Head.Switch.Aes.ToString();

      sgFiles.Cells[6, r] := dps[i].fileinfo.FileExt.AsString;
      application.ProcessMessages;

    end;
    inc(r);
  end;
  {
    i := 0;
    while i < c do
    begin

    if (sgFiles.Cells[0, r] = '') or (aFileChanged) then
    begin
    sgFiles.Cells[0, r] := r.ToString;

    dp := FCurElec.FileDesps[r - 1];
    // sgFiles.Cells[1, r] := dp.fileinfo.filename.AsString;
    // sgFiles.Cells[2, r] := qstring.RollupSize(dp.Head.FileSize);

    application.ProcessMessages;

    end;
    inc(i);
    inc(r);

    end;
  }
end;

procedure TForm1.ShowPackage(aElec: TMFElec);
begin
  sgFiles.RowCount := aElec.FileCount;
  ShowGrid(true);
  ShowPackageHeader(aElec.Package.PackHeader);
  // setlength(FNodeFiles, aElec.FileCount);
  // ListView_SetItemCountEx(lvFiles.Handle, aElec.FileCount, LVSICF_NOINVALIDATEALL or LVSICF_NOSCROLL);
  // lvFiles.Items.count := aElec.FileCount;
  // lvFiles.Repaint;
end;

procedure TForm1.ShowPackageHeader(ph: TMPackHeader);
begin
  vlePackage.Values['描述']   := (ph.DespStr);
  vlePackage.Values['索引']   := (ph.IndexStr);
  vlePackage.Values['版本']   := (ph.VersionStr);
  vlePackage.Values['文件数量'] := (ph.FileCount.ToString);

end;

procedure TForm1.ShowStatus(aStatus: String);
begin
  self.StatusBar1.Panels[0].Text := aStatus;
  application.ProcessMessages;
end;

procedure TForm1.tvPackageChange(Sender: TObject; Node: TTreeNode);
var
  js: TQjson;
  pn: String;
begin
  js := TQjson(Node.Data);
  pn := js.ValueByName('package', '');
  self.LoadPackage(pn);
  self.tsPacakge.Show;
  self.ts_files.Show;
end;

procedure TForm1.vlePackageMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  sg        : TValueListEditor;
  ACol, ARow: Integer;

begin
  sg := TValueListEditor(Sender);
  sg.MouseToCell(X, Y, ACol, ARow);
  if ARow > sg.Tag then
  begin
    sg.options := sg.options - [goEditing]
  end else begin
    sg.options := sg.options + [goEditing];

  end;

end;

procedure TForm1.vlePackageStringsChange(Sender: TObject);
begin
  FCurElec.Package.PackHeader.IndexStr := vlePackage.Values['索引'];
  FCurElec.Package.PackHeader.DespStr  := vlePackage.Values['描述'];
  FCurElec.Package.SavePackageHeader;
end;

end.
