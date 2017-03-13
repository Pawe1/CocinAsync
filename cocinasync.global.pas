unit cocinasync.global;

interface

uses System.Classes;

type
  TThreadCounter = class(TObject)
  strict private
    FTerminating : Boolean;
    FThreadCount : Integer;
    class var FGlobal : TThreadCounter;
  private
    class procedure GlobalInitialize;
    class procedure GlobalFinalize;
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;

    procedure NotifyThreadStart;
    procedure NotifyThreadEnd;
    property ThreadCount : Integer read FThreadCount;

    class property Global : TThreadCounter read FGlobal;
  end;

implementation

uses System.SysUtils, System.SyncObjs;

{ TCocinAsync }

constructor TThreadCounter.Create;
begin
  inherited Create;
  FTerminating := False;
  FThreadCount := 0;
end;

destructor TThreadCounter.Destroy;
begin
  FTerminating := True;
  while FThreadCount > 0 do
    sleep(10);
  inherited;
end;

class procedure TThreadCounter.GlobalFinalize;
begin
  FreeAndNil(FGlobal);
end;

class procedure TThreadCounter.GlobalInitialize;
begin
  FGlobal := TThreadCounter.Create;
end;

procedure TThreadCounter.NotifyThreadEnd;
begin
  TInterlocked.Decrement(FThreadCount);
end;

procedure TThreadCounter.NotifyThreadStart;
begin
  if FTerminating then
    Abort;
  TInterlocked.Increment(FThreadCount);
end;

initialization
  // NOTE: Using initialization and finalization to ensure is referenced
  //       where class constructor and class destructor may be optimized out.
  TThreadCounter.GlobalInitialize;

finalization
  TThreadCounter.GlobalFinalize;

end.
