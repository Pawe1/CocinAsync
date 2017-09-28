unit cocinasync.tests.collections;

interface

uses
  DUnitX.TestFramework, cocinasync.collections;

type

  [TestFixture]
  TestCollections = class(TObject)
  strict private
  private
  public
    [Test]
    [TestCase('TestStack-0','0, 1000,0')]
    [TestCase('TestStack-1','1, 1000,0')]
    [TestCase('TestStack-2.1','2, 1000,1')]
    [TestCase('TestStack-8','8, 1000,0')]
    [TestCase('TestStack-8.5','8, 1000,5')]
    [TestCase('TestStack-10','10, 10000,1')]
    // [TestCase('TestStack-100','100, 100000, 0')]
    procedure TestStackThreads(ThreadCount, ItemsCount, Delay : Integer);

    [Test]
    procedure TestHashRemove;

    [Test]
    procedure TestHash;

    [Test]
    procedure TestHashClear;

    [Test]
    procedure TestQueue;

    [Test]
    procedure TestStack;

    [Test]
    [TestCase('TestHash-8','2, 1000, 0')]
    [TestCase('TestHash-8','8, 1000, 1')]
    procedure TestHashThreads(ThreadCount, ItemsCount, Delay : Integer);
  end;

implementation

uses System.SysUtils, System.Classes, System.SyncObjs, System.Threading;

type
  TThreadHack = class(TThread)
  end;

procedure TestCollections.TestHash;
var
  h : THash<integer,integer>;
  hs : THash<integer, string>;
  ho : THash<integer, TObject>;
  s : string;
begin
  h := THash<integer,integer>.Create;
  try
    // set first to a value
    h[1] := 890000;

    // update to another value
    h[1] := 990000;

    try
      h.Add(1, 1000);
      s := 'Did not raise exception when adding key that exists';
    except
      {on e: EKeyExists<integer> do
        s := '';
      else raise;    }
    end;

    if s <> '' then
      Assert.Fail(s);

    // make sure updated value is in the hash
    if h[1] = 990000 then
      s := ''
      else
      s := 'Expected '+(990000).ToString+' found '+h[1].ToString;

    if s <> '' then
      Assert.Fail(s);

    Assert.AreEqual(h.Remove(1), 990000);

    h[2] := 123;
    h[3] := 235;
    h.Visit(
      procedure(const Key : Integer; var Value : Integer; var Delete : Boolean)
      begin
        if Key = 2 then
          Delete := True;
      end
    );
    h.Remove(2);
  finally
    h.Free;
  end;


  hs := THash<integer, string>.Create;
  try
    hs[2] := '990000';

    hs[2] := '890000';

    if hs[2] <> '890000' then
      s := 'Expected 890000 found '+hs[2]
    else
      s := '';
  finally
    hs.Free;
  end;

  ho := THash<integer, TObject>.Create;
  try
    ho[3] := self;
    ho[3] := ho;
    if ho[3] <> ho then
      Assert.Fail('Wrong Object in Hash');
  finally
    ho.Free;
  end;

  Assert.Pass;
end;

procedure TestCollections.TestHashClear;
var
  h : THash<string, string>;
  i : integer;
begin
  h := THash<string, string>.Create;
  try
    for i := 1 to 40 do
      TThread.CreateAnonymousThread(
        procedure
        begin
          h['first'] := 'jason';
          h['last'] := 'smith';
          h.Clear;
        end
      );
      Sleep(100);
      if h.Has['first'] or h.Has['last'] then
        Assert.Fail('Clear did not clear');
  finally
    h.Free;
  end;
end;

procedure TestCollections.TestHashRemove;
var
  h : THash<string, string>;
begin
  h := THash<string, string>.Create;
  try
    h['first'] := 'jason';
    h['last'] := 'smith';
    h.Remove('first');
    h.Remove('last');
    if h.Has['first'] then
      Assert.Fail('has first after removal');
    if h.Has['last'] then
      Assert.Fail('has last after removal');
    Assert.AreEqual(h['first'],'','first is not nil');
    Assert.AreEqual(h['last'],'','last is not nil');
  finally
    h.Free;
  end;
