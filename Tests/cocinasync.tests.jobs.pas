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
    [TestCase('TestA','1')]
    [TestCase('TestB','2')]
    [TestCase('TestC','3')]
    [TestCase('TestD','4')]
    [TestCase('TestD','5')]
    [TestCase('TestD','6')]
    [TestCase('TestD','7')]
    [TestCase('TestD','8')]
    [TestCase('TestD','9')]
    [TestCase('TestD','10')]
    [TestCase('TestD','11')]
    [TestCase('TestD','12')]
    [TestCase('TestD','13')]
    [TestCase('TestD','14')]
    [TestCase('TestD','15')]
    [TestCase('TestD','16')]
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
begin
  if HowMany > CPUCount then
  begin
    Assert.Pass('Skipped Test Due to Test more than CPU Count');
  end;
  dtStart := Now;
  for i := 1 to HowMany do
    FJobs.Queue(
      procedure
      begin
        Sleep(1000);
      end
    );
  FJobs.WaitForAll(10000);
  iMS := MilliSecondsBetween(dtStart, Now);
  if iMS < 10 then
    Assert.Pass('Time: '+iMS.ToString)
  else
    Assert.Fail('Unexpected Wait: '+iMS.ToString);
end;

initialization
  TDUnitX.RegisterTestFixture(TestIJobs);
end.
