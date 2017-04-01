unit cocinasync.collections;

interface

uses System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Defaults,
  System.TypInfo;

resourcestring
  S_ARRAYISFULL = 'The queue is full';
  S_ARRAYISEMPTY = 'The queue is empty';

type
  TInterlockedHelper = class helper for TInterlocked
  public
    class function CompareExchange(var Target: Pointer; Value: Pointer; Comparand: Pointer; out Succeeded: Boolean): Pointer; overload;
    class function CompareExchange(var Target: UInt64; Value: UInt64; Comparand: UInt64; out Succeeded: Boolean): UInt64; overload;
    class function Exchange<T>(var Target: T; Value: T): T; overload;
  end;

  EQueueSizeException = class(Exception)
  end;

  TQueue<T> = class(TObject)
  strict private
    FData : System.TArray<T>;
    FSize : integer;
    FWriteIndex : integer;
    FReadIndex : integer;
    FWriteIndexMax : integer;
    FReadIndexMax : integer;
    function IndexOf(idx : integer) : integer; inline;
    function GetItems(idx: integer): T;  inline;
    function GetCount: integer;  inline;
  public
    constructor Create(Size : Integer); reintroduce; virtual;
    destructor Destroy; override;

    procedure Enqueue(Value : T); inline;
    function Dequeue : T; inline;
    procedure Clear; inline;

    property Items[idx : integer] : T read GetItems; default;
    property Count : integer read GetCount;
  end;

  TStack<T> = class(TObject)
  strict private type
    PStackPointer = ^TStackPointer;
    TStackPointer = record
      FData : T;
      FPrior : Pointer;
    end;
  strict private
    FTop : Pointer;
    FDisposeQueue : TQueue<PStackPointer>;
    FPushMisses: Int64;
    FPopMisses: Int64;
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;

    procedure Push(const Value: T); inline;
    function Pop: T; overload; inline;
    procedure Clear; inline;
    property PushMisses : Int64 read FPushMisses;
    property PopMisses : Int64 read FPopMisses;
  end;

  TVisitorProc<K,V> = reference to procedure(const Key : K; var Value : V; var Delete : Boolean);

  THash<K,V> = class(TObject)
  strict private
    type
    PValue = ^V;
    PItem = ^TItem;
    TItem = record
      Key: K;
      Value: V;
      Next: Pointer;
    end;
    TItemArray = system.TArray<Pointer>;
  strict private
    FMemSize: Cardinal;
    FSizeMask : Cardinal;
    FItems: TItemArray;
    FComparer : IEqualityComparer<K>;
    FKeyType: PTypeInfo;
    procedure GetMapPointer(Key: K; HashIdx : integer; var Prior, Current : PItem; var Depth : Integer); inline;
    function GetMap(Key: K): V;  inline;
    procedure SetMap(Key: K; const Value: V; NewItem : PItem; const wait : TSpinWait); overload; inline;
    procedure SetMap(Key: K; const Value: V); overload;  inline;
    function GetHas(Key: K): boolean; inline;
    function GetHashIndex(Key : K) : Integer; inline;
    function CalcDepth(item: PItem): integer; inline;
    procedure Remove(const Key : K; const wait : TSpinWait); overload; inline;
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
    procedure Remove(const Key : K); overload;  inline;
    procedure AddOrSetValue(const Key : K; const Value : V);  inline;
    property Has[Key : K] : boolean read GetHas;
    property Map[Key : K] : V read GetMap write SetMap; default;
    procedure Visit(const visitor : TVisitorProc<K,V>);
  end;

implementation

uses Math;

{ TInterlockedHelper }

class function TInterlockedHelper.CompareExchange(var Target: Pointer; Value: Pointer; Comparand: Pointer; out Succeeded: Boolean): Pointer;
begin
  Result := AtomicCmpExchange(Target, Value, Comparand, Succeeded);
end;

class function TInterlockedHelper.CompareExchange(var Target: UInt64; Value,
  Comparand: UInt64; out Succeeded: Boolean): UInt64;
begin
  Result := AtomicCmpExchange(Target, Value, Comparand, Succeeded);
end;


class function TInterlockedHelper.Exchange<T>(var Target: T; Value : T): T;
begin
  TObject((@Result)^) := Exchange(TObject((@Target)^), TObject((@Value)^));
end;

{ TQueue<T> }

