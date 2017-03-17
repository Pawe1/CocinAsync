unit cocinasync.profiler;

interface

uses System.SysUtils, System.Classes, System.Diagnostics;

type
  TLogProc = reference to procedure(const msg : string);
  TTestProc = reference to procedure(CLog, DLog : TStrings);

  TProfiles = class
  strict private
    class procedure SetupTest(const LogHeader : string; const Log : TLogProc; const TestProc : TTestProc);
    class procedure DoHashIteration(RunCnt, IterationSize, ThreadCount: Integer; const Log : TLogProc); static;
    class procedure DoStackIteration(RunCnt, IterationSize, ThreadCount: Integer; const Log : TLogProc); static;
  public
    class procedure DoTest(RunCount : Integer; const Log : TLogProc);
  end;

implementation

uses cocinasync.collections, System.Generics.Collections, System.Threading,
  System.SyncObjs, cocinasync.async;

{ TProfiles }

class procedure TProfiles.DoTest(RunCount : Integer; const Log: TLogProc);
  procedure FullTestForThread(RunCount : Integer; iCnt: Integer; const Log: TLogProc);
  begin
    Log(iCnt.ToString + ' Thread Test - Avg of '+RunCount.ToString+' runs');
    Log('------------------');
    DoHashIteration(RunCount, 1, iCnt, Log);
    DoHashIteration(RunCount, 100, iCnt, Log);
    DoHashIteration(RunCount, 1000, iCnt, Log);
    DoHashIteration(RunCount, 10000, iCnt, Log);
    DoHashIteration(RunCount, 100000, iCnt, Log);
    DoStackIteration(RunCount, 1, iCnt, Log);
    DoStackIteration(RunCount, 100, iCnt, Log);
    DoStackIteration(RunCount, 1000, iCnt, Log);
    DoStackIteration(RunCount, 10000, iCnt, Log);
    DoStackIteration(RunCount, 100000, iCnt, Log);
    Log('------------------');
    Log('');
    Log('');
  end;
var
  iCnt : integer;
begin
  FullTestForThread(RunCount, 1,Log);
  iCnt := 2;
  while iCnt < 10 do
  begin
    FullTestForThread(RunCount, iCnt, Log);
    inc(iCnt,2);
  end;
end;

class procedure TProfiles.DoHashIteration(RunCnt, IterationSize : integer; ThreadCount : Integer; const Log : TLogProc);
begin
  Log('Hash '+IterationSize.ToString+' Each');
  SetupTest('Hash'#9'Strings'#9'Ints'#9'Intfs'#9'Lkps',
    Log,
    procedure(CLog, DLog : TStrings)
    var
      chs : THash<String,Integer>;
      chi : THash<Integer,Integer>;
      cho : THash<IInterface,Integer>;
      dhs : TDictionary<String, Integer>;
      dhi : TDictionary<Integer, Integer>;
      dho : TDictionary<IInterface, Integer>;
      dhcs : TCriticalSection;
      p : TParallel.TLoopResult;
      iThreadsComplete : integer;
      iTimeDHS, iTimeDHI, iTimeDHO, iTimeDHL : Int64;
      iTimeCHS, iTimeCHI, iTimeCHO, iTimeCHL : Int64;
      i: Integer;
    begin
      iThreadsComplete := 0;
      iTimeDHS := 0;
      iTimeDHI := 0;
      iTimeDHO := 0;
      iTimeDHL := 0;
      iTimeCHS := 0;
      iTimeCHI := 0;
      iTimeCHO := 0;
      iTimeCHL := 0;
      chs := THash<String,Integer>.Create;
      chi := THash<Integer,Integer>.Create;
      cho := THash<IInterface,Integer>.Create;
      dhs := TDictionary<String, Integer>.Create;
      dhi := TDictionary<Integer, Integer>.Create;
      dho := TDictionary<IInterface, Integer>.Create;
      dhcs := TCriticalSection.Create;
      try
        for i := 1 to RunCnt do
        begin
          p := TParallel.For(1,ThreadCount,
            procedure(idx : integer)
            var
              sw : TStopWatch;
              i: Integer;
            begin
              try
                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dhs.AddOrSetValue(TThread.Current.ThreadID.ToString+'~'+i.ToString, i);
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHS, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                  chs[TThread.Current.ThreadID.ToString+'~'+i.ToString] := i;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHS, sw.ElapsedTicks);
                  end
                );


                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dhi.AddOrSetValue(i, i);
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHI, sw.ElapsedTicks);
                  end
                );


                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                  chi[i] := i;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHI, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dho.AddOrSetValue(TInterfacedObject.Create, i);
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHO, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                  cho[TInterfacedObject.Create] := i;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHO, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dhi[i] := dhs[TThread.Current.ThreadID.ToString+'~'+i.ToString]+dhi[i];
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHL, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                  chi[i] := chs[TThread.Current.ThreadID.ToString+'~'+i.ToString]+chi[i];
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHL, sw.ElapsedTicks);
                  end
                );
              finally
                TInterlocked.Increment(iThreadsComplete);
              end;
            end
          );

          while not p.Completed do
            sleep(10);
          while iThreadsComplete < ThreadCount do
            sleep(10);
        end;

        DLog.Add((iTimeDHS div RunCnt).ToString);
        DLog.Add((iTimeDHI div RunCnt).ToString);
        DLog.Add((iTimeDHO div RunCnt).ToString);
        DLog.Add((iTimeDHL div RunCnt).ToString);
        CLog.Add((iTimeCHS div RunCnt).ToString);
        CLog.Add((iTimeCHI div RunCnt).ToString);
        CLog.Add((iTimeCHO div RunCnt).ToString);
        CLog.Add((iTimeCHL div RunCnt).ToString);

      finally
        chs.Free;
        chi.Free;
        cho.Free;
        dhs.Free;
        dhi.Free;
        dho.Free;
        dhcs.Free;
      end;
    end
  );
