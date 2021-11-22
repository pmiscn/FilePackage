unit frmCrud;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  MFP.Crud, MFP.Types, MFP.Utils, MFP.Index, MFP.Package,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls;

type
  TForm2 = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    OpenDialog1: TOpenDialog;
    Button1: TButton;
    Memo1: TMemo;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Edit1: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    private
      Elec: TMFElec;
    public

  end;

var
  Form2: TForm2;

implementation

uses Mu.fileinfo;
{$R *.dfm}

procedure TForm2.Button1Click(Sender: TObject);
begin
  Elec               := TMFElec.Create(getexepath + 'package\test' + PubPackageExt, tmrwlevel.rwlReadWrite);
  Elec.OnGetFileName := procedure(const aFileName: AnsiString; var aNewFileName: AnsiString; var aExt: AnsiString)
    begin
      aExt         := extractfileext(aFileName);
      aNewFileName := extractfilename(aFileName);
    end;
end;

procedure TForm2.Button2Click(Sender: TObject);
var
  fd: TMFPosFindedArray;
  i : integer;
  s : String;
  bs: TBytes;
begin
  Elec.Find(Edit1.Text, fd);
  for i := Low(fd) to High(fd) do
  begin
    Memo1.Lines.Add(format('index %d;pos:%d', [fd[i].Index, fd[i].Pos]));
    Elec.GetOne(fd[i].Pos, bs);
    s := stringof(bs);
    Memo1.Lines.Add(s);
  end;
end;

procedure TForm2.Button4Click(Sender: TObject);
begin
  if self.OpenDialog1.Execute then
  begin
    Elec.AppendFile(self.OpenDialog1.FileName);
    self.Edit1.Text := extractfilename(OpenDialog1.FileName);
  end;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  //
end;

procedure TForm2.FormDestroy(Sender: TObject);
begin
  if assigned(Elec) then
    Elec.Free;
end;

end.
