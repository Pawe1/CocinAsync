unit cocinasync.tests.jobs;

interface

uses
  DUnitX.TestFramework, cocinasync.jobs;

type

  [TestFixture]
  TestIJobs = class(TObject)
  strict private
    FJobs : IJobs;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure EarlyFree;
    [Test]
    [TestCase('QueueAnonymousMethodAndWait-1','1')]
    [TestCase('QueueAnonymousMethodAndWait-2','2')]
    [TestCase('QueueAnonymousMethodAndWait-3','3')]
    [TestCase('QueueAnonymousMethodAndWait-4','4')]
    [TestCase('QueueAnonymousMethodAndWait-5','5')]
    [TestCase('QueueAnonymousMethodAndWait-6','6')]
    [TestCase('QueueAnonymousMethodAndWait-7','7')]
    [TestCase('QueueAnonymousMethodAndWait-8','8')]
    [TestCase('QueueAnonymousMethodAndWait-9','9')]
    [TestCase('QueueAnonymousMethodAndWait-10','10')]
    [TestCase('QueueAnonymousMethodAndWait-11','11')]
    [TestCase('QueueAnonymousMethodAndWait-12','12')]
    [TestCase('QueueAnonymousMethodAndWait-13','13')]
    [TestCase('QueueAnonymousMethodAndWait-14','14')]
    [TestCase('QueueAnonymousMethodAndWait-15','15')]
    [TestCase('QueueAnonymousMethodAndWait-16','16')]
    procedure QueueAnonymousMethodAndWait(HowMany : Integer);

    [Test]
    [TestCase('QueueAnonymousFunctionAndWait-1','1')]
    [TestCase('QueueAnonymousFunctionAndWait-2','2')]
    [TestCase('QueueAnonymousFunctionAndWait-3','3')]
    [TestCase('QueueAnonymousFunctionAndWait-4','4')]
    [TestCase('QueueAnonymousFunctionAndWait-5','5')]
    [TestCase('QueueAnonymousFunctionAndWait-6','6')]
    [TestCase('QueueAnonymousFunctionAndWait-7','7')]
    [TestCase('QueueAnonymousFunctionAndWait-8','8')]
    [TestCase('QueueAnonymousFunctionAndWait-9','9')]
    [TestCase('QueueAnonymousFunctionAndWait-10','10')]
    [TestCase('QueueAnonymousFunctionAndWait-11','11')]
    [TestCase('QueueAnonymousFunctionAndWait-12','12')]
    [TestCase('QueueAnonymousFunctionAndWait-13','13')]
    [TestCase('QueueAnonymousFunctionAndWait-14','14')]
    [TestCase('QueueAnonymousFunctionAndWait-15','15')]
    [TestCase('QueueAnonymousFunctionAndWait-16','16')]
    procedure QueueAnonymousFunctionAndWait(HowMany : Integer);

    [Test]
    procedure TestAbort;

    [Test]
    procedure JobReturnValue;

    [Test]
    procedure JobWait;
  end;

implementation

uses System.SysUtils, System.DateUtils, System.SyncObjs, System.Diagnostics;

procedure TestIJobs.Setup;
begin
  FJobs := TJobManager.CreateJobs;
end;

procedure TestIJobs.TearDown;
begin
  FJobs := nil;
end;

procedure TestIJobs.TestAbort;
var
  jobs : IJobs;
  queue : TJobQueue;
  i: Integer;
  iCnt : Integer;
begin
  iCnt := 0;
  queue := TJobQueue.Create(4096);
  try
    jobs := TJobManager.CreateJobs(CPUCount);

    for i := 1 to CPUCount*2 do
      TJobManager.Execute(
        procedure
        begin
          TInterlocked.Increment(iCnt);
          Sleep(3000);
        end,
        queue,
        jobs
      );

    sleep(100);
    queue.Abort;
    Assert.AreEqual(CPUCount, iCnt, ': unexpected number of jobs executed.');
    jobs := nil;
  finally
    queue.Free;
  end;
  Assert.Pass;
