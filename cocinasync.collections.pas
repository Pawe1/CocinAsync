unit cocinasync.collections;

interface

uses System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Defaults,
  System.TypInfo;

type
  TInterlockedHelper = class helper for TInterlocked
  public
    class function CompareExchange(var Target: Pointer; Value: Pointer; Comparand: Pointer; out Succeeded: Boolean): Pointer;
  end;

  TStack<T> = class(TObject)
  strict private
    type
      PStackPointer = ^TStackPointer;
      TStackPointer = record
        FData : T;
        FPrior : Pointer;
      end;
  strict private
    FTop : Pointer;
    FFirst : Pointer;
    function Pop(Depth : integer) : T; overload; inline;
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;

    procedure Push(const Value: T); inline;
    function Pop: T; overload; inline;
    function Peek: T; inline;
    procedure Clear;
  end;

  THash<K,V> = class(TObject)
  strict private
    type
    PItem = ^TItem;
    TItem = record
      Key: K;
      Value: V;
      Next: Pointer;
    end;
    TItemArray = TArray<Pointer>;
  strict private
    FMemSize: Cardinal;
    FSizeMask : Cardinal;
    FItems: TItemArray;
    FComparer : IEqualityComparer<K>;
    FKeyType: PTypeInfo;
    function GetMapPointer(Key: K; HashIdx : integer; var Prior, Current : PItem): Boolean;
    function GetMap(Key: K): V;
    procedure SetMap(Key: K; const Value: V; NewItem : PItem; Depth : integer); overload; //inline;
    procedure SetMap(Key: K; const Value: V); overload;
    function GetHas(Key: K): boolean;
    function GetHashIndex(Key : K) : Integer; //inline;
    function CalcDepth(item: PItem): integer; //inline;
  public
    type
      TDepth = record
        EmptyCnt : Cardinal;
        MaxDepth : Cardinal;
        Average  : Cardinal;
        AvgFilled : Cardinal;
        Size : Cardinal;
      end;
  public
    constructor Create(EstimatedItemCount : Integer = 1024); reintroduce; virtual;
    destructor Destroy; override;

    function DebugDepth : TDepth;
    procedure Delete(const Key : K);
    procedure AddOrSetValue(const Key : K; const Value : V);
    property Has[Key : K] : boolean read GetHas;
    property Map[Key : K] : V read GetMap write SetMap; default;
  end;

implementation

uses Math;

class function TInterlockedHelper.CompareExchange(var Target: Pointer; Value: Pointer; Comparand: Pointer; out Succeeded: Boolean): Pointer;
begin
  Result := AtomicCmpExchange(Target, Value, Comparand, Succeeded);
end;


{ TStack<T> }

procedure TStack<T>.Clear;
var
  val : T;
  bAssigned : boolean;
begin
  while FTop <> FFirst do
    Pop;
end;

constructor TStack<T>.Create;
var
  p : PStackPointer;
begin
  inherited Create;
  New(p);
  p^.FData := T(nil);
  p^.FPrior := nil;
  FFirst := p;
  FTop := p;
end;

destructor TStack<T>.Destroy;
begin
  Clear;
  Dispose(FFirst);
  inherited;
end;

function TStack<T>.Peek: T;
begin
  if FTop <> nil then
  begin
    Result := PStackPointer(FTop)^.FData;
  end else
    Result := T(nil);
end;

function TStack<T>.Pop(Depth: integer): T;
var
  p, pTop : PStackPointer;
  iCnt : integer;
  bSucceeded : boolean;
begin
  pTop := FTop;
  if (pTop <> nil) and (pTop <> FFirst) then
  begin
    p := PStackPointer(TInterlocked.CompareExchange(FTop,PStackPointer(pTop)^.FPrior, pTop,bSucceeded));
    if bSucceeded then
    begin
      Result := p^.FData;
      Dispose(pTop);
    end else
    begin
      Sleep(Depth);
      if Depth < 5 then
        Result := Pop(Depth+1)
      else
        Result := Pop(Depth*2);
    end;
  end else
    Result := T(nil);
end;

function TStack<T>.Pop: T;
begin
  Result := Pop(0);
end;

procedure TStack<T>.Push(const Value: T);
var
  ptop, p : PStackPointer;
  bSuccess : boolean;
  iSleep : integer;
begin
  New(p);
  p^.FData := Value;
  bSuccess := False;
  iSleep := 0;
  repeat
    p.FPrior := FTop;
    TInterlocked.CompareExchange(FTop, p, p^.FPrior, bSuccess);
    if not bSuccess then
    begin
      sleep(iSleep);
      if iSleep < 5 then
        inc(iSleep)
      else
        inc(iSleep, iSleep*2);
    end;
  until bSuccess;
end;

{ THash<K, V> }

procedure THash<K, V>.AddOrSetValue(const Key: K; const Value: V);
begin
  SetMap(Key, Value);
end;

constructor THash<K, V>.Create(EstimatedItemCount : Integer = 1024);
var
  i: Integer;