procedure TQueue<T>.Clear;
begin
  repeat
    Dequeue;
  until IndexOf(FReadIndex) = IndexOf(FReadIndexMax);
end;

constructor TQueue<T>.Create(Size: Integer);
begin
  inherited Create;
  FSize := Size;
  SetLength(FData, Size);
end;

function TQueue<T>.Dequeue: T;
var
  iMaxRead, iRead : integer;
  bSuccess : boolean;
  sw : TSpinWait;
  p : pointer;
begin
  sw.Reset;
  repeat
    iRead := FReadIndex;
    iMaxRead := FReadIndexMax;

    if IndexOf(iRead) = IndexOf(iMaxRead) then
      exit(T(nil));

    Result := FData[IndexOf(iRead)];

    TInterlocked.CompareExchange(FReadIndex, iRead+1, iRead, bSuccess);
    if not bSuccess then
      sw.SpinCycle;
  until bSuccess;

  if IsManagedType(T) then
  begin
    p := @FData[IndexOf(iRead)];
    TInterlocked.CompareExchange(p,nil,@Result);
  end;
end;

destructor TQueue<T>.Destroy;
begin
  Clear;
  inherited;
end;

procedure TQueue<T>.Enqueue(Value: T);
var
  bSuccess : boolean;
  iRead, iWrite : integer;
  sw : TSpinWait;
begin
  sw.Reset;
  repeat
    iWrite := FWriteIndex;
    iRead := FReadIndex;
    if IndexOf(iWrite + 1) = IndexOf(iRead) then
      raise EQueueSizeException.Create(S_ARRAYISFULL);
    TInterlocked.CompareExchange(FWriteIndex, iWrite+1, iWrite, bSuccess);
    if not bSuccess then
      sw.SpinCycle;
  until bSuccess;

  FData[IndexOf(iWrite)] := Value;

  sw.Reset;
  repeat
    TInterlocked.CompareExchange(FReadIndexMax, iWrite+1, iWrite, bSuccess);
    if not bSuccess then
      sw.SpinCycle;
  until (bSuccess);
end;

function TQueue<T>.GetItems(idx: integer): T;
begin
  Result := FData[IndexOf(idx)];
end;

function TQueue<T>.GetCount : integer;
begin
  Result := FReadIndexMax - FReadIndex;
end;

function TQueue<T>.IndexOf(idx: integer): integer;
begin
  result := idx mod FSize;
end;

{ TStack<T> }

procedure TStack<T>.Clear;
begin
  while FTop <> nil do
    Pop;
end;

constructor TStack<T>.Create;
begin
  inherited Create;
  FTop := nil;
  FDisposeQueue := TQueue<PStackPointer>.Create(256);
  FPushMisses := 0;
  FPopMisses := 0;
end;

destructor TStack<T>.Destroy;
var
  p : PStackPointer;
begin
  Clear;
  repeat
    p := FDisposeQueue.Dequeue;
    if p <> nil then
      Dispose(p);
  until p = nil;
  FDisposeQueue.Free;
  inherited;
end;

function TStack<T>.Pop: T;
var
  p : PStackPointer;
  bSuccess : boolean;
  wait : TSpinWait;
begin
  wait.Reset;

  if FTop = nil then
    exit(T(nil));

  repeat
    p := FTop;
    if p <> nil then
      TInterlocked.CompareExchange(FTop,p^.FPrior, p, bSuccess)
    else
      exit(T(nil));
    if not bSuccess then
    begin
      wait.SpinCycle;
      TInterlocked.Increment(FPopMisses);
    end;
  until bSuccess;

  Result := p^.FData;

  FDisposeQueue.Enqueue(p);
  if FDisposeQueue.Count > 192 then
  begin
    while FDisposeQueue.Count > 128 do
    begin
      p := FDisposeQueue.Dequeue;
      if p <> nil then
        Dispose(p);
    end;
  end;
end;

procedure TStack<T>.Push(const Value: T);
var
  pNew : PStackPointer;
  wait : TSpinWait;
  bSuccess : boolean;
begin
  wait.Reset;
  if FDisposeQueue.Count > 64 then
    pNew := FDisposeQueue.Dequeue
  else
    New(pNew);
  pNew^.FData := Value;
  repeat
    pNew^.FPrior := FTop;
    TInterlocked.CompareExchange(FTop,pNew, pNew^.FPrior,bSuccess);
    if not bSuccess then
    begin
      wait.SpinCycle;
      TInterlocked.Increment(FPushMisses);
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

