unit cocinasync.profiler;

interface

uses System.SysUtils, System.Classes, System.Diagnostics;

type
  TLogProc = reference to procedure(const msg : string);
  TTestProc = reference to procedure(CLog, DLog, TLog : TStrings);

  TProfiles = class
  strict private
    class procedure SetupTest(const LogHeader : string; const Log : TLogProc; const TestProc : TTestProc);
    class procedure DoHashIteration(RunCnt, IterationSize, ThreadCount: Integer; const Log : TLogProc); static;
    class procedure DoStackIteration(RunCnt, IterationSize, ThreadCount: Integer; const Log : TLogProc); static;
    class procedure DoQueueIteration(RunCnt, IterationSize, ThreadCount: Integer; const Log : TLogProc); static;
  public
    class procedure DoTest(RunCount : Integer; const Log : TLogProc);
  end;

implementation

uses cocinasync.collections, System.Generics.Collections, System.Threading,
  System.SyncObjs, cocinasync.async, System.Math;

{ TProfiles }

class procedure TProfiles.DoTest(RunCount : Integer; const Log: TLogProc);
  procedure FullTestForThread(RunCount : Integer; iCnt: Integer; const Log: TLogProc);
  begin
    Log(iCnt.ToString + ' Thread Test - Avg of '+RunCount.ToString+' runs');
    Log('------------------');
    DoQueueIteration(RunCount, 1, iCnt, Log);
    DoQueueIteration(RunCount, 100, iCnt, Log);
    DoQueueIteration(RunCount, 250, iCnt, Log);
    DoQueueIteration(RunCount, 500, iCnt, Log);
    DoQueueIteration(RunCount, 750, iCnt, Log);
    DoQueueIteration(RunCount, 1000, iCnt, Log);
    DoQueueIteration(RunCount, 10000, iCnt, Log);
    DoStackIteration(RunCount, 1, iCnt, Log);
    DoStackIteration(RunCount, 100, iCnt, Log);
    DoStackIteration(RunCount, 250, iCnt, Log);
    DoStackIteration(RunCount, 500, iCnt, Log);
    DoStackIteration(RunCount, 750, iCnt, Log);
    DoStackIteration(RunCount, 1000, iCnt, Log);
    DoStackIteration(RunCount, 10000, iCnt, Log);
//    DoStackIteration(RunCount, 100000, iCnt, Log);
    DoHashIteration(RunCount, 1, iCnt, Log);
    DoHashIteration(RunCount, 100, iCnt, Log);
    DoHashIteration(RunCount, 1000, iCnt, Log);
    DoHashIteration(RunCount, 10000, iCnt, Log);
