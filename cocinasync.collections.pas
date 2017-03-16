unit cocinasync.collections;

interface

uses System.SysUtils, System.Classes, System.SyncObjs;

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
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;

    procedure Push(const Value: T); //inline;
    function Pop: T; //inline;
    function Peek: T; //inline;
    procedure Clear;
  end;

implementation

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

function TStack<T>.Pop: T;
var
  p, pTop : PStackPointer;
  iCnt : integer;
  bSucceeded : boolean;
begin
  pTop := FTop;
  if (pTop <> nil) and (pTop <> FFirst) then
  begin
    while (pTop.FPrior = nil) do
    begin
      sleep(1);
    end;
    p := PStackPointer(TInterlocked.CompareExchange(FTop,PStackPointer(pTop)^.FPrior, pTop,bSucceeded));
    if bSucceeded then
    begin
      Result := p^.FData;
      Dispose(pTop);
    end else
      Result := Pop;
  end else
    Result := T(nil);
end;

procedure TStack<T>.Push(const Value: T);
var
  ptop, p : Pointer;
begin
  p := New(PStackPointer);
  PStackPointer(p)^.FData := Value;
  PStackPointer(p).FPrior := TInterlocked.Exchange(FTop,p);
end;

end.
