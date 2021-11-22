unit qrtti.map;

interface

uses system.classes, system.sysutils, system.generics.defaults,
  system.generics.collections;

type
  {
    【注意】本单元包含泛型的使用，所以在Delphi 支持泛型格式化前不要格式化代码

    QRtti 是一组对 Delphi Rtti 的功能增强封装，版权归吉林省左右软件开发有限公司所有

    TQMap 是一个基于红黑树实现的映射，具有良好的增删查改综合性能，是 qrbtree 里 TQRBTree 的泛型实现版本。你可以拿它做为
    TDictionary 的替代品而不用担心占用过多的空间（每个元素需要额外增加SizeOf(Pointer)*3字节）

    [使用示例]
    var
    AMap:TQMap<Integer,String>;
    AValue:String;
    APair:TPair<Integer,String>;
    begin
    AMap:=TQMap<Integer,String>.Create;
    AMap.Values[100]:='abc';
    AMap.Values[20]:='ddd';
    ...
    //判断一个元素是否存在
    if AMap.Exists(1999) then
    ...
    //查找指定键对应的值，不同于直接访问 Values 属性，这个可以判断键是否存在，而 Values 如果不存在，会返回默认值
    if AMap.Find(20,AValue) then
    ....
    //删除一个键对应的值
    AMap.Delete(20);
    //循环所有元素方法1
    for APair in AMap do
    begin
    //APair 存贮了其中一个的Key-Value对
    end;
    //循环所有元素方法2，回调也可以为事件，而不是匿名回调
    AMap.ForEach(procedure (AMap:TQMap<Integer,String>;APair:TPair<Integer,String>;var AContinue:Boolean)
    begin
    //在这里处理每一个元素，如果不想继续循环，将AContinue设置为false
    end);
    //元素个数
    AMap.Count
    //判断是否为空
    if AMap.IsEmpty then
    ...
    或
    if AMap.Count=0 then
    ...
    [修订历史]
    2020-8-2
    =========
    + 增加 ForRange 函数
    2020-7-20
    =========
    + 第一个初始版本
  }

TQMap < TKey, TValue >= class(TEnumerable < TPair < TKey, TValue >> ) //
  protected //
  type //
  TKVPair = TPair<TKey, TValue>;
TQMapNotify =
procedure(ASender: TObject; const AValue: TKVPair) of object;
TQMapCallback = reference to
procedure(ASender: TObject; const AValue: TKVPair);
TQMapEnumNotify =
procedure(ASender: TObject; const AValue: TKVPair; var AContinue: Boolean)
  of object;
TQMapEnumCallback = reference to
procedure(ASender: TObject; const AValue: TKVPair; var AContinue: Boolean);
// 结点定义
PQRBTreeNode = ^TQRBTreeNode;
TQRBTreeNode = record //
  Parent_Color: IntPtr;
Left, Right: PQRBTreeNode;
Pair:
TPair<TKey, TValue>;
function GetNext: PQRBTreeNode; inline;
function GetParent: PQRBTreeNode; inline;
function GetPrior: PQRBTreeNode; inline;
function GetIsEmpty: Boolean; inline;
procedure SetBlack; inline;
function RedParent: PQRBTreeNode; inline;
procedure SetParentColor(AParent: PQRBTreeNode; AColor: Integer); inline;
function GetIsBlack: Boolean; inline;
function GetIsRed: Boolean; inline;
procedure SetParent(const Value: PQRBTreeNode); inline;
function GetLeftDeepest: PQRBTreeNode; inline;
procedure Assign(const src: PQRBTreeNode);
function NextPostOrder: PQRBTreeNode;
procedure Clear;
property Next: PQRBTreeNode read GetNext; // rb_next
property Prior: PQRBTreeNode read GetPrior; // rb_prev
property Parent: PQRBTreeNode read GetParent write SetParent; // rb_parent
property IsEmpty: Boolean read GetIsEmpty; // RB_NODE_EMPTY
property IsBlack: Boolean read GetIsBlack; // rb_is_black
property IsRed: Boolean read GetIsRed; // rb_is_red
property LeftDeepest: PQRBTreeNode read GetLeftDeepest;
end;
TPairEnumerator = class(TEnumerator<TKVPair>) //
  private //

var
  FMap: TQMap<TKey, TValue>;
  FCurrent: PQRBTreeNode;

function GetCurrent: TKVPair;
protected
  function DoGetCurrent: TKVPair;override;
  function DoMoveNext: Boolean;override;
public
  constructor Create(const AMap: TQMap<TKey, TValue>);
  property Current: TKVPair read GetCurrent;
  function MoveNext: Boolean;
  end;
protected
  FRoot: PQRBTreeNode;
  FCount: Integer;
  FOnCompare: IComparer<TKey>;
  FOnDelete: TQMapNotify;
  function GetIsEmpty: Boolean;inline;
  procedure RotateSetParents(AOld, ANew: PQRBTreeNode; color: Integer);inline;
  procedure InsertNode(node: PQRBTreeNode);inline;
  procedure EraseColor(AParent: PQRBTreeNode);inline;
  procedure ChangeChild(AOld, ANew, Parent: PQRBTreeNode);inline;
  function EraseAugmented(node: PQRBTreeNode): PQRBTreeNode;inline;
  procedure DoDelete(node: PQRBTreeNode);
  procedure InsertColor(AChild: PQRBTreeNode);inline;
  procedure LinkNode(node, Parent: PQRBTreeNode; var rb_link: PQRBTreeNode);inline;
  procedure Replace(victim, ANew: PQRBTreeNode); overload;
  function DoGetEnumerator: TEnumerator<TPair<TKey, TValue>>;override;
  function First: PQRBTreeNode;
  function Last: PQRBTreeNode;
  function InternalAdd(const AKey: TKey; const AValue: TValue;
    var AExists: Boolean): PQRBTreeNode;
  function InternalFind(const AKey: TKey): PQRBTreeNode;
  procedure InternalDelete(AChild: PQRBTreeNode);
  function GetValues(const AKey: TKey): TValue;
  procedure SetValues(const AKey: TKey; const Value: TValue); //
  function ValidItem(const AItem: PQRBTreeNode): Boolean;virtual;
  procedure AfterInsert(AItem:PQRBTreeNode);virtual;
