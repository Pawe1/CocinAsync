unit cocinasync.async;

interface

uses System.SysUtils, System.Classes, cocinasync.global;

type
  IMREWSync = interface
     procedure BeginRead;
     procedure EndRead;
     procedure BeginWrite;
     procedure EndWrite;
  end;

  TAsync = class(TObject)
  strict private
    FCounter : TThreadCounter;
  public
    class function CreateMREWSync : IMREWSync;
    class procedure SynchronizeIfInThread(const proc : TProc);
    class procedure QueueIfInThread(const proc : TProc);

    procedure AfterDo(const After : Cardinal; const &Do : TProc; SynchronizedDo : boolean = true);
    procedure DoLater(const &Do : TProc; SynchronizedDo : boolean = true);
    procedure OnDo(const &On : TFunc<Boolean>; const &Do : TProc; CheckInterval : integer = 1000; &Repeat : TFunc<boolean> = nil; SynchronizedOn : boolean = false; SynchronizedDo : boolean = true);
    function DoEvery(const MS : Cardinal; const &Do : TFunc<Boolean>; SynchronizedDo : boolean = true) : TThread;

    constructor Create; reintroduce; virtual;
    destructor Destroy; override;
  end;

var
  // NOTE: This global object handles async work at the global level. If you
  //       are using within a form or some other object that could be destroyed
  //       before the app is terminated, then you should create your own instance
  //       in your form or other object and use that instead.  This will ensure
  //       that async operations are complete before your object is destroyed.
  Async : TAsync;

{$IFDEF MSWINDOWS}
  {.$DEFINE USEOURMWERS}
{$ENDIF}

implementation

uses System.Threading, System.SyncObjs {$IFDEF USEOURMWERS}, WinAPI.Windows {$ENDIF};