begin
  inherited Create;
  FMemSize := $FFFFFF;
  while (EstimatedItemCount < FMemSize) and (FMemSize > $F) do
    FMemSize := FMemSize shr 4;
  SetLength(FItems,FMemSize+1);
  FKeyType := TypeInfo(K);
  FComparer := TEqualityComparer<K>.Default;
  for i := Low(FItems) to High(FItems) do
    FItems[i] := nil;
end;

function THash<K, V>.CalcDepth(item : PItem) : integer;
begin
  Result := 1;
  while (item <> nil) and (item.Next <> nil) do
  begin
    inc(Result);
    item := item.Next;
  end;
end;

function THash<K, V>.DebugDepth: TDepth;
var
  i, iDepth : integer;
begin
  Result.EmptyCnt := 0;
  Result.MaxDepth := 0;
  Result.Average := 0;
  Result.AvgFilled := 0;
  Result.Size := FMemSize+1;
  for i := 0 to FMemSize do
  begin
    if FItems[i] <> nil then
    begin
      iDepth := CalcDepth(FItems[I]);
      Result.MaxDepth := Max(Result.MaxDepth, iDepth);
      inc(Result.Average,iDepth);
      inc(Result.AvgFilled, iDepth);
    end else
      Inc(Result.EmptyCnt);
  end;
  Result.Average := Result.Average div (FMemSize+1);
  if FMemSize >= Result.EmptyCnt then
    Result.AvgFilled := Result.AvgFilled div ((FMemSize+1) - Result.EmptyCnt)
  else
    Result.AvgFilled := Result.Average;
end;

procedure THash<K, V>.Delete(const Key: K);
begin
  SetMap(Key, V(nil));
end;

destructor THash<K, V>.Destroy;
var
  i: Integer;
begin
  for i := Low(FItems) to High(FItems) do
    if FItems[i] <> nil then
      Dispose(FItems[i]);
  inherited;
end;

function THash<K, V>.GetHas(Key: K): boolean;
var
  val : V;
begin
  val := GetMap(Key);
  Result := @val <> nil;
end;

function THash<K, V>.GetHashIndex(Key: K): Integer;
const Mask = not Integer($80000000);
begin
  result := (Mask and ((Mask and FComparer.GetHashCode(Key)) + 1)) and (FMemSize);
end;

function THash<K, V>.GetMap(Key: K): V;
var
  p, pPrior : PItem;
begin
  GetMapPointer(Key, GetHashIndex(Key), pPrior, p);
  if p <> nil then
  begin
    Result := p.Value;
  end else
    Result := V(nil);
end;

function THash<K, V>.GetMapPointer(Key: K; HashIdx : integer; var Prior, Current : PItem): Boolean;
var
  p : PItem;
begin
  Result := False;
  Prior := nil;
  p := FItems[HashIdx];
  if p <> nil then
  begin
    if not FComparer.Equals(p.Key, Key) then
    begin
      repeat
        Prior := p;
        p := p.Next;
      until (p = nil) or FComparer.Equals(p.Key, Key);

      if p <> nil then
        Current := p
      else
        Current := nil;
    end else
      Current := p;
    Result := Prior <> nil;
  end else
    Current := nil;
end;

procedure THash<K, V>.SetMap(Key: K; const Value: V; NewItem: PItem; Depth : integer);
var
  p, pNew, pDisp, pPrior : PItem;
  idx : Integer;
  bSlotNotEmpty, bSuccess : boolean;
begin
  if NewItem = nil then
  begin
    New(pNew);
    pNew.Key := Key;
    pNew.Value := Value;
  end else
    pNew := NewItem;
  pNew.Next := nil;

  idx := GetHashIndex(Key);
  pPrior := nil;
  bSlotNotEmpty := GetMapPointer(Key, idx, pPrior, p);
  if bSlotNotEmpty then
  begin
    if p = nil then // New Key not found in list.
    begin
      pNew.Next := p;
      TInterlocked.CompareExchange(pPrior^.Next, pNew, p, bSuccess);
      if not bSuccess then
      begin
        sleep(Depth);
        SetMap(Key,Value, pNew, Depth+2);
      end;
    end else // Key Found, updating
    begin
      pDisp := p;
      pNew.Next := p^.Next;
      TInterlocked.CompareExchange(pPrior^.Next, pNew, p, bSuccess);
      if not bSuccess then
      begin
        sleep(Depth);
        SetMap(Key,Value, pNew, Depth+2);
      end else
      begin
        Dispose(pDisp);
      end;
    end;
  end else
  begin
    // New Key at position, add a new one.
    TInterlocked.CompareExchange(FItems[idx],pNew,p,bSuccess);
    if not bSuccess then
    begin
      sleep(Depth);
      SetMap(Key,Value, pNew, Depth+2);
    end else
      if p <> nil then
        Dispose(p);
  end;
end;

procedure THash<K, V>.SetMap(Key: K; const Value: V);
begin
  SetMap(Key, Value, nil, 0);
end;

end.