//    DoHashIteration(RunCount, 100000, iCnt, Log);
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
  SetupTest('Strings'#9'Ints'#9'Intfs'#9'Lkps'#9'Empty'#9'Max'#9'Avg',
    Log,
    procedure(CLog, DLog, TLog : TStrings)
    var
      DepthS : THash<String, Integer>.TDepth;
      DepthI : THash<Integer, Integer>.TDepth;
      DepthO : THash<IInterface, Integer>.TDepth;
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
      chs := THash<String,Integer>.Create((IterationSize * ThreadCount)+1);
      chi := THash<Integer,Integer>.Create((IterationSize * ThreadCount)+1);
      cho := THash<IInterface,Integer>.Create((IterationSize * ThreadCount)+1);
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

        DepthS := chs.DebugDepth;
        DepthI := chi.DebugDepth;
        DepthO := cho.DebugDepth;

        DLog.Add((iTimeDHS div RunCnt).ToString);
        DLog.Add((iTimeDHI div RunCnt).ToString);
        DLog.Add((iTimeDHO div RunCnt).ToString);
        DLog.Add((iTimeDHL div RunCnt).ToString);
        CLog.Add((iTimeCHS div RunCnt).ToString);
        CLog.Add((iTimeCHI div RunCnt).ToString);
        CLog.Add((iTimeCHO div RunCnt).ToString);
        CLog.Add((iTimeCHL div RunCnt).ToString);
        CLog.Add((Round((DepthS.EmptyCnt+DepthI.EmptyCnt+DepthO.EmptyCnt) / (DepthS.Size*3)*10000)/100).ToString);
        CLog.Add((Max(Max(DepthS.MaxDepth, DepthI.MaxDepth), DepthO.MaxDepth) ).ToString);
        CLog.Add((Round((DepthS.Average+DepthI.Average+DepthO.Average) / (DepthS.Size*3)*10000)/100).ToString);
        if iTimeDHS > 0 then
          TLog.Add((Round(((iTimeDHS - iTimeCHS) / iTimeDHS)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHI > 0 then
          TLog.Add((Round(((iTimeDHI - iTimeCHI) / iTimeDHI)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHO > 0 then
          TLog.Add((Round(((iTimeDHO - iTimeCHO) / iTimeDHO)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHL > 0 then
          TLog.Add((Round(((iTimeDHL - iTimeCHL) / iTimeDHL)*10000) / 100).ToString)
        else
          TLog.Add('Err');


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

class procedure TProfiles.DoQueueIteration(RunCnt, IterationSize,
  ThreadCount: Integer; const Log: TLogProc);
begin
  Log('Queue '+IterationSize.ToString+' Each');
  SetupTest('Strings'#9'Ints'#9'Objs'#9'Dequeue',
    Log,
    procedure(CLog, DLog, TLog : TStrings)
    var
      chs : cocinasync.collections.TQueue<String>;
      chi : cocinasync.collections.TQueue<Integer>;
      cho : cocinasync.collections.TQueue<TObject>;
      dhs : system.generics.collections.TQueue<String>;
      dhi : system.generics.collections.TQueue<Integer>;
      dho : system.generics.collections.TQueue<TObject>;
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
      chs := cocinasync.collections.TQueue<String>.Create((IterationSize*RunCnt*ThreadCount)+100);
      chi := cocinasync.collections.TQueue<Integer>.Create((IterationSize*RunCnt*ThreadCount)+100);
      cho := cocinasync.collections.TQueue<TObject>.Create((IterationSize*RunCnt*ThreadCount)+100);
      dhs := system.generics.collections.TQueue<String>.Create;
      dhi := system.generics.collections.TQueue<Integer>.Create;
      dho := system.generics.collections.TQueue<TObject>.Create;
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
                    dhs.Enqueue(TThread.Current.ThreadID.ToString+'~'+i.ToString);
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
                  chs.Enqueue(TThread.Current.ThreadID.ToString+'~'+i.ToString);
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
                    dhi.Enqueue(i);
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
                  chi.Enqueue(i);
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
                    dho.Enqueue(dho);
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
                  cho.Enqueue(cho);
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
                    dhs.Dequeue;
                    dhi.Dequeue;
                    dho.Dequeue;
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
                  chs.Dequeue;
                  chi.Dequeue;
                  cho.Dequeue;
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

        DLog.Add((Round(iTimeDHS / RunCnt * 100) / 100).ToString);
        DLog.Add((Round(iTimeDHI / RunCnt * 100) / 100).ToString);
        DLog.Add((Round(iTimeDHO / RunCnt * 100) / 100).ToString);
        DLog.Add((Round(iTimeDHL / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHS / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHI / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHO / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHL / RunCnt * 100) / 100).ToString);
        if iTimeDHS > 0 then
          TLog.Add((Round(((iTimeDHS - iTimeCHS) / iTimeDHS)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHI > 0 then
          TLog.Add((Round(((iTimeDHI - iTimeCHI) / iTimeDHI)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHO > 0 then
          TLog.Add((Round(((iTimeDHO - iTimeCHO) / iTimeDHO)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHL > 0 then
          TLog.Add((Round(((iTimeDHL - iTimeCHL) / iTimeDHL)*10000) / 100).ToString)
        else
          TLog.Add('Err');
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
  SetupTest('Strings'#9'Ints'#9'Objs'#9'Pops',
    Log,
    procedure(CLog, DLog, TLog : TStrings)
    var
      chs : cocinasync.collections.TStack<String>;
      chi : cocinasync.collections.TStack<Integer>;
      cho : cocinasync.collections.TStack<TObject>;
      dhs : system.generics.collections.TStack<String>;
      dhi : system.generics.collections.TStack<Integer>;
      dho : system.generics.collections.TStack<TObject>;
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
      cho := cocinasync.collections.TStack<TObject>.Create;
      dhs := system.generics.collections.TStack<String>.Create;
      dhi := system.generics.collections.TStack<Integer>.Create;
      dho := system.generics.collections.TStack<TObject>.Create;
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
                    dho.Push(dho);
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
                  cho.Push(cho);
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

        DLog.Add((Round(iTimeDHS / RunCnt * 100) / 100).ToString);
        DLog.Add((Round(iTimeDHI / RunCnt * 100) / 100).ToString);
        DLog.Add((Round(iTimeDHO / RunCnt * 100) / 100).ToString);
        DLog.Add((Round(iTimeDHL / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHS / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHI / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHO / RunCnt * 100) / 100).ToString);
        CLog.Add((Round(iTimeCHL / RunCnt * 100) / 100).ToString);
        if iTimeDHS > 0 then
          TLog.Add((Round(((iTimeDHS - iTimeCHS) / iTimeDHS)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHI > 0 then
          TLog.Add((Round(((iTimeDHI - iTimeCHI) / iTimeDHI)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHO > 0 then
          TLog.Add((Round(((iTimeDHO - iTimeCHO) / iTimeDHO)*10000) / 100).ToString)
        else
          TLog.Add('Err');
        if iTimeDHL > 0 then
          TLog.Add((Round(((iTimeDHL - iTimeCHL) / iTimeDHL)*10000) / 100).ToString)
        else
          TLog.Add('Err');
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
  procedure RightAlignAll(sl : TStrings);
  var
    i: Integer;
    s : string;
  begin
    for i := 0 to sl.Count-1 do
    begin
      s := sl[i];
      while length(s) < 10 do
        s := ' '+s;
      sl[i] := s;

    end;
  end;
var
  slH, slC, slD, slT: TStringList;
begin
  slH := TStringList.Create;
  slC := TStringList.Create;
  slD := TStringList.Create;
  slT := TStringList.Create;
  try
    TestProc(slC, slD, slT);
    slH.DelimitedText := LogHeader;
    while slH.Count < slC.Count do
      slH.Insert(0,'');
    slH.Insert(0,'');
    slC.Insert(0,'CocinA');
    slD.Insert(0,'Delphi');
    slT.Insert(0,'%Imprv');
    RightAlignAll(slH);
    RightAlignAll(slC);
    RightAlignAll(slD);
    RightAlignAll(slT);
    log(slH.Text.Replace(#13#10,''));
    log(slC.Text.Replace(#13#10,''));
    log(slD.Text.Replace(#13#10,''));
    log(slT.Text.Replace(#13#10,''));
    log('');
  finally
    slH.Free;
    slC.Free;
    slD.Free;
    slT.Free;
  end;
end;

end.