type
  // NOTE: The intention here was to provide a faster MREWSync. Unfortunately
  //       the implementation below has a deadlock in it that hasn't yet been fixed
  //       for now the default is to use the MREWSync that comes with Delphi.

  { TFastMREWSync }

  TFastMREWSync = class(TInterfacedObject, IMREWSync)
  private
    FRef : {$IFDEF USEOURMWERS}Integer{$ELSE}TMREWSync{$ENDIF};
    {$IFDEF USEOURMWERS}
    FReadLockCount : Cardinal;
    FWriteLockCount : Cardinal;
    {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    procedure BeginRead;
    procedure EndRead;
    procedure BeginWrite;
    procedure EndWrite;
  end;

{ TFastMREWSync }

constructor TFastMREWSync.Create;
begin
  inherited Create;
  {$IFNDEF USEOURMWERS}
  FRef := TMREWSync.Create;
  {$ENDIF}
end;

destructor TFastMREWSync.Destroy;
begin
  {$IFNDEF USEOURMWERS}
  FRef.Free;
  {$ENDIF}

  inherited;
end;

procedure TFastMREWSync.BeginRead;
{$IFDEF USEOURMWERS}
var
  ref : Integer;
begin
  //Wait on writer to reset write flag so Reference.Bit0 must be 0 than increase Reference
  repeat
      ref := Integer(FRef) and not 1;
  until ref = Integer(InterlockedCompareExchange(FRef, ref + 2, ref));
  inc(FReadLockCount);
end;
{$ELSE}
begin
   FRef.BeginRead;
end;
{$ENDIF}

procedure TFastMREWSync.BeginWrite;
{$IFDEF USEOURMWERS}
var
  ref : integer;
begin
  //Wait on writer to reset write flag so omrewReference.Bit0 must be 0 then set omrewReference.Bit0
  repeat
      ref := FRef and (not 1);
  until ref = Integer(InterlockedCompareExchange(FRef, ref+1, ref));

  //Now wait on all readers
  repeat
  until FRef = 1;
  inc(FWriteLockCount);
end;
{$ELSE}
begin
   FRef.BeginWrite;
end;
{$ENDIF}

procedure TFastMREWSync.EndRead;
begin
  {$IFDEF USEOURMWERS}
  //Decrease omrewReference
  InterlockedExchangeAdd(@FRef, -2);
  dec(FReadLockCount);
  {$ELSE}
  FRef.EndRead;
  {$ENDIF}
end;

procedure TFastMREWSync.EndWrite;
begin
  {$IFDEF USEOURMWERS}
  FRef := 0;
  dec(FWriteLockCount);
  {$ELSE}
  FRef.EndWrite;
  {$ENDIF}
end;

  { TAsync }

constructor TAsync.Create;
begin
  inherited Create;
  FCounter := TThreadCounter.Create;
end;

class function TAsync.CreateMREWSync : IMREWSync;
begin
  Result := TFastMREWSync.Create;
end;


class procedure TAsync.SynchronizeIfInThread(const proc : TProc);
begin
  if TThread.Current.ThreadID <> MainThreadID then
  begin
    TThread.Synchronize(TThread.Current,
      procedure
      begin
        proc();
      end
    );
  end else
    proc();
end;

class procedure TAsync.QueueIfInThread(const proc : TProc);
begin
  if TThread.Current.ThreadID <> MainThreadID then
  begin
    TThread.Queue(TThread.Current,
      procedure
      begin
        proc();
      end
    );
  end else
    proc();
end;

type
  TThreadHack = class(TThread) end;

destructor TAsync.Destroy;
begin
  FCounter.Free;
  inherited;
end;

function TAsync.DoEvery(const MS : Cardinal; const &Do : TFunc<Boolean>; SynchronizedDo : boolean = true) : TThread;
begin
  Result := TThread.CreateAnonymousThread(
    procedure
    var
      bContinue : boolean;
    begin
      FCounter.NotifyThreadStart;
      try
        bContinue := True;
        while not TThreadHack(TThread.Current).Terminated do
        begin
          sleep(MS);
          if SynchronizedDo then
            SynchronizeIfInThread(
              procedure
              begin
                bContinue := &Do();
              end
            )
          else
            bContinue := &Do();
          if not bContinue then
            break;
        end;
      finally
        FCounter.NotifyThreadEnd;
      end;
    end
  );

  Result.Start;
end;

procedure TAsync.AfterDo(const After : Cardinal; const &Do : TProc; SynchronizedDo : boolean = true);
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      FCounter.NotifyThreadStart;
      try
        sleep(After);
        if SynchronizedDo then
          SynchronizeIfInThread(
            procedure
            begin
              &Do();
            end
          )
        else
          &Do();
      finally
        FCounter.NotifyThreadEnd;
      end;
    end
  ).Start;
end;

procedure TAsync.DoLater(const &Do : TProc; SynchronizedDo : boolean = true);
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      FCounter.NotifyThreadStart;
      try
        if SynchronizedDo then
          SynchronizeIfInThread(
            procedure
            begin
              &Do();
            end
          )
        else
          &Do();
      finally
        FCounter.NotifyThreadEnd;
      end;
    end
  ).Start;
end;

procedure TAsync.OnDo(const &On : TFunc<Boolean>; const &Do : TProc; CheckInterval : integer = 1000; &Repeat : TFunc<boolean> = nil; SynchronizedOn : boolean = false; SynchronizedDo : boolean = true);
begin
  if not Assigned(&Repeat) then
    &Repeat :=
      function : boolean
      begin
        Result := False;
      end;

  TThread.CreateAnonymousThread(
    procedure
    var
      bOn : Boolean;
    begin
      FCounter.NotifyThreadStart;
      try
        repeat
          repeat
            if SynchronizedOn then
              SynchronizeIfInThread(
                procedure
                begin
                  bOn := &On();
                end
              )
            else
              bOn := &On();
            if bOn then
              break;
            sleep(CheckInterval)
          until bOn;

          if SynchronizedDo then
            SynchronizeIfInThread(
              procedure
              begin
                &Do();
              end
            )
          else
            &Do();
        until not &Repeat();
      finally
        FCounter.NotifyThreadEnd;
      end;
    end
  ).Start;
end;

initialization
  Async := TAsync.Create;

finalization
  Async.Free;

end.



