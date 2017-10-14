unit cocinasync.jobs;

interface

uses System.SysUtils, System.SyncObjs, Cocinasync.Collections;

type
  IJob = interface
    procedure SetupJob;
    procedure ExecuteJob;
    procedure FinishJob;
    function Wait(Timeout : Cardinal = 0) : boolean; overload;
    procedure Wait(var Completed : boolean; Timeout : Cardinal = 0); overload;
  end;

  IJob<T> = interface(IJob)
    function Result : T;
  end;

  TJobQueue = class(TQueue<IJob>)
  public
    function WaitForAll(Timeout : Cardinal = 0) : boolean; inline;
    procedure Abort;
  end;

  TJobQueue<T> = class(TQueue<IJob<T>>)
  public
    function WaitForAll(Timeout : Cardinal = 0) : boolean; inline;
    procedure Abort;
  end;

  IJobs = interface
    procedure Queue(const DoIt : TProc); overload;
    procedure Queue(const Job : IJob); overload;
    procedure WaitForAll(Timeout : Cardinal = 0);
  end;

  TDefaultJob<T> = class(TInterfacedObject, IJob, IJob<T>)
  private
    FProcToExecute : TProc;
    FFuncToExecute : TFunc<T>;
    FEvent : TEvent;
    FResult : T;
    procedure SetEvent; inline;
  public
    constructor Create(ProcToExecute : TProc; FuncToExecute : TFunc<T>); reintroduce; virtual;
    destructor Destroy; override;

    procedure ExecuteJob; inline;
    procedure SetupJob; inline;
    procedure FinishJob; inline;
    function Wait(Timeout : Cardinal = 0) : boolean; overload; inline;
    procedure Wait(var Completed : boolean; Timeout : Cardinal = 0); overload; inline;
    function Result : T; inline;
  end;

  TJobManager = class
  public
    class function CreateJobs(RunnerCount : Cardinal = 0; MaxJobs : Integer = 4096) : IJobs;
    class function Job(const AJob : TProc) : IJob; overload; inline;
    class function Job<T>(const AJob : TFunc<T>) : IJob<T>; overload; inline;
    class function Execute(const AJob : TProc; AJobs : IJobs = nil) : IJob; overload; inline;
    class function Execute<T>(const AJob : TFunc<T>; AJobs : IJobs = nil) : IJob<T>; overload; inline;
    class function Execute(const AJob : TProc; AQueue : TJobQueue; AJobs : IJobs = nil) : IJob; overload; inline;
    class function Execute<T>(const AJob : TFunc<T>; AQueue : TJobQueue<T>; AJobs : IJobs = nil) : IJob<T>; overload; inline;
  end;

var
  Jobs : IJobs;

implementation

uses System.Classes, cocinasync.async, System.Diagnostics;

type
  TJobs = class;

  TJobRunner = class(TThread)
  strict private
    [Weak]
    FJobs : TJobs;
  protected
    procedure Execute; override;
  public
    constructor Create(Jobs : TJobs); reintroduce; virtual;
  end;

  TJobs = class(TInterfacedObject, IJobs)
  strict private
    FTerminating : boolean;
    FRunners : TQueue<TJobRunner>;
    FJobs : TQueue<IJob>;
    procedure TerminateRunners;
  private
    FJobRunnerCount : integer;
    FJobsInProcess : integer;
  public
    constructor Create(RunnerCount : Integer; MaxJobs : Integer = 4096); reintroduce; virtual;
    destructor Destroy; override;

    function Next : IJob; inline;
    procedure Queue(const DoIt : TProc); overload; inline;
    procedure Queue(const Job : IJob); overload; inline;
    procedure WaitForAll(Timeout : Cardinal = 0); inline;
    property Terminating : boolean read FTerminating;
  end;

{ TJobManager }

class function TJobManager.CreateJobs(RunnerCount : Cardinal = 0; MaxJobs : Integer = 4096) : IJobs;
var
  iCnt : Cardinal;
