unit Mu.Pool.St;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  QSimplePool, Generics.Collections,
  SyncObjs, qstring,
  System.Classes;

type
  TListPool<T> = class(TObject)
  private
    FOutObj: Tlist;
    FPool: TQSimplePool;
    procedure FOnObjectCreate(Sender: TQSimplePool; var AData: Pointer);
    procedure FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
    procedure FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
  protected

  public
    constructor Create(Poolsize: integer = 100);
    destructor Destroy; override;
    function get(): Tlist<T>;
    procedure return(aSt: Tlist<T>);
    procedure release(aSt: Tlist<T>);

  end;

  TStPool = class(TObject)
  private
    FPool: TQSimplePool;
    procedure FOnObjectCreate(Sender: TQSimplePool; var AData: Pointer);
    procedure FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
    procedure FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
  protected

  public
    constructor Create(Poolsize: integer = 100);
    destructor Destroy; override;
    function get(): tstringlist;
    procedure return(aSt: tstringlist);
    procedure release(aSt: tstringlist);

  end;

  TStmPool = class(TObject)
  private
    FPool: TQSimplePool;
    procedure FOnObjectCreate(Sender: TQSimplePool; var AData: Pointer);
    procedure FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
    procedure FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
  protected

  public
    constructor Create(Poolsize: integer = 100);
    destructor Destroy; override;
    function get(): TMemoryStream;
    procedure return(aStm: TMemoryStream);
    procedure release(aStm: TMemoryStream);

  end;

  TFixStmPool = class(TObject)
  private
    FFixSize: integer;
    FPool: TQSimplePool;
    procedure FOnObjectCreate(Sender: TQSimplePool; var AData: Pointer);
    procedure FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
    procedure FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
  protected

  public
    constructor Create(aFixSize: integer; Poolsize: integer = 100);
    destructor Destroy; override;
    function get(): TMemoryStream;
    procedure return(aStm: TMemoryStream);

  end;

var
  stmPool: TStmPool;
  stPool: TStPool;

implementation

{ TstPool }

constructor TStPool.Create(Poolsize: integer);
begin

  FPool := TQSimplePool.Create(Poolsize, FOnObjectCreate, FOnObjectFree,
    FOnObjectReset);
end;

destructor TStPool.Destroy;
begin
  FPool.Free;
  inherited;
end;

procedure TStPool.FOnObjectCreate(Sender: TQSimplePool; var AData: Pointer);
begin
  tstringlist(AData) := tstringlist.Create;
end;

procedure TStPool.FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
begin
  tstringlist(AData).Free;
end;

procedure TStPool.FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
begin
  tstringlist(AData).Clear;
end;

function TStPool.get: tstringlist;
begin
  result := tstringlist(FPool.pop);
end;

procedure TStPool.release(aSt: tstringlist);
begin
  aSt.Clear;
  FPool.push(aSt);
end;

procedure TStPool.return(aSt: tstringlist);
begin
  release(aSt);
end;

{ TStmPool }

constructor TStmPool.Create(Poolsize: integer);
begin
  FPool := TQSimplePool.Create(Poolsize, FOnObjectCreate, FOnObjectFree,
    FOnObjectReset);
end;

destructor TStmPool.Destroy;
var
  i: integer;
begin
  FPool.Free;
  inherited;
end;

procedure TStmPool.FOnObjectCreate(Sender: TQSimplePool; var AData: Pointer);
begin
  TMemoryStream(AData) := TMemoryStream.Create;
end;

procedure TStmPool.FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
begin
  TMemoryStream(AData).Free;
end;

procedure TStmPool.FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
begin
  TMemoryStream(AData).Clear;
end;

function TStmPool.get: TMemoryStream;
begin
  result := TMemoryStream(FPool.pop);
end;

procedure TStmPool.release(aStm: TMemoryStream);
begin
  aStm.Clear;
  FPool.push(aStm);
end;

procedure TStmPool.return(aStm: TMemoryStream);
begin
  release(aStm);
end;

{ TListPool<T> }

constructor TListPool<T>.Create(Poolsize: integer);
begin
  FPool := TQSimplePool.Create(Poolsize, FOnObjectCreate, FOnObjectFree,
    FOnObjectReset);
end;

destructor TListPool<T>.Destroy;
var
  i: integer;
begin
  FPool.Free;
  inherited;
end;

procedure TListPool<T>.FOnObjectCreate(Sender: TQSimplePool;
  var AData: Pointer);
begin
  Tlist<T>(AData) := Tlist<T>.Create;
end;

procedure TListPool<T>.FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
begin
  Tlist<T>(AData).Clear;
  Tlist<T>(AData).Free;
end;

procedure TListPool<T>.FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
begin
  Tlist<T>(AData).Clear;
end;

function TListPool<T>.get: Tlist<T>;
begin
  result := Tlist<T>(FPool.pop);
end;

procedure TListPool<T>.release(aSt: Tlist<T>);
begin
  if aSt <> nil then
    aSt.Clear;
  // FLock.Enter;
  try
    FOutObj.Remove(aSt);
  finally
    // FLock.Leave;
  end;
  FPool.push(aSt);
end;

procedure TListPool<T>.return(aSt: Tlist<T>);
begin
  release(aSt);
end;

{ TFixStmPool }

constructor TFixStmPool.Create(aFixSize: integer; Poolsize: integer);
begin
  FFixSize := aFixSize;
  FPool := TQSimplePool.Create(Poolsize, FOnObjectCreate, FOnObjectFree,
    FOnObjectReset);
end;

destructor TFixStmPool.Destroy;
begin
  FPool.Free;
  inherited;
end;

procedure TFixStmPool.FOnObjectCreate(Sender: TQSimplePool; var AData: Pointer);
var
  stm: TMemoryStream;
begin
  stm := TMemoryStream.Create;
  stm.Size := FFixSize;
  AData := stm;
end;

procedure TFixStmPool.FOnObjectFree(Sender: TQSimplePool; AData: Pointer);
begin
  TMemoryStream(AData).Free;
end;

procedure TFixStmPool.FOnObjectReset(Sender: TQSimplePool; AData: Pointer);
begin
  ZeroMemory(TMemoryStream(AData).Memory, self.FFixSize);
end;

function TFixStmPool.get: TMemoryStream;
begin
  result := TMemoryStream(FPool.pop);
end;

procedure TFixStmPool.return(aStm: TMemoryStream);
begin
  FPool.push(aStm);
end;

initialization

stPool := TStPool.Create(10);
stmPool := TStmPool.Create(10);

finalization

stPool.Free;;
stmPool.Free;

end.