public
  /// <summary>构造函数，传递一个大小比较函数进去，以便在插入和查找时能够正确的区分，如果不传，则使用默认比较函数比较</summary>
  constructor Create(AOnCompare: IComparer < TKey >= nil);overload;
  destructor Destroy;override;
  /// <summary>删除一个结点</summary>
  /// <param name="AKey">要删除的结点的键值</param>
  /// <remarks>如果值对应的结点存在，则删除对应的结点，否则，啥也不做，即删除一个不存在的键对应的结点是安全的</remarks>
  procedure Delete(AKey: TKey); // rb_erase
  /// <summary>插入一个数据，比较由构造时传入的事件回调函数处理</summary>
  /// <param name="AKey">键值</param>
  /// <param name="AValue">关联的值</param>
  /// <returns>成功，返回true，失败，返回false</returns>
  /// <remarks>如果指定的数据相同内容已经存在，就会返回false</remarks>
  function Add(const AKey: TKey; const AValue: TValue): Boolean;
  /// <summary>查找与指定键值相同的结点</summary>
  /// <param name="AKey">要用于搜索的键值</param>
  /// <param name="AValue">用于返回找到的结果</param>
  /// <returns>返回</returns>
  function Find(const AKey: TKey; var AValue: TValue): Boolean;
  function Exists(const AKey: TKey): Boolean;
  /// <summary>清除所有的结点</summary>
  procedure Clear;
  procedure ForEach(ACallback: TQMapEnumNotify);overload;
  procedure ForEach(ACallback: TQMapEnumCallback);overload;
  procedure ForRange(AMinValue, AMaxValue: TKey; ACallback: TQMapEnumNotify;
    AIncludeMinValue, AIncludeMaxValue: Boolean);overload;
  procedure ForRange(AMinValue, AMaxValue: TKey; ACallback: TQMapEnumCallback;
    AIncludeMinValue, AIncludeMaxValue: Boolean);overload;
  procedure SetOnDelete(ACallback: TQMapCallback);
  /// <summary>替换结点</summary>
  /// <param name="AKey">键值</param>
  /// <param name="AValue">新值</param>
  procedure Replace(const AKey: TKey; const AValue: TValue);overload;
  procedure AddOrReplace(const AKey: TKey; const AValue: TValue);
  /// 判断树是否为空树
  property IsEmpty: Boolean read GetIsEmpty;
  /// 删除事件响应函数
  property OnDelete: TQMapNotify read FOnDelete write FOnDelete;
  // 结点数量
  property Count: Integer read FCount;
  property Values[const AKey: TKey]: TValue read GetValues write SetValues;
  end;
  // 单键多值映射
  TQMultiMap < TKey, TValue >= class(TEnumerable < TPair < TKey, TValue >> )
    public //
  type //
  TValueArray = TArray<TValue>;
  TMapType = TQMap<TKey, TValueArray>;
  TKVPair = TPair<TKey, TValue>;
  TKVArrayPair = TPair<TKey, TValueArray>;
  TMapNode = TMapType.PQRBTreeNode;
  TQMapNotify = procedure(ASender: TObject; const AValue: TKVPair) of object;
  TQMapCallback =reference to procedure(ASender: TObject; const AValue: TKVPair);
  TQMapEnumNotify =procedure(ASender: TObject; const AValue: TKVPair; var AContinue: Boolean)
    of object;
  TQMapEnumCallback = reference to procedure(ASender: TObject; const AValue: TKVPair; var AContinue: Boolean);
private
var
  FOnDelete: TQMapNotify;
  FCount: Integer;
  function GetIsEmpty: Boolean;
  function GetValues(const AKey: TKey): TValueArray;
  procedure SetValues(const AKey: TKey; const Value: TValueArray);
protected
  FItems: TMapType;
  procedure DoDelete(const APair: TKVPair);
  procedure DoDeleteArray(Sender: TObject; const APair: TKVArrayPair);