end;

class procedure TProfiles.DoStackIteration(RunCnt, IterationSize : integer; ThreadCount : Integer; const Log : TLogProc);
begin
  Log('Stack '+IterationSize.ToString+' Each');
  SetupTest('Stack'#9'Strings'#9'Ints'#9'Intfs'#9'Pops',
    Log,
    procedure(CLog, DLog : TStrings)
    var
      chs : cocinasync.collections.TStack<String>;
      chi : cocinasync.collections.TStack<Integer>;
      cho : cocinasync.collections.TStack<IInterface>;
      dhs : system.generics.collections.TStack<String>;
      dhi : system.generics.collections.TStack<Integer>;
      dho : system.generics.collections.TStack<IInterface>;
      dhcs : TCriticalSection;
      p : TParallel.TLoopResult;
      iThreadsComplete : integer;
      iTimeDHS, iTimeDHI, iTimeDHO, iTimeDHL : Int64;
      iTimeCHS, iTimeCHI, iTimeCHO, iTimeCHL : Int64;
      i: Integer;
    begin
      iThreadsComplete := 0;
      iTimeDHS := 0;
      iTimeDHI := 0;
      iTimeDHO := 0;
      iTimeDHL := 0;
      iTimeCHS := 0;
      iTimeCHI := 0;
      iTimeCHO := 0;
      iTimeCHL := 0;
      chs := cocinasync.collections.TStack<String>.Create;
      chi := cocinasync.collections.TStack<Integer>.Create;
      cho := cocinasync.collections.TStack<IInterface>.Create;
      dhs := system.generics.collections.TStack<String>.Create;
      dhi := system.generics.collections.TStack<Integer>.Create;
      dho := system.generics.collections.TStack<IInterface>.Create;
      dhcs := TCriticalSection.Create;
      try
        for i := 1 to RunCnt do
        begin
          p := TParallel.For(1,ThreadCount,
            procedure(idx : integer)
            var
              sw : TStopWatch;
              i: Integer;
            begin
              try
                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dhs.Push(TThread.Current.ThreadID.ToString+'~'+i.ToString);
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHS, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                  chs.Push(TThread.Current.ThreadID.ToString+'~'+i.ToString);
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHS, sw.ElapsedTicks);
                  end
                );


                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dhi.Push(i);
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHI, sw.ElapsedTicks);
                  end
                );


                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                  chi.Push(i);
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHI, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dho.Push(TInterfacedObject.Create);
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHO, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                  cho.Push(TInterfacedObject.Create);
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHO, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  if ThreadCount > 1 then
                    dhcs.Enter;
                  try
                    dhs.Pop;
                    dhi.Pop;
                    dho.Pop;
                  finally
                    if ThreadCount > 1 then
                      dhcs.Leave;
                  end;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeDHL, sw.ElapsedTicks);
                  end
                );

                sw := TStopwatch.StartNew;
                for i := 1 to IterationSize do
                begin
                  chs.Pop;
                  chi.Pop;
                  cho.Pop;
                end;
                sw.Stop;
                TAsync.SynchronizeIfInThread(
                  procedure
                  begin
                    inc(iTimeCHL, sw.ElapsedTicks);
                  end
                );
              finally
                TInterlocked.Increment(iThreadsComplete);
              end;
            end
          );

          while not p.Completed do
            sleep(10);
          while iThreadsComplete < ThreadCount do
            sleep(10);
        end;

        DLog.Add((iTimeDHS div RunCnt).ToString);
        DLog.Add((iTimeDHI div RunCnt).ToString);
        DLog.Add((iTimeDHO div RunCnt).ToString);
        DLog.Add((iTimeDHL div RunCnt).ToString);
        CLog.Add((iTimeCHS div RunCnt).ToString);
        CLog.Add((iTimeCHI div RunCnt).ToString);
        CLog.Add((iTimeCHO div RunCnt).ToString);
        CLog.Add((iTimeCHL div RunCnt).ToString);

      finally
        chs.Free;
        chi.Free;
        cho.Free;
        dhs.Free;
        dhi.Free;
        dho.Free;
        dhcs.Free;
      end;
    end
  );
end;

class procedure TProfiles.SetupTest(const LogHeader: string; const Log : TLogProc;
  const TestProc: TTestProc);
var
  slC, slD: TStringList;
begin
  slC := TStringList.Create;
  slD := TStringList.Create;
  try
    slC.Delimiter := #9;
    slD.Delimiter := #9;
    TestProc(slC, slD);
    log(LogHeader);
    log('CocinA'#9+slC.DelimitedText);
    log('Delphi'#9+slD.DelimitedText);
    log('');
  finally
    slC.Free;
    slD.Free;
  end;
end;

end.