begin
  if RunnerCount = 0 then
    iCnt := CPUCount
  else
    iCnt := RunnerCount;

  Result := TJobs.Create(iCnt, MaxJobs);
end;

class function TJobManager.Execute(const AJob: TProc; AJobs : IJobs = nil): IJob;
begin
  Result := Job(AJob);
  if AJobs = nil then
    AJobs := Jobs;
  AJobs.Queue(Result);
end;

class function TJobManager.Execute<T>(const AJob: TFunc<T>; AJobs : IJobs = nil): IJob<T>;
begin
  Result := Job<T>(AJob);
  if AJobs = nil then
    AJobs := Jobs;
  AJobs.Queue(Result);
end;

class function TJobManager.Execute(const AJob: TProc; AQueue: TJobQueue; AJobs : IJobs = nil): IJob;
begin
  Result := Job(AJob);
  AQueue.Enqueue(Result);
  if AJobs = nil then
    AJobs := Jobs;
  Jobs.Queue(Result);
end;

class function TJobManager.Execute<T>(const AJob: TFunc<T>; AQueue: TJobQueue<T>; AJobs : IJobs = nil): IJob<T>;
begin
  Result := Job<T>(AJob);
  AQueue.Enqueue(Result);
  if AJobs = nil then
    AJobs := Jobs;
  AJobs.Queue(Result);
end;

class function TJobManager.Job(const AJob: TProc): IJob;
begin
  Result := TDefaultJob<Boolean>.Create(AJob,nil);
end;

class function TJobManager.Job<T>(const AJob: TFunc<T>): IJob<T>;
begin
  Result := TDefaultJob<T>.Create(nil, AJob);
end;

{ TJobs }

constructor TJobs.Create(RunnerCount: Integer; MaxJobs : Integer = 4096);
begin
  inherited Create;
  FTerminating := False;
  FJobs := TQueue<IJob>.Create(MaxJobs);
  FJobRunnerCount := 0;
  FJobsInProcess := 0;
  FRunners := TQueue<TJobRunner>.Create(RunnerCount+1);
  while FRunners.Count < RunnerCount do
    FRunners.Enqueue(TJobRunner.Create(Self));
end;

destructor TJobs.Destroy;
begin
  TerminateRunners;
  FJobs.Free;
  FRunners.Free;
  inherited;
end;

function TJobs.Next: IJob;
begin
  Result := FJobs.Dequeue;
end;

procedure TJobs.Queue(const DoIt: TProc);
begin
  Queue(TJobManager.Job(DoIt));
end;

procedure TJobs.Queue(const Job : IJob);
begin
  if FTerminating then
    raise Exception.Create('Cannot queue while Jobs are terminating.');
  FJobs.Enqueue(Job);
end;

procedure TJobs.TerminateRunners;
var
  i : integer;
  r : TJobRunner;
  rq : TQueue<TJobRunner>;
begin
  FTerminating := True;
  WaitForAll(3000);
  FJobs.Clear;

  rq := TQueue<TJobRunner>.Create(FRunners.Count+1);
  try
    repeat
      r := FRunners.Dequeue;
      if not Assigned(r) then
        break;
      r.Terminate;
      rq.Enqueue(r);
    until not Assigned(r);

    while FJobRunnerCount > 0 do
      Sleep(10);

    repeat
      r := rq.Dequeue;
      r.Free;
    until not Assigned(r);
  finally
    rq.Free;
  end;
end;


procedure TJobs.WaitForAll(Timeout : Cardinal = 0);
var
  timer : TStopWatch;
  sw : TSpinWait;
begin
  timer := TStopWatch.StartNew;
  sw.Reset;
  while ((FJobs.Count > 0) or (FJobsInProcess > 0)) and
        (  (Timeout = 0) or
           ((Timeout > 0) and (timer.ElapsedMilliseconds <= Timeout))
        ) do
    sw.SpinCycle;
end;

{ TJobRunner }

