unit cocinasync.tests.async;

interface

uses
  DUnitX.TestFramework, cocinasync.async;

type

  [TestFixture]
  TestTAsync = class(TObject)
  strict private
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure DoLater;
    [Test]
    procedure OnDo;
    [Test]
    procedure DoEvery;
    [Test]
    procedure AfterDo;
    [Test]
    procedure EarlyFree;
    // Test with TestCase Atribute to supply parameters.
  end;

implementation

uses System.SysUtils, System.DateUtils, SyncObjs;

procedure TestTAsync.OnDo;
var
  bDo, bDone : boolean;
begin
  bDo := False;
  bDone := False;
  Async.OnDo(
    function : boolean
    begin
      Result := bDo;
    end,
    procedure
    begin
      bDone := True;
    end
  );
  Sleep(10);
  if bDone then
  begin
    Assert.Fail('Did not wait until told to continue.');
    exit;
  end;
  bDo := True;
  Sleep(10);
  Assert.AreEqual(True, bDone);
end;

procedure TestTAsync.Setup;
begin
end;

procedure TestTAsync.TearDown;
begin
end;

procedure TestTAsync.AfterDo;
var
  bDone : boolean;
begin
  bDone := False;
  Async.AfterDo(100,
    procedure
    begin
      bDone := True;
    end
  );
  Sleep(210);
  Assert.AreEqual(True, bDone);
end;

procedure TestTAsync.DoEvery;
var
  iCnt : integer;
begin
  iCnt := 1;
  Async.DoEvery(10,
    function : boolean
    begin
      inc(iCnt);
      if iCnt >= 10 then
        Result := False
      else
        Result := True;
    end
  );
  Sleep(1000);
  Assert.AreEqual(10, iCnt);
end;

procedure TestTAsync.DoLater;
var
  bDone : boolean;
begin
  bDone := False;
  Async.DoLater(
    procedure
    begin
      bDone := True;
    end
  );
  Sleep(100);
  Assert.AreEqual(True, bDone);
end;

procedure TestTAsync.EarlyFree;
var
  async : TAsync;
  iCnt : integer;
begin
  try
    iCnt := 0;
    async := TAsync.Create;
    try
      async.DoEvery(10,
        function : boolean
        begin
          TInterlocked.Increment(iCnt);
        end
      );
      sleep(100);
    finally
      async.Free;
    end;
    if iCnt > 0 then
      Assert.Pass
    else
      Assert.Fail('DoEvery Did not run');
  except
    on E : Exception do
      Assert.Fail(E.Message);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TestTAsync);
end.

