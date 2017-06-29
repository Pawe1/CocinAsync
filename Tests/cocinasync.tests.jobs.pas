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
    // Test with TestCase Atribute to supply parameters.
  end;

implementation

uses System.SysUtils, System.DateUtils;

procedure TestIJobs.Setup;
begin
  FJobs := CreateJobs;
end;

procedure TestIJobs.TearDown;
begin
  FJobs := nil;
end;

procedure TestIJobs.EarlyFree;
var
  jobs : IJobs;
begin
  try
    jobs := CreateJobs;
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
  iWait := 1010+ (HowMany div CPUCount);

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