public
  /// <summary>构造函数，传递一个大小比较函数进去，以便在插入和查找时能够正确的区分，如果不传，则使用默认比较函数比较</summary>
  constructor Create(AOnCompare: IComparer < TKey >= nil);overload;
  destructor Destroy;override;
  /// <summary>删除一个结点</summary>
  /// <param name="AKey">要删除的结点的键值</param>
  /// <param name="AIndex">要删除的结点的索引</param>
  /// <remarks>如果值对应的结点存在，则删除对应的结点，否则，啥也不做，即删除一个不存在的键对应的结点是安全的</remarks>
  procedure Delete(const AKey: TKey; const AIndex, ACount: Integer); // rb_erase
  /// <summary>插入一个数据，比较由构造时传入的事件回调函数处理</summary>
  /// <param name="AKey">键值</param>
  /// <param name="AValue">关联的值</param>
  /// <returns>成功，返回true，失败，返回false</returns>
  /// <remarks>如果指定的数据相同内容已经存在，就会返回false</remarks>
  function Add(const AKey: TKey; const AValue: TValue): Boolean;
  /// <summary>查找与指定键值相同的结点</summary>
  /// <param name="AKey">要用于搜索的键值</param>
  /// <param name="AValue">用于返回找到的结果</param>
  /// <returns>返回</returns>
  function Find(const AKey: TKey; var AValues: TValueArray): Boolean;
  function Exists(const AKey: TKey): Boolean;
  /// <summary>清除所有的结点</summary>
  procedure Clear;
  procedure ForEach(ACallback: TQMapEnumNotify);overload;
  procedure ForEach(ACallback: TQMapEnumCallback);overload;
  procedure SetOnDelete(ACallback: TQMapCallback);
  /// 判断树是否为空树
  property IsEmpty: Boolean read GetIsEmpty;
  /// 删除事件响应函数
  property OnDelete: TQMapNotify read FOnDelete write FOnDelete;
  // 结点数量
  property Count: Integer read FCount;
  property Values[const AKey: TKey]: TValueArray read GetValues write SetValues;
  end;

  TQTimeoutValue < TValue >= record Timeout: Cardinal;
  Value: TValue;
  end;

  TQTimeoutMap < TKey, TValue >= class(TQMap < TKey,
    TQTimeoutValue < TValue >> ) //
    protected //
var
  FTimeout: Cardinal;
  FAutoCleanup: Boolean;

  function ValidItem(const AItem: TQMap < TKey, TQTimeoutValue < TValue >>
    .PQRBTreeNode): Boolean; override;
  procedure AfterInsert(AItem:TQMap < TKey, TQTimeoutValue < TValue >>
    .PQRBTreeNode);override;
  public
    property Timeout: Cardinal read FTimeout write FTimeout;
    property AutoCleanup: Boolean read FAutoCleanup write FAutoCleanup;
    end;

implementation

const
  RB_RED = 0;
  RB_BLACK = 1;
  { TQMap<TKey, TValue>.TPairEnumerator }

constructor TQMap<TKey, TValue>.TPairEnumerator.Create
  (const AMap: TQMap<TKey, TValue>);
begin
  inherited Create;
  FMap := AMap;
  FCurrent := AMap.First;
end;

function TQMap<TKey, TValue>.TPairEnumerator.DoGetCurrent: TPair<TKey, TValue>;
begin
  Result := GetCurrent;
end;

function TQMap<TKey, TValue>.TPairEnumerator.DoMoveNext: Boolean;
begin
  Result := MoveNext;
end;

function TQMap<TKey, TValue>.TPairEnumerator.GetCurrent: TPair<TKey, TValue>;
begin
  Result := FCurrent.Pair;
end;

function TQMap<TKey, TValue>.TPairEnumerator.MoveNext: Boolean;
begin
  if Assigned(FCurrent) then
    FCurrent := FCurrent.Next;
  Result := Assigned(FCurrent);
end;

function TQMap<TKey, TValue>.Add(const AKey: TKey;
  const AValue: TValue): Boolean;
begin
  InternalAdd(AKey, AValue, Result);
end;

procedure TQMap<TKey, TValue>.AddOrReplace(const AKey: TKey;
  const AValue: TValue);
var
  ANode: PQRBTreeNode;
begin
  ANode := InternalFind(AKey);
  if Assigned(ANode) then
    ANode.Pair.Value := AValue
  else
    Add(AKey, AValue);
end;

procedure TQMap<TKey, TValue>.AfterInsert(AItem: PQRBTreeNode);
begin

end;

procedure TQMap<TKey, TValue>.ChangeChild(AOld, ANew, Parent: PQRBTreeNode);
begin
  if Parent <> nil then
  begin
    if Parent.Left = AOld then
      Parent.Left := ANew
    else
      Parent.Right := ANew;
  end
  else
    FRoot := ANew;
end;

procedure TQMap<TKey, TValue>.Clear;
var
  ANode: PQRBTreeNode;
begin
  if Assigned(FRoot) then
  begin
    if Assigned(OnDelete) then
    begin
      ANode := First;
      while ANode <> nil do
      begin
        // 触发 OnDelete 事件并且清除子结点
        DoDelete(ANode);
        ANode := ANode.Next;
      end;
    end;
    FRoot.Clear;
    Dispose(FRoot);
    FRoot := nil;
    FCount := 0;
  end;
end;

constructor TQMap<TKey, TValue>.Create(AOnCompare: IComparer<TKey>);
begin
  if Assigned(AOnCompare) then
    FOnCompare := AOnCompare
  else
    FOnCompare := TComparer<TKey>.Default;
end;

procedure TQMap<TKey, TValue>.Delete(AKey: TKey);
var
  rebalance, AChild: PQRBTreeNode;
begin
  AChild := InternalFind(AKey);
  if Assigned(AChild) then
    InternalDelete(AChild);
end;

destructor TQMap<TKey, TValue>.Destroy;
begin
  Clear;
  SetOnDelete(nil);
  inherited;
end;

procedure TQMap<TKey, TValue>.DoDelete(node: PQRBTreeNode);
begin
  if Assigned(FOnDelete) then
  begin
    if TMethod(FOnDelete).Data = Pointer(-1) then
      TQMapCallback(TMethod(FOnDelete).Code)(Self, node.Pair)
    else
      FOnDelete(Self, node.Pair);
  end;
  node.Clear;
end;

