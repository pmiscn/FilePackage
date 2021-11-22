unit FrmSqlImport;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, System.zlib, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, MFP.importSQL, MFP.crud, qjson, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFSQLImport = class(TForm)
    Label1: TLabel;
    Timer1: TTimer;
    Label2: TLabel;
    Label3: TLabel;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    private
      MFElec: TMFElec;
    public
      { Public declarations }
  end;

var
  FSQLImport   : TFSQLImport;
  MFPSQLImports: TMFPSQLImports;

implementation

uses mu.fileinfo, MFP.Types;
{$R *.dfm}

procedure TFSQLImport.FormCreate(Sender: TObject);
var
  js, ajs, j: TQJson;
begin

  js := TQJson.Create;

  try
    js.LoadFromFile(getexepath + 'config/config.json');
    if js.HasChild('tasks', ajs) then
    begin
      if ajs.DataType = jdtarray then
      begin
        setlength(MFPSQLImports, ajs.Count);
        for j in ajs do
        begin
          MFPSQLImports[j.ItemIndex] := TMFPSQLImport.Create(j);
        end;
      end else begin
        setlength(MFPSQLImports, 1);
        MFPSQLImports[0] := TMFPSQLImport.Create(ajs);
      end;
    end;
  finally
    js.Free;
  end;
  self.Timer1.Enabled := true;
end;

procedure TFSQLImport.FormDestroy(Sender: TObject);
var
  i: integer;
begin
  for i := Low(MFPSQLImports) to High(MFPSQLImports) do
    MFPSQLImports[i].Free;
end;

procedure TFSQLImport.Timer1Timer(Sender: TObject);
begin

  self.Label1.Caption := format('get   count:%d', [MFPSQLImports.GetCount]);
  self.Label2.Caption := format('pool  count:%d', [MFPSQLImports.PoolCount]);
  self.Label3.Caption := format('write count:%d', [MFPSQLImports.WriteCount]);
end;

end.