end;

procedure TestIJobs.EarlyFree;
var
  jobs : IJobs;
begin
  try
    jobs := TJobManager.CreateJobs;
    jobs.Queue(
      procedure
      begin
        Sleep(1000);
      end
    );
    jobs := nil;
  except
    on E: Exception do
    begin
      Assert.Fail(E.Message);
      exit;
    end
  end;
  Assert.Pass;
end;

procedure TestIJobs.JobReturnValue;
var
  job : IJob<string>;
  sVal : string;
begin
  job := TJobManager.Execute<string>(
        function : string
        begin
          Sleep(3000);
          result := 'Value Set';
        end
      );
  sVal := job.Result;
  Assert.AreEqual('Value Set',sVal);
end;

procedure TestIJobs.JobWait;
var
  j1, j2 : IJob;
  bj2Finished : boolean;
  timer : TStopWatch;
  iMS : Int64;
begin
  bj2Finished := False;
  j1 := TJobManager.Job(
    procedure
    begin
      sleep(3000);
    end
  );
  j2 := TJobManager.Job(
    procedure
    begin
      sleep(1000);
      bj2Finished := True;
    end
  );
  jobs.Queue(j1);
  jobs.Queue(j2);
  timer := TStopWatch.StartNew;
  if (not j1.Wait(4000)) then
  begin
    iMS := timer.ElapsedMilliseconds;
    Assert.Fail('Job Wait Timed Out: '+iMS.ToString);
  end;
  iMS := timer.ElapsedMilliseconds;
  if (iMS < 3000) then
    Assert.Fail('Job did not wait: '+iMS.ToString);
  Assert.AreEqual(True, bj2Finished, 'Second job did not run while waiting');
end;

procedure TestIJobs.QueueAnonymousFunctionAndWait(HowMany: Integer);
var
  dtStart : TDateTime;
  iMS : Cardinal;
  i : integer;
  iWait : integer;
  queue : TJobQueue<integer>;
  jobLast : IJob<integer>;
begin
  if HowMany > CPUCount then
  begin
    Assert.Pass('Skipped Test Due to Test more than CPU Count');
  end;
  iWait := 1005+ (HowMany div CPUCount); // give 5ms buffer

  queue := TJobQueue<integer>.Create(HowMany+1);
  try
    dtStart := Now;

    for i := 1 to HowMany do
      jobLast := TJobManager.Execute<integer>(
        function : Integer
        begin
          Sleep(1000);
          Result := i;
        end,
        queue,
        FJobs
      );
    if not queue.WaitForAll(iWait) then
      Assert.Fail('Wait Timeout');
    if jobLast.Result = 0 then
      Assert.Fail('Job Result was not set');
  finally
    queue.Free;
  end;
  iMS := MilliSecondsBetween(dtStart, Now);
  if iMS <= iWait then
    Assert.Pass('Time: '+iMS.ToString)
  else
    Assert.Fail('Unexpected Wait: '+iMS.ToString+' allowed '+(iWait).ToString);
end;

procedure TestIJobs.QueueAnonymousMethodAndWait(HowMany : Integer);
var
  dtStart : TDateTime;
  iMS : Cardinal;
  i : integer;
  iWait : integer;
begin
  if HowMany > CPUCount then
  begin
    Assert.Pass('Skipped Test Due to Test more than CPU Count');
  end;
  iWait := 1005+ (HowMany div CPUCount); // give 5ms buffer

  dtStart := Now;
  for i := 1 to HowMany do
    FJobs.Queue(
      procedure
      begin
        Sleep(1000);
      end
    );
  FJobs.WaitForAll(iWait);
  iMS := MilliSecondsBetween(dtStart, Now);
  if iMS <= iWait then
    Assert.Pass('Time: '+iMS.ToString)
  else
    Assert.Fail('Unexpected Wait: '+iMS.ToString+' allowed '+(iWait).ToString);
end;

initialization
  TDUnitX.RegisterTestFixture(TestIJobs);
end.