function TQMap<TKey, TValue>.DoGetEnumerator: TEnumerator<TPair<TKey, TValue>>;
begin
  Result := TPairEnumerator.Create(Self);
end;

function TQMap<TKey, TValue>.EraseAugmented(node: PQRBTreeNode): PQRBTreeNode;
var
  child, tmp, AParent, rebalance: PQRBTreeNode;
  pc, pc2: IntPtr;
  successor, child2: PQRBTreeNode;
begin
  child := node.Right;
  tmp := node.Left;
  if tmp = nil then
  begin
    pc := node.Parent_Color;
    AParent := node.Parent;
    ChangeChild(node, child, AParent);
    if Assigned(child) then
    begin
      child.Parent_Color := pc;
      rebalance := nil;
    end
    else if (pc and RB_BLACK) <> 0 then
      rebalance := AParent
    else
      rebalance := nil;
    tmp := AParent;
  end
  else if not Assigned(child) then
  begin
    tmp.Parent_Color := node.Parent_Color;
    AParent := node.Parent;
    ChangeChild(node, tmp, AParent);
    rebalance := nil;
    tmp := AParent;
  end
  else
  begin
    successor := child;
    tmp := child.Left;
    if not Assigned(tmp) then
    begin
      AParent := successor;
      child2 := successor.Right;
    end
    else
    begin
      repeat
        AParent := successor;
        successor := tmp;
        tmp := tmp.Left;
      until tmp = nil;
      AParent.Left := successor.Right;
      child2 := successor.Right;
      successor.Right := child;
      child.Parent := successor;
    end;
    successor.Left := node.Left;
    tmp := node.Left;
    tmp.Parent := successor;
    pc := node.Parent_Color;
    tmp := node.Parent;
    ChangeChild(node, successor, tmp);
    if Assigned(child2) then
    begin
      successor.Parent_Color := pc;
      child2.SetParentColor(AParent, RB_BLACK);
      rebalance := nil;
    end
    else
    begin
      pc2 := successor.Parent_Color;
      successor.Parent_Color := pc;
      if (pc2 and RB_BLACK) <> 0 then
        rebalance := AParent
      else
        rebalance := nil;
    end;
    tmp := successor;
  end;
  Result := rebalance;
end;

procedure TQMap<TKey, TValue>.EraseColor(AParent: PQRBTreeNode);
var
  node, sibling, tmp1, tmp2: PQRBTreeNode;
