unit cocinasync.tests.collections;

interface

uses
  DUnitX.TestFramework, cocinasync.collections;

type

  [TestFixture]
  TestCollections = class(TObject)
  strict private
  private
    FStack: TStack<TObject>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    [TestCase('TestStack-0','0, 1000,0')]
//    [TestCase('TestStack-0-s','0, 20,0')]
    [TestCase('TestStack-1','1, 1000,0')]
    [TestCase('TestStack-2.1','2, 1000,1')]
    [TestCase('TestStack-8','8, 1000,0')]
    [TestCase('TestStack-8.5','8, 1000,5')]
    [TestCase('TestStack-10','10, 10000,1')]
    procedure TestStack(ThreadCount, ItemsCount, Delay : Integer);
  end;

implementation

uses System.SysUtils, System.Classes, System.SyncObjs, System.Threading;

procedure TestCollections.Setup;
begin
  FStack := TStack<TObject>.Create;
end;

procedure TestCollections.TearDown;
begin
  FStack.Free;
end;

type
  TThreadHack = class(TThread)
  end;

procedure TestCollections.TestStack(ThreadCount, ItemsCount, Delay : Integer);
var
  ary : TArray<TThread>;
  iEndCount : integer;
  bFinished: Boolean;
  o: TObject;
  aryErrors : TArray<string>;
  i: Integer;
begin
  setlength(ary, ThreadCount);
  setLength(aryErrors, ThreadCount);
  iEndCount := 0;
  System.Threading.TParallel.&For(1,ThreadCount,
    procedure(i : integer)
    begin
      ary[i-1] := TThread.CreateAnonymousThread(
        procedure
        var
          obj : TObject;
          j : integer;
        begin
          try
            try
              for j := 1 to ItemsCount do
              begin
                obj := TObject.Create;
                FStack.Push(obj);
                TInterlocked.Increment(iEndCount);
              end;
              for j := 1 to ItemsCount do
              begin
                obj := FStack.Pop;
                if Assigned(obj) then
                begin
                  TInterlocked.Decrement(iEndCount);
                  obj.Free;
                end
              end;
              aryErrors[i-1] := '';
            except
              on E: Exception do
                aryErrors[i-1] := E.Message;
            end;
          finally
            TThreadHack(TThread.Current).FreeOnTerminate := False;
            TThreadHack(TThread.Current).Terminate;
          end;
        end
      );
    end
  );

  for i := 1 to ItemsCount do
  begin
    FStack.Push(TObject.Create);
    inc(iEndCount);
  end;

  for i := 0 to ThreadCount-1 do
  begin
    ary[i].Start;
    sleep(Delay);
  end;
  repeat
    bFinished := True;
    for i := ThreadCount-1 downto 0 do
    begin
      if not TThreadHack(ary[i]).Terminated then
      begin
        bFinished := False;
        break;
      end;
    end;
    sleep(10);
  until bFinished;

  for i := 0 to ThreadCount-1 do
    ary[i].Free;
  SetLength(ary,0);

  for i := 1 to ItemsCount do
  begin
    o := FStack.Pop;
    if Assigned(o) then
    begin
      dec(iEndCount);
      o.Free;
    end;
  end;

  for i := 0 to ThreadCount-1 do
    if aryErrors[i] <> '' then
      Assert.Fail('Failuer in thread: '+aryErrors[i]);

  if iEndCount = 0 then
    Assert.Pass
  else
    Assert.Fail('Left '+iEndCount.ToString+' objects in the stack');

end;

initialization
  TDUnitX.RegisterTestFixture(TestCollections);
end.
