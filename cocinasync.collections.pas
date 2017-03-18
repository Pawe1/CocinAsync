unit cocinasync.collections;

interface

uses System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Defaults;

const
  HASH_ARRAY_SIZE = 16384;

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
    TItemArray = array[0..HASH_ARRAY_SIZE-1] of Pointer;
  strict private
    FItems: TItemArray;
    FComparer : IEqualityComparer<K>;
    function GetMap(Key: K): V;
    procedure SetMap(Key: K; const Value: V; NewItem : PItem); overload; inline;
    procedure SetMap(Key: K; const Value: V); overload;
    function GetHas(Key: K): boolean;
    function GetHash(Key : K) : Integer; inline;
    function CalcDepth(item: PItem): integer; inline;
  public
    type
      TDepth = record
        EmptyCnt : integer;
        MaxDepth : integer;
        Average  : integer;
        AvgFilled : integer;
        Size : integer;
      end;
  public
    constructor Create; reintroduce; virtual;
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
      Result := Pop(Depth+1);
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
  ptop, p : Pointer;
  bSuccess : boolean;
  iSleep : integer;
begin
  p := New(PStackPointer);
  PStackPointer(p)^.FData := Value;
  bSuccess := False;
  iSleep := 0;
  repeat
    PStackPointer(p).FPrior := FTop;
    TInterlocked.CompareExchange(FTop,p,PStackPointer(p).FPrior,bSuccess);
    if not bSuccess then
    begin
      sleep(iSleep);
      inc(iSleep);
    end;
  until bSuccess;
end;

{ THash<K, V> }

procedure THash<K, V>.AddOrSetValue(const Key: K; const Value: V);
begin
  SetMap(Key, Value);
end;

constructor THash<K, V>.Create;
var
  i: Integer;
begin
  inherited Create;
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
  Result.Size := HASH_ARRAY_SIZE;
  for i := 0 to HASH_ARRAY_SIZE-1 do
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
  Result.Average := Result.Average div HASH_ARRAY_SIZE;
  Result.AvgFilled := Result.AvgFilled div (HASH_ARRAY_SIZE - Result.EmptyCnt);
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

function THash<K, V>.GetHash(Key: K): Integer;
begin
  result := ((not Integer($80000000)) and FComparer.GetHashCode(Key)) mod HASH_ARRAY_SIZE;
end;

function THash<K, V>.GetMap(Key: K): V;
var
  p : PItem;
begin
  p := FItems[GetHash(Key)];
  if p <> nil then
  begin
    if not FComparer.Equals(p.Key, Key) then
    begin
      repeat
        p := p.Next;
      until (p = nil) or FComparer.Equals(p.Key, Key);

      if p <> nil then
        Result := p.Value
      else
        Result := V(nil);
    end else
      Result := p.Value;
  end else
    Result := V(nil);
end;

procedure THash<K, V>.SetMap(Key: K; const Value: V; NewItem: PItem);
var
  p, pNew, pDisp, pPrior : PItem;
  idx : Integer;
  bSuccess : boolean;
begin
  if NewItem = nil then
  begin
    New(pNew);
    pNew.Key := Key;
    pNew.Value := Value;
  end else
    pNew := NewItem;

  idx := GetHash(Key);
  p := FItems[idx];
  pNew.Next := p;
  pPrior := nil;
  if p <> nil then
  begin
    if not FComparer.Equals(p.Key, Key) then
    begin
      repeat
        pPrior := p;
        p := p.Next;
      until (p = nil) or FComparer.Equals(p.Key, Key);
      if p = nil then // New Key not found in list.
      begin
        pNew.Next := p;
        TInterlocked.CompareExchange(pPrior^.Next, pNew, p, bSuccess);
        if not bSuccess then
        begin
          SetMap(Key,Value, pNew);
        end;
      end else // Key Found, updating
      begin
        pDisp := p;
        pNew.Next := p^.Next;
        TInterlocked.CompareExchange(pPrior^.Next, pNew, p, bSuccess);
        if not bSuccess then
        begin
          SetMap(Key,Value, pNew);
        end else
        begin
          Dispose(pDisp);
        end;
      end;
      exit;
    end;
  end;
  // New Key at position, add a new one.
  TInterlocked.CompareExchange(FItems[idx],pNew,p,bSuccess);
  if not bSuccess then
  begin
    SetMap(Key, Value, pNew);
    exit;
  end;
end;

procedure THash<K, V>.SetMap(Key: K; const Value: V);
begin
  SetMap(Key, Value, nil);
end;

end.