begin
  node := nil;
  while (true) do
  begin
    sibling := AParent.Right;
    if node <> sibling then
    begin
{$REGION 'node<>sibling'}
      if sibling.IsRed then
{$REGION 'slbling.IsRed'}
      begin
        AParent.Right := sibling.Left;
        tmp1 := sibling.Left;
        sibling.Left := AParent;
        tmp1.SetParentColor(AParent, RB_BLACK);
        RotateSetParents(AParent, sibling, RB_RED);
        sibling := tmp1;
      end;
{$ENDREGION 'slbling.IsRed'}
      tmp1 := sibling.Right;
      if (not Assigned(tmp1)) or tmp1.IsBlack then
      begin
{$REGION 'tmp1.IsBlack'}
        tmp2 := sibling.Left;
        if (not Assigned(tmp2)) or tmp2.IsBlack then
        begin
{$REGION 'tmp2.IsBlack'}
          sibling.SetParentColor(AParent, RB_RED);
          if AParent.IsRed then
            AParent.SetBlack
          else
          begin
            node := AParent;
            AParent := node.Parent;
            if Assigned(AParent) then
              Continue;
          end;
          Break;
{$ENDREGION 'tmp2.IsBlack'}
        end;
        sibling.Left := tmp2.Right;
        tmp1 := tmp2.Right;
        tmp2.Right := sibling;
        AParent.Right := tmp2;
        if Assigned(tmp1) then
          tmp1.SetParentColor(sibling, RB_BLACK);
        tmp1 := sibling;
        sibling := tmp2;
{$ENDREGION 'tmp1.IsBlack'}
      end;
      AParent.Right := sibling.Left;
      tmp2 := sibling.Left;
      sibling.Left := AParent;
      tmp1.SetParentColor(sibling, RB_BLACK);
      if Assigned(tmp2) then
        tmp2.Parent := AParent;
      RotateSetParents(AParent, sibling, RB_BLACK);
      Break;
{$ENDREGION 'node<>sibling'}
    end
    else
    begin
{$REGION 'RootElse'}
      sibling := AParent.Left;
      if (sibling.IsRed) then
      begin
{$REGION 'Case 1 - right rotate at AParent'}
        AParent.Left := sibling.Right;
        tmp1 := sibling.Right;
        sibling.Right := AParent;
        tmp1.SetParentColor(AParent, RB_BLACK);
        RotateSetParents(AParent, sibling, RB_RED);
        sibling := tmp1;
{$ENDREGION 'Case 1 - right rotate at AParent'}
      end;
      tmp1 := sibling.Left;
      if (tmp1 = nil) or tmp1.IsBlack then
      begin
{$REGION 'tmp1.IsBlack'}
        tmp2 := sibling.Right;
        if (tmp2 = nil) or tmp2.IsBlack then
        begin
{$REGION 'tmp2.IsBlack'}
          sibling.SetParentColor(AParent, RB_RED);
          if AParent.IsRed then
            AParent.SetBlack
          else
          begin
            node := AParent;
            AParent := node.Parent;
            if Assigned(AParent) then
              Continue;
          end;
          Break;
{$ENDREGION 'tmp2.IsBlack'}
        end;
        sibling.Right := tmp2.Left;
        tmp1 := tmp2.Left;
        tmp2.Left := sibling;
        AParent.Left := tmp2;
        if Assigned(tmp1) then
          tmp1.SetParentColor(sibling, RB_BLACK);
        tmp1 := sibling;
        sibling := tmp2;
{$ENDREGION ''tmp1.IsBlack'}
      end;
      AParent.Left := sibling.Right;
      tmp2 := sibling.Right;
      sibling.Right := AParent;
      tmp1.SetParentColor(sibling, RB_BLACK);
      if Assigned(tmp2) then
        tmp2.Parent := AParent;
      RotateSetParents(AParent, sibling, RB_BLACK);
      Break;
{$ENDREGION 'RootElse'}
    end;
  end;
end;

function TQMap<TKey, TValue>.Exists(const AKey: TKey): Boolean;
begin
  Result := InternalFind(AKey) <> nil;
end;

function TQMap<TKey, TValue>.Find(const AKey: TKey; var AValue: TValue)
  : Boolean;
var
  ANode: PQRBTreeNode;
begin
  ANode := InternalFind(AKey);
  Result := Assigned(ANode);
  if Result then
    AValue := ANode.Pair.Value
  else
  begin
    AValue := Default (TValue);
  end;
end;

function TQMap<TKey, TValue>.First: PQRBTreeNode;
begin
  Result := FRoot;
  if Result <> nil then
  begin
    while Assigned(Result.Left) do
      Result := Result.Left;
  end;
end;

procedure TQMap<TKey, TValue>.ForEach(ACallback: TQMapEnumCallback);
var
  AFirst, ANext: PQRBTreeNode;
  AContinue: Boolean;
begin
  if Assigned(ACallback) then
  begin
    AContinue := true;
    AFirst := First;
    while Assigned(AFirst) and AContinue do
    begin
      ANext := AFirst.Next;
      if ValidItem(AFirst) then
        ACallback(Self, AFirst.Pair, AContinue);
      AFirst := ANext;
    end;
  end;
end;

procedure TQMap<TKey, TValue>.ForRange(AMinValue, AMaxValue: TKey;
  ACallback: TQMapEnumCallback; AIncludeMinValue, AIncludeMaxValue: Boolean);
var
  AMethod: TMethod;
  ANotify: TQMapEnumNotify absolute AMethod;
begin
  AMethod.Code := nil;
  TQMapEnumCallback(AMethod.Code) := ACallback;
  AMethod.Data := Pointer(-1);
  ForRange(AMinValue, AMaxValue, ANotify, AIncludeMinValue, AIncludeMaxValue);
  TQMapEnumCallback(AMethod.Code) := nil;
end;

procedure TQMap<TKey, TValue>.ForRange(AMinValue, AMaxValue: TKey;
  ACallback: TQMapEnumNotify; AIncludeMinValue, AIncludeMaxValue: Boolean);
var
  rc: Integer;
  AItem, ANext: PQRBTreeNode;
  AContinue: Boolean;
begin
  AItem := FRoot;
  while Assigned(AItem) do
  begin
    rc := FOnCompare.Compare(AMinValue, AItem.Pair.Key);
    if rc < 0 then
    begin
      if Assigned(AItem.Left) then
        AItem := AItem.Left
      else
        Break;
    end
    else if rc > 0 then
    begin
      if Assigned(AItem.Right) then
        AItem := AItem.Right
      else
        Exit;
    end
    else
    begin
      if not AIncludeMinValue then
        AItem := AItem.Next;
      Break;
    end;
  end;
  AContinue := true;
  ANext := AItem.Next;
  while Assigned(AItem) and AContinue do
  begin
    rc := FOnCompare.Compare(AMaxValue, AItem.Pair.Key);
    if rc < 0 then
      Break;
    if (rc > 0) or AIncludeMaxValue then
    begin
      if ValidItem(AItem) then
      begin
        if TMethod(ACallback).Data = Pointer(-1) then
          TQMapEnumCallback(TMethod(ACallback).Code)
            (Self, AItem.Pair, AContinue)
        else
          ACallback(Self, AItem.Pair, AContinue);
      end;
    end;
    AItem := ANext;
  end;
end;

procedure TQMap<TKey, TValue>.ForEach(ACallback: TQMapEnumNotify);
var
  AFirst, ANext: PQRBTreeNode;
  AContinue: Boolean;
begin
  if Assigned(ACallback) then
  begin
    AFirst := First;
    while Assigned(AFirst) and AContinue do
    begin
      ANext := AFirst.Next;
      if ValidItem(AFirst) then
        ACallback(Self, AFirst.Pair, AContinue);
      AFirst := ANext;
    end;
  end;
end;

function TQMap<TKey, TValue>.GetIsEmpty: Boolean;
begin
  Result := (FRoot = nil);
end;

function TQMap<TKey, TValue>.GetValues(const AKey: TKey): TValue;
begin
  if not Find(AKey, Result) then
    Result := Default (TValue);
end;

procedure TQMap<TKey, TValue>.InsertColor(AChild: PQRBTreeNode);
begin
  InsertNode(AChild);
end;

procedure TQMap<TKey, TValue>.InsertNode(node: PQRBTreeNode);
var
  AParent, GParent, tmp: PQRBTreeNode;
begin
  AParent := node.RedParent;
  while true do
  begin
    if AParent = nil then
    begin
      node.SetParentColor(nil, RB_BLACK);
      Break;
    end
    else if AParent.IsBlack then
      Break;
    GParent := AParent.RedParent;
    tmp := GParent.Right;
    if AParent <> tmp then
    begin
      if Assigned(tmp) and tmp.IsRed then
      begin
        tmp.SetParentColor(GParent, RB_BLACK);
        AParent.SetParentColor(GParent, RB_BLACK);
        node := GParent;
        AParent := node.Parent;
        node.SetParentColor(AParent, RB_RED);
        Continue;
      end;
      tmp := AParent.Right;
      if node = tmp then
      begin
        AParent.Right := node.Left;
        tmp := node.Left;
        node.Left := AParent;
        if Assigned(tmp) then
          tmp.SetParentColor(AParent, RB_BLACK);
        AParent.SetParentColor(node, RB_RED);
        AParent := node;
        tmp := node.Right;
      end;
      GParent.Left := tmp;
      AParent.Right := GParent;
      if tmp <> nil then
        tmp.SetParentColor(GParent, RB_BLACK);
      RotateSetParents(GParent, AParent, RB_RED);
      Break;
    end
    else
    begin
      tmp := GParent.Left;
      if Assigned(tmp) and tmp.IsRed then
      begin
        tmp.SetParentColor(GParent, RB_BLACK);
        AParent.SetParentColor(GParent, RB_BLACK);
        node := GParent;
        AParent := node.Parent;
        node.SetParentColor(AParent, RB_RED);
        Continue;
      end;
      tmp := AParent.Left;
      if node = tmp then
      begin
        AParent.Left := node.Right;
        tmp := node.Right;
        node.Right := AParent;
        if tmp <> nil then
          tmp.SetParentColor(AParent, RB_BLACK);
        AParent.SetParentColor(node, RB_RED);
        AParent := node;
        tmp := node.Left;
      end;
      GParent.Right := tmp;
      AParent.Left := GParent;
      if tmp <> nil then
        tmp.SetParentColor(GParent, RB_BLACK);
      RotateSetParents(GParent, AParent, RB_RED);
      Break;
    end;
  end;
{$IFDEF PRINT_TREE}
  PrintTree('After insert ' + IntToHex(IntPtr(node), 8));
{$ENDIF}
end;

function TQMap<TKey, TValue>.InternalAdd(const AKey: TKey; const AValue: TValue;
  var AExists: Boolean): PQRBTreeNode;
var
  ANew: ^PQRBTreeNode;
  Parent, AChild: PQRBTreeNode;
  rc: Integer;
begin
  ANew := @FRoot;
  Parent := nil;
  AExists := false;
  while ANew^ <> nil do
  begin
    rc := FOnCompare.Compare(AKey, ANew^.Pair.Key);
    Parent := ANew^;
    if rc < 0 then
      ANew := @ANew^.Left
    else if rc > 0 then
      ANew := @ANew^.Right
    else // 已存在
    begin
      Result := ANew^;
      AExists := true;
      Exit;
    end;
  end;
  new(AChild);
  AChild.Pair.Key := AKey;
  AChild.Pair.Value := AValue;
  LinkNode(AChild, Parent, ANew^);
  InsertColor(AChild);
  Inc(FCount);
  Result := AChild;

end;

procedure TQMap<TKey, TValue>.InternalDelete(AChild: PQRBTreeNode);
var
  rebalance: PQRBTreeNode;
begin
  rebalance := EraseAugmented(AChild);
  if rebalance <> nil then
    EraseColor(rebalance);
  AChild.Left := nil;
  AChild.Right := nil;
  Dec(FCount);
  DoDelete(AChild);
  Dispose(AChild);
end;

function TQMap<TKey, TValue>.InternalFind(const AKey: TKey): PQRBTreeNode;
var
  rc: Integer;
begin
  Result := FRoot;
  while Assigned(Result) do
  begin
    rc := FOnCompare.Compare(AKey, Result.Pair.Key);
    if rc < 0 then
      Result := Result.Left
    else if rc > 0 then
      Result := Result.Right
    else
    begin
      if not ValidItem(Result) then
        Result := nil;
      Break;
    end;
  end
end;

function TQMap<TKey, TValue>.Last: PQRBTreeNode;
begin
  Result := FRoot;
  if Result <> nil then
  begin
    while Assigned(Result.Right) do
      Result := Result.Right;
  end;
end;

procedure TQMap<TKey, TValue>.LinkNode(node, Parent: PQRBTreeNode;
  var rb_link: PQRBTreeNode);
begin
  node.Parent_Color := IntPtr(Parent);
  node.Left := nil;
  node.Right := nil;
  rb_link := node;
end;

procedure TQMap<TKey, TValue>.Replace(const AKey: TKey; const AValue: TValue);
var
  ANode: PQRBTreeNode;
begin
  ANode := InternalFind(AKey);
  if Assigned(ANode) then
    ANode.Pair.Value := AValue;
end;

procedure TQMap<TKey, TValue>.Replace(victim, ANew: PQRBTreeNode);
var
  Parent: PQRBTreeNode;
begin
  Parent := victim.Parent;
  ChangeChild(victim, ANew, Parent);
  if Assigned(victim.Left) then
    victim.Left.SetParent(ANew)
  else
    victim.Right.SetParent(ANew);
  ANew.Assign(victim);
end;

procedure TQMap<TKey, TValue>.RotateSetParents(AOld, ANew: PQRBTreeNode;
  color: Integer);
var
  AParent: PQRBTreeNode;
begin
  AParent := AOld.Parent;
  ANew.Parent_Color := AOld.Parent_Color;
  AOld.SetParentColor(ANew, color);
  ChangeChild(AOld, ANew, AParent);
end;

procedure TQMap<TKey, TValue>.SetOnDelete(ACallback: TQMapCallback);
begin
  with TMethod(FOnDelete) do
  begin
    if Data = Pointer(-1) then
      TQMapCallback(Code) := nil;
    if Assigned(ACallback) then
    begin
      Data := Pointer(-1);
      TQMapCallback(Code) := ACallback;
    end
    else
    begin
      Data := nil;
      Code := nil;
    end;
  end;
end;

procedure TQMap<TKey, TValue>.SetValues(const AKey: TKey; const Value: TValue);
begin
  AddOrReplace(AKey, Value);
end;

function TQMap<TKey, TValue>.ValidItem(const AItem: PQRBTreeNode): Boolean;
begin
  Result := true;
end;

{ TQMap<TKey, TValue>.PQRBTreeNode }

procedure TQMap<TKey, TValue>.TQRBTreeNode.Assign(const src: PQRBTreeNode);
begin
  Parent_Color := src.Parent_Color;
  Left := src.Left;
  Right := src.Right;
  Pair := src.Pair;
end;

procedure TQMap<TKey, TValue>.TQRBTreeNode.Clear;
begin
  Parent_Color := IntPtr(@Self);
  if Assigned(Left) then
  begin
    Left.Clear;
    Dispose(Left);
    Left := nil;
  end;
  if Assigned(Right) then
  begin
    Right.Clear;
    Dispose(Right);
    Right := nil;
  end;
end;

function TQMap<TKey, TValue>.TQRBTreeNode.GetIsBlack: Boolean;
begin
  Result := (IntPtr(Parent_Color) and $1) <> 0;
end;

function TQMap<TKey, TValue>.TQRBTreeNode.GetIsEmpty: Boolean;
begin
  Result := (Parent_Color = IntPtr(@Self));
end;

function TQMap<TKey, TValue>.TQRBTreeNode.GetIsRed: Boolean;
begin
  Result := ((IntPtr(Parent_Color) and $1) = 0);
end;

function TQMap<TKey, TValue>.TQRBTreeNode.GetLeftDeepest: PQRBTreeNode;
begin
  Result := @Self;
  while true do
  begin
    if Assigned(Result.Left) then
      Result := Result.Left
    else if Assigned(Result.Right) then
      Result := Result.Right
    else
      Break;
  end;
end;

function TQMap<TKey, TValue>.TQRBTreeNode.GetNext: PQRBTreeNode;
var
  node, AParent: PQRBTreeNode;
begin
  if IsEmpty then
    Result := nil
  else
  begin
    if Assigned(Right) then
    begin
      Result := Right;
      while Assigned(Result.Left) do
        Result := Result.Left;
      Exit;
    end;
    node := @Self;
    repeat
      AParent := node.Parent;
      if Assigned(AParent) and (node = AParent.Right) then
        node := AParent
      else
        Break;
    until AParent = nil;
    Result := AParent;
  end;
end;

function TQMap<TKey, TValue>.TQRBTreeNode.GetParent: PQRBTreeNode;
begin
  Result := PQRBTreeNode(IntPtr(Parent_Color) and (not $3));
end;

function TQMap<TKey, TValue>.TQRBTreeNode.GetPrior: PQRBTreeNode;
var
  node, AParent: PQRBTreeNode;
begin
  if IsEmpty then
    Result := nil
  else
  begin
    if Assigned(Left) then
    begin
      Result := Left;
      while Assigned(Result.Right) do
        Result := Result.Right;
      Exit;
    end;
    node := @Self;
    repeat
      AParent := node.Parent;
      if Assigned(Parent) and (node = AParent.Left) then
        node := AParent
      else
        Break;
    until AParent = nil;
    Result := AParent;
  end;
end;

function TQMap<TKey, TValue>.TQRBTreeNode.NextPostOrder: PQRBTreeNode;
begin
  Result := Parent;
  if Assigned(Result) and (@Self = Result.Left) and Assigned(Result.Right) then
    Result := Result.Right.LeftDeepest;
end;

function TQMap<TKey, TValue>.TQRBTreeNode.RedParent: PQRBTreeNode;
begin
  Result := PQRBTreeNode(Parent_Color);
end;

procedure TQMap<TKey, TValue>.TQRBTreeNode.SetBlack;
begin
  Parent_Color := Parent_Color or RB_BLACK;
end;

procedure TQMap<TKey, TValue>.TQRBTreeNode.SetParent(const Value: PQRBTreeNode);
begin
  Parent_Color := IntPtr(Value) or (IntPtr(Parent_Color) and $1);
end;

procedure TQMap<TKey, TValue>.TQRBTreeNode.SetParentColor(AParent: PQRBTreeNode;
  AColor: Integer);
begin
  Parent_Color := IntPtr(AParent) or AColor;
end;

{ TQMultiMap<TKey, TValue> }

function TQMultiMap<TKey, TValue>.Add(const AKey: TKey;
  const AValue: TValue): Boolean;
var
  ANode: TQMap<TKey, TValueArray>.PQRBTreeNode;
  AValues: TValueArray;
begin
  ANode := FItems.InternalFind(AKey);
  if Assigned(ANode) then
  begin
    SetLength(ANode.Pair.Value, Length(ANode.Pair.Value) + 1);
    ANode.Pair.Value[High(ANode.Pair.Value)] := AValue;
  end
  else
  begin
    SetLength(AValues, 1);
    AValues[0] := AValue;
    FItems.Add(AKey, AValues);
  end;
end;

procedure TQMultiMap<TKey, TValue>.Clear;
begin
  FItems.Clear;
end;

constructor TQMultiMap<TKey, TValue>.Create(AOnCompare: IComparer<TKey>);
begin
  inherited Create;
  FItems := TMapType.Create(AOnCompare);
  FItems.OnDelete := DoDeleteArray;
end;

procedure TQMultiMap<TKey, TValue>.Delete(const AKey: TKey;
  const AIndex, ACount: Integer);
var
  ANode: TMapNode;
  AValue: TKVPair;
  L, H, I: Integer;
begin
  ANode := FItems.InternalFind(AKey);
  if Assigned(ANode) then
  begin
    L := AIndex;
    H := AIndex + ACount;
    if H > High(ANode.Pair.Value) then
      H := High(ANode.Pair.Value);
    if Assigned(FOnDelete) then
    begin
      AValue.Key := ANode.Pair.Key;
      for I := L to H do
      begin
        AValue.Value := ANode.Pair.Value[I];
        DoDelete(AValue);
      end;
    end;
    system.Delete(ANode.Pair.Value, AIndex, ACount);
    if Length(ANode.Pair.Value) = 0 then
      FItems.InternalDelete(ANode);
  end;
end;

destructor TQMultiMap<TKey, TValue>.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

procedure TQMultiMap<TKey, TValue>.DoDelete(const APair: TKVPair);
begin
  if Assigned(FOnDelete) then
  begin
    if TMethod(FOnDelete).Data = Pointer(-1) then
      TQMapCallback(TMethod(FOnDelete).Code)(Self, APair)
    else
      FOnDelete(Self, APair);
  end;
end;

procedure TQMultiMap<TKey, TValue>.DoDeleteArray(Sender: TObject;
  const APair: TKVArrayPair);
var
  AValue: TKVPair;
  I: Integer;
begin
  if Assigned(FOnDelete) then
  begin
    AValue.Key := APair.Key;
    for I := 0 to High(APair.Value) do
    begin
      AValue.Value := APair.Value[I];
      DoDelete(AValue);
    end;
  end;
end;

function TQMultiMap<TKey, TValue>.Exists(const AKey: TKey): Boolean;
begin
  Result := FItems.InternalFind(AKey) <> nil;
end;

function TQMultiMap<TKey, TValue>.Find(const AKey: TKey;
  var AValues: TValueArray): Boolean;
var
  ANode: TMapNode;
  AValue: TKVPair;
  L, H, I: Integer;
begin
  ANode := FItems.InternalFind(AKey);
  if Assigned(ANode) then
    AValues := Copy(ANode.Pair.Value, Low(ANode.Pair.Value),
      Length(ANode.Pair.Value))
  else
    SetLength(AValues, 0);
  Result := Assigned(ANode);
end;

procedure TQMultiMap<TKey, TValue>.ForEach(ACallback: TQMapEnumNotify);
var
  APair: TKVArrayPair;
  AValue: TKVPair;
  I: Integer;
  AContinue: Boolean;
begin
  AContinue := true;
  for APair in FItems do
  begin
    AValue.Key := APair.Key;
    for I := 0 to High(APair.Value) do
    begin
      AValue.Value := APair.Value[I];
      ACallback(Self, AValue, AContinue);
      if not AContinue then
        Exit;
    end;
  end;
end;

procedure TQMultiMap<TKey, TValue>.ForEach(ACallback: TQMapEnumCallback);
var
  APair: TKVArrayPair;
  AValue: TKVPair;
  I: Integer;
  AContinue: Boolean;
begin
  AContinue := true;
  for APair in FItems do
  begin
    AValue.Key := APair.Key;
    for I := 0 to High(APair.Value) do
    begin
      AValue.Value := APair.Value[I];
      ACallback(Self, AValue, AContinue);
      if not AContinue then
        Exit;
    end;
  end;
end;

function TQMultiMap<TKey, TValue>.GetIsEmpty: Boolean;
begin
  Result := FItems.IsEmpty;
end;

function TQMultiMap<TKey, TValue>.GetValues(const AKey: TKey): TValueArray;
begin
  Result := FItems.GetValues(AKey);
end;

procedure TQMultiMap<TKey, TValue>.SetOnDelete(ACallback: TQMapCallback);
begin
  with TMethod(FOnDelete) do
  begin
    if Data = Pointer(-1) then
      TQMapCallback(Code) := nil;
    if Assigned(ACallback) then
    begin
      Data := Pointer(-1);
      TQMapCallback(Code) := ACallback;
    end
    else
    begin
      Data := nil;
      Code := nil;
    end;
  end;
end;

procedure TQMultiMap<TKey, TValue>.SetValues(const AKey: TKey;
  const Value: TValueArray);
begin
  FItems.SetValues(AKey, Value);
end;

{ TQTimeoutMap<TKey, TValue> }

procedure TQTimeoutMap<TKey, TValue>.AfterInsert(
  AItem: TQMap<TKey, TQTimeoutValue<TValue>>.PQRBTreeNode);
begin
  if Timeout>0 then
    AItem.Pair.Value.Timeout:=TThread.GetTickCount+Timeout;
end;

function TQTimeoutMap<TKey, TValue>.ValidItem(const AItem: TQMap < TKey,
  TQTimeoutValue < TValue >>.PQRBTreeNode): Boolean;
begin
  Result := AItem.Pair.Value.Timeout < TThread.GetTickCount;
  if (not Result) and AutoCleanup then
    InternalDelete(AItem);
end;

end.
