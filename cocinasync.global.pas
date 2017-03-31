unit cocinasync.global;

interface

uses System.SysUtils, System.Classes, System.SyncObjs;

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

    procedure WaitForAll(Timeout : Cardinal = 0);
    class property Global : TThreadCounter read FGlobal;
  end;

  TConsole = class(TObject)
  private
    FEvent : TEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Wake(Sender : TObject);
    procedure CheckSynchronize(Timeout : Cardinal = INFINITE);
    class procedure ApplicationLoop(const &Until : TFunc<Boolean>);
  end;

implementation

uses DateUtils;

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

procedure TThreadCounter.WaitForAll(Timeout: Cardinal);
var
  dtStart : TDateTime;
begin
  dtStart := Now;
  while (FThreadCount > 0) and
        (  (Timeout = 0) or
           ((Timeout > 0) and (MillisecondsBetween(dtStart,Now) >= Timeout))
        ) do
    sleep(10);
end;

{ TConsoleSync }

procedure TConsole.CheckSynchronize(Timeout : Cardinal = INFINITE);
begin
  FEvent.WaitFor(Timeout);
  System.Classes.CheckSynchronize;
end;

constructor TConsole.Create;
begin
  inherited Create;
  FEvent := TEvent.Create;
  WakeMainThread := Wake;
end;

destructor TConsole.Destroy;
begin
  FEvent.Free;
  inherited;
end;

class procedure TConsole.ApplicationLoop(const &Until: TFunc<Boolean>);
var
  CS : TConsole;
begin
  CS := TConsole.Create;
  try
    repeat
      CS.CheckSynchronize(1000);
    until not &Until();
  finally
    CS.Free;
  end;
end;

procedure TConsole.Wake(Sender: TObject);
begin
  FEvent.SetEvent;
end;

initialization
  // NOTE: Using initialization and finalization to ensure is referenced
  //       where class constructor and class destructor may be optimized out.
  TThreadCounter.GlobalInitialize;

finalization
  TThreadCounter.GlobalFinalize;

end.