end;

procedure TestCollections.TestHashThreads(ThreadCount, ItemsCount, Delay: Integer);
var
  i : integer;
  ary : TArray<TThread>;
  aryErrors : TArray<string>;
  h : THash<integer,integer>;
  bFinished : boolean;
begin
  h := THash<integer,integer>.Create(ThreadCount*ItemsCount);
  try
    SetLength(ary,ThreadCount);
    SetLength(aryErrors,ThreadCount);
    TParallel.&For(1,ThreadCount,
      procedure(idx : integer)
      begin
        ary[idx-1] := TThread.CreateAnonymousThread(
          procedure
          var
            i: Integer;
          begin
            try
              try
                // update to another value
                for i := 1 to ItemsCount do
                begin
                  h[i] := TThread.Current.ThreadID
                end;
                for i := 1 to ItemsCount do
                begin
                  if h[i] <> TThread.Current.ThreadID then
                    h[i] := TThread.Current.ThreadID
                end;
                aryErrors[idx-1] := '';
              except
                on E: Exception do
                  aryErrors[idx-1] := E.Message;
              end;
            finally
              TThreadHack(TThread.Current).FreeOnTerminate := False;
              TThreadHack(TThread.Current).Terminate;
            end;
          end
        );
      end
    );

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
  finally
    h.Free;
  end;

  for i := 0 to length(aryErrors)-1 do
    if aryErrors[i] <> '' then
      Assert.Fail(aryErrors[i]);

  Assert.Pass;
end;

procedure TestCollections.TestQueue;
var
  queue : TQueue<integer>;
  i: Integer;
begin
  queue := TQueue<integer>.Create(101);
  try
    for i := 1 to 100 do
      queue.Enqueue(i);

    for i := 1 to 100 do
      if queue.dequeue <> i then
        Assert.Fail('Expected '+i.ToString);

    Assert.Pass;
  finally
    queue.Free;
  end;
end;

procedure TestCollections.TestStack;
var
  stack : TStack<integer>;
  i: Integer;
begin
  stack := TStack<integer>.Create;
  try
    for i := 1 to 100 do
      stack.Push(i);

    for i := 100 downto 1 do
      if stack.pop <> i then
        Assert.Fail('Expected '+i.ToString);

    Assert.Pass;
  finally
    stack.Free;
  end;
end;

procedure TestCollections.TestStackThreads(ThreadCount, ItemsCount, Delay : Integer);
var
  ary : TArray<TThread>;
  iEndCount : integer;
  bFinished: Boolean;
  o: TObject;
  aryErrors : TArray<string>;
  i: Integer;
  Stack : TStack<TObject>;
begin
  Stack := TStack<TObject>.Create;
  try
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
                try
                  for j := 1 to ItemsCount do
                  begin
                    obj := TObject.Create;
                    Stack.Push(obj);
                    TInterlocked.Increment(iEndCount);
                  end;
                except
                  on e: exception do
                    raise Exception.Create(e.Message+' push j='+j.ToString+' of '+ItemsCount.ToString);
                end;
                try
                  for j := ItemsCount downto 1 do
                  begin
                    obj := Stack.Pop;
                    if Assigned(obj) then
                    begin
                      TInterlocked.Decrement(iEndCount);
                      obj.Free;
                    end
                  end;
                except
                  on e: exception do
                    raise Exception.Create(e.Message+' pop j='+j.ToString+' of '+ItemsCount.ToString);
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
      Stack.Push(TObject.Create);
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
      o := Stack.Pop;
      if Assigned(o) then
      begin
        dec(iEndCount);
        o.Free;
      end;
    end;

    for i := 0 to ThreadCount-1 do
      if aryErrors[i] <> '' then
        Assert.Fail('Failure in thread: '+aryErrors[i]);

    if iEndCount = 0 then
      Assert.Pass
    else
      Assert.Fail('Left '+iEndCount.ToString+' objects in the stack');
  finally
    Stack.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TestCollections);
end.