constructor TJobRunner.Create(Jobs : TJobs);
begin
  inherited Create(False);
  FJobs := Jobs;
  FreeOnTerminate := False;
end;

procedure TJobRunner.Execute;
var
  wait : TSpinWait;
  job : IJob;
begin
  TInterlocked.Increment(FJobs.FJobRunnerCount);
  try
    wait.Reset;
    while not Terminated do
    begin
      job := FJobs.Next;
      if job <> nil then
      begin
        if FJobs.Terminating then
          exit;

        TInterlocked.Increment(FJobs.FJobsInProcess);
        try
          wait.Reset;
          job.SetupJob;
          try
            job.ExecuteJob;
          finally
            job.FinishJob;
          end;
        finally
          TInterlocked.Decrement(FJobs.FJobsInProcess);
        end;
      end else
        wait.SpinCycle;
    end;
  finally
    TInterlocked.Decrement(FJobs.FJobRunnerCount);
  end;
end;

{ TDefaultJob }

constructor TDefaultJob<T>.Create(ProcToExecute : TProc; FuncToExecute : TFunc<T>);
begin
  inherited Create;
  FResult := T(nil);
  FProcToExecute := ProcToExecute;
  FFuncToExecute := FuncToExecute;
  FEvent := TEvent.Create;
  FEvent.ResetEvent;
end;

destructor TDefaultJob<T>.Destroy;
begin
  FEvent.Free;
  inherited;
end;

procedure TDefaultJob<T>.ExecuteJob;
begin
  if Assigned(FProcToExecute) then
    FProcToExecute()
  else if Assigned(FFuncToExecute) then
    FResult := FFuncToExecute();

  SetEvent;
end;

procedure TDefaultJob<T>.FinishJob;
begin
  // Nothing to finish
end;

function TDefaultJob<T>.Result: T;
begin
  Result := FResult;
end;

procedure TDefaultJob<T>.SetEvent;
begin
  FEvent.SetEvent;
end;

procedure TDefaultJob<T>.SetupJob;
begin
  // Nothing to Setup
end;

procedure TDefaultJob<T>.Wait(var Completed: boolean; Timeout: Cardinal);
var
  wr : TWaitResult;
begin
  wr := FEvent.WaitFor(Timeout);
  Completed := wr <> TWaitResult.wrTimeout;
end;

function TDefaultJob<T>.Wait(Timeout: Cardinal): boolean;
var
  wr : TWaitResult;
begin
  wr := FEvent.WaitFor(Timeout);
  Result := wr <> TWaitResult.wrTimeout;
end;


{ TJobQueue }

procedure TJobQueue.Abort;
var
  j : IJob;
begin
  repeat
    j := Dequeue;
  until j = nil;
end;

function TJobQueue.WaitForAll(Timeout: Cardinal): boolean;
var
  j : IJob;
  timer : TStopWatch;
begin
  timer := TStopWatch.StartNew;
  Result := True;
  while Count > 0 do
  begin
    j := Dequeue;
    if not j.Wait(1) then
      Enqueue(j);
    if (Count > 0) and (timer.ElapsedMilliseconds >= Timeout) then
    begin
      Result := False;
      break;
    end;
  end;
end;

{ TJobQueue<T> }

procedure TJobQueue<T>.Abort;
var
  j : IJob;
begin
  repeat
    j := Dequeue;
  until j = nil;
end;

function TJobQueue<T>.WaitForAll(Timeout: Cardinal): boolean;
var
  j : IJob<T>;
  timer : TStopWatch;
begin
  timer := TStopWatch.StartNew;
  Result := True;
  while Count > 0 do
  begin
    j := Dequeue;
    if not j.Wait(1) then
      Enqueue(j);
    if (Count > 0) and (timer.ElapsedMilliseconds >= Timeout) then
    begin
      Result := False;
      break;
    end;
  end;
end;

initialization
  Jobs := TJobManager.CreateJobs;

finalization
  Jobs.WaitForAll;

end.
