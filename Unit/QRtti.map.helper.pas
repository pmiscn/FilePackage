unit QRtti.map.helper;

interface

uses QRtti.map, system.classes, system.sysutils, system.generics.defaults,
  system.generics.collections;

type
  TQMapExt<TKey, TValue> = class(TQMap<TKey, TValue>)
    public type
      TValues = array of TValue;
    public
      function Find(const AKey: TKey; var AValue: TValue; var APriorValues: TValues; var ANextValues: TValues;
        aPriorCount: integer = 0; aNextCount: integer = 0): Boolean; overload;
  end;

implementation

{ TQMapExt<TKey, TValue> }

function TQMapExt<TKey, TValue>.Find(const AKey: TKey; var AValue: TValue; var APriorValues, ANextValues: TValues;
  aPriorCount, aNextCount: integer): Boolean;
var
  ANode         : PQRBTreeNode;
  ANodeP, aNodeN: PQRBTreeNode;
  c, l          : cardinal;
begin
  ANode  := InternalFind(AKey);
  Result := Assigned(ANode);

  if Result then
  begin
    AValue := ANode.Pair.Value
  end else begin
    AValue := default (TValue);
    exit;
  end;
  if aPriorCount > 0 then
  begin
    c := 0;
    while c < aPriorCount do
    begin
      ANodeP := ANode.Prior;
      if ANodeP <> nil then
      begin

        l := length(APriorValues);
        setlength(APriorValues, l + 1);
        APriorValues[l] := ANodeP.Pair.Value;

        inc(c);
      end;
    end;
  end;
  if aNextCount > 0 then
  begin
    c := 0;
    while c < aNextCount do
    begin
      aNodeN := ANode.Next;
      if aNodeN <> nil then
      begin
        l := length(ANextValues);
        setlength(ANextValues, l + 1);
        APriorValues[l] := aNodeN.Pair.Value;

        inc(c);
      end;
    end;
  end;

end;

end.