procedure THash<K, V>.Remove(const Key: K; const wait: TSpinWait);
var
  p, pPrior : PItem;
  iDepth : integer;
  bSuccess : boolean;
begin
  GetMapPointer(Key, GetHashIndex(Key), pPrior, p, iDepth);
  if p <> nil then
  begin
    if pPrior = nil then
      TInterlocked.CompareExchange(FItems[GetHashIndex(Key)],p^.Next, p, bSuccess)
    else
      TInterlocked.CompareExchange(pPrior^.Next, p^.Next, p, bSuccess);

    if not bSuccess then
    begin
      wait.SpinCycle;
      Remove(Key, wait);
    end else
      Dispose(p);
  end;
end;

procedure THash<K, V>.Remove(const Key: K);
var
  sw : TSpinWait;
begin
  sw.Reset;
  Remove(Key, sw);
end;

destructor THash<K, V>.Destroy;
var
  p, pNext : PItem;
  i: Integer;
begin
  for i := Low(FItems) to High(FItems) do
    if FItems[i] <> nil then
    begin
      p := PItem(PItem(FItems[i])^.Next);
      while p <> nil do
      begin
        pNext := p^.Next;
        p^.Value := V(nil);
        Dispose(PItem(p));
        p := pNext;
      end;
      Dispose(PItem(FItems[i]));
    end;
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
  iDepth : integer;
begin
  GetMapPointer(Key, GetHashIndex(Key), pPrior, p, iDepth);
  if p <> nil then
  begin
    Result := p.Value;
  end else
    Result := V(nil);
end;

procedure THash<K, V>.GetMapPointer(Key: K; HashIdx : integer; var Prior, Current : PItem; var Depth : Integer);
var
  p : PItem;
begin
  Depth := 0;
  Prior := nil;
  p := FItems[HashIdx];
  if p <> nil then
  begin
    if not FComparer.Equals(p.Key, Key) then
    begin
      repeat
        Prior := p;
        p := p.Next;
        inc(Depth);
      until (p = nil) or FComparer.Equals(p.Key, Key);

      if p <> nil then
        Current := p
      else
        Current := nil;
    end else
      Current := p;
  end else
    Current := nil;
end;

procedure THash<K, V>.SetMap(Key: K; const Value: V; NewItem: PItem; const wait : TSpinWait);
var
  p, pNew, pDisp, pPrior : PItem;
  iDepth, idx : Integer;
  bSuccess : boolean;
  vValue : V;
begin
  idx := GetHashIndex(Key);
  pPrior := nil;
  GetMapPointer(Key, idx, pPrior, p, iDepth);

  if p = nil then
  begin
    if NewItem = nil then
    begin
      New(pNew);
      pNew.Key := Key;
      pNew.Value := Value;
    end else
      pNew := NewItem;
    pNew.Next := nil;

    if iDepth > 0 then
    begin
      // Slot occupied but key not found
      pNew.Next := p;
      TInterlocked.CompareExchange(pPrior^.Next, pNew, p, bSuccess);
      if not bSuccess then
      begin
        wait.SpinCycle;
        SetMap(Key,Value, pNew, wait);
      end;
    end else
    begin
      // Slot open, start linked list with key
      TInterlocked.CompareExchange(FItems[idx],pNew,p,bSuccess);
      if not bSuccess then
      begin
        wait.SpinCycle;
        SetMap(Key,Value, pNew, wait);
      end else
        if p <> nil then
          Dispose(p);
    end;
  end else
  begin
    TInterlocked.Exchange<V>(p^.Value,Value);
  end;
end;

procedure THash<K, V>.SetMap(Key: K; const Value: V);
var
  sw : TSpinWait;
begin
  sw.Reset;
  SetMap(Key, Value, nil, sw);
end;

procedure THash<K, V>.Visit(const visitor: TVisitorProc<K,V>);
var
  p : PItem;
  del : boolean;
  i : integer;
begin
  for i := low(FItems) to High(FItems) do
  begin
    p := FItems[i];
    if p <> nil then
    begin
      repeat
        del := False;
        visitor(p^.Key, p^.Value, del);
        if del then
          Remove(p^.Key);
        p := p^.Next;
      until p = nil
    end;
  end;
end;

end.

