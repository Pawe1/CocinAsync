unit cocinasync.jobs;

interface

uses System.SysUtils;

type
  IJob = interface
    procedure SetupJob;
    procedure ExecuteJob;
    procedure FinishJob;
  end;

  IJobs = interface
    procedure Queue(const DoIt : TProc); overload;
    procedure Queue(const Job : IJob); overload;
    procedure WaitForAll(Timeout : Cardinal = 0);
  end;

function CreateJobs(RunnerCount : Cardinal = 0; SleepDelay : Cardinal = 10) : IJobs;

var
  Jobs : IJobs;

implementation

uses System.Classes, System.SyncObjs, System.Generics.Collections, System.DateUtils,
  cocinasync.async;

type
  TDefaultJob = class(TInterfacedObject, IJob)
  private
    FProcToExecute : TProc;
  public
    constructor Create(ProcToExecute : TProc); reintroduce; virtual;

    procedure ExecuteJob;
    procedure SetupJob;
    procedure FinishJob;
  end;

  TJobs = class;

  TJobRunner = class(TThread)
  strict private
    FSleepDelay : Cardinal;
    [Weak]
    FJobs : TJobs;
  protected
    procedure Execute; override;
  public
    constructor Create(Jobs : TJobs; SleepDelay : Cardinal); reintroduce; virtual;
  end;

  TJobs = class(TInterfacedObject, IJobs)
  strict private
    FSleepDelay : Cardinal;
    FTerminating : boolean;
    FRunners : TList<TJobRunner>;
    FJobs : TQueue<IJob>;
    FJobsCS : TCriticalSection;
    procedure TerminateRunners;
  private
    FJobRunnerCount : integer;
    FJobsInProcess : integer;
  public
    constructor Create(RunnerCount : Integer; SleepDelay : Cardinal); reintroduce; virtual;
    destructor Destroy; override;

    function Next : IJob;
    procedure Queue(const DoIt : TProc); overload;
    procedure Queue(const Job : IJob); overload;
    procedure WaitForAll(Timeout : Cardinal = 0);
    property Terminating : boolean read FTerminating;
  end;

function CreateJobs(RunnerCount : Cardinal = 0; SleepDelay : Cardinal = 10) : IJobs;
var
  iCnt : Cardinal;
begin
  if RunnerCount = 0 then
    iCnt := CPUCount
  else
    iCnt := RunnerCount;

  Result := TJobs.Create(iCnt, SleepDelay);
end;

{ TJobs }

constructor TJobs.Create(RunnerCount: Integer; SleepDelay : Cardinal);
begin
  inherited Create;
  FTerminating := False;
  FJobsCS := TCriticalSection.Create;
  FJobs := TQueue<IJob>.Create;
  FJobRunnerCount := 0;
  FJobsInProcess := 0;
  FRunners := TList<TJobRunner>.Create;
  FSleepDelay := SleepDelay;
  while FRunners.Count < RunnerCount do
    FRunners.Add(TJobRunner.Create(Self, FSleepDelay));
end;

destructor TJobs.Destroy;
begin
  TerminateRunners;
  FJobsCS.Free;
  FJobs.Free;
  FRunners.Free;
  inherited;
end;

function TJobs.Next: IJob;
begin
  Result := nil;
  // NOTE: FJobs.Count should be fine to read outside of the critical section.
  //       It's only ever changed inside the critical section.
  if FJobs.Count > 0 then
  begin
    FJobsCS.Enter;
    try
      if FJobs.Count > 0 then
        Result := FJobs.Dequeue;
    finally
      FJobsCS.Leave;
    end;
  end;
end;

procedure TJobs.Queue(const DoIt: TProc);
begin
  Queue(TDefaultJob.Create(DoIt));
end;

procedure TJobs.Queue(const Job : IJob);
begin
  if FTerminating then
    raise Exception.Create('Cannot queue while Jobs are terminating.');
  FJobsCS.Enter;
  try
    FJobs.Enqueue(Job);
  finally
    FJobsCS.Leave;
  end;
end;

procedure TJobs.TerminateRunners;
var
  i : integer;
begin
  FTerminating := True;
  WaitForAll(3000);
  FJobsCS.Enter;
  try
    FJobs.Clear;
  finally
    FJobsCS.Leave;
  end;
  for i := 0 to FRunners.Count-1 do
  begin
    FRunners[i].Terminate;
  end;
  while FJobRunnerCount > 0 do
    Sleep(10);
  FRunners.Clear;
end;

procedure TJobs.WaitForAll(Timeout : Cardinal = 0);
var
  dtStart : TDateTime;
begin
  dtStart := Now;
  while ((FJobs.Count > 0) or (FJobsInProcess > 0)) and
        (  (Timeout = 0) or
           ((Timeout > 0) and (MillisecondsBetween(dtStart,Now) >= Timeout))
        ) do
    sleep(10);
end;

{ TJobRunner }

constructor TJobRunner.Create(Jobs : TJobs; SleepDelay : Cardinal);
begin
  inherited Create(False);
  FSleepDelay := SleepDelay;
  FJobs := Jobs;
  FreeOnTerminate := True;
end;

procedure TJobRunner.Execute;
var
  job : IJob;
begin
  TInterlocked.Increment(FJobs.FJobRunnerCount);
  try
    while not Terminated do
    begin
      job := FJobs.Next;
      if job <> nil then
      begin
        if FJobs.Terminating then
          exit;

        TInterlocked.Increment(FJobs.FJobsInProcess);
        try
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
        sleep(FSleepDelay);
    end;
  finally
    TInterlocked.Decrement(FJobs.FJobRunnerCount);
  end;
end;

{ TDefaultJob }

constructor TDefaultJob.Create(ProcToExecute: TProc);
begin
  inherited Create;
  FProcToExecute := ProcToExecute;
end;

procedure TDefaultJob.ExecuteJob;
begin
  FProcToExecute();
end;

procedure TDefaultJob.FinishJob;
begin
  // Nothing to finish
end;

procedure TDefaultJob.SetupJob;
begin
  // Nothing to Setup
end;

initialization
  Jobs := CreateJobs;

finalization
  Jobs.WaitForAll;

end.
