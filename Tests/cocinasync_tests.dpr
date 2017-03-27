program cocinasync_tests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}{$STRONGLINKTYPES ON}
uses
  ScaleMM2,
  SysUtils,
  Classes,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF }
  cocinasync.global,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  cocinasync.tests.jobs in 'cocinasync.tests.jobs.pas',
  cocinasync.tests.async in 'cocinasync.tests.async.pas',
  cocinasync.tests.collections in 'cocinasync.tests.collections.pas';

var
  runner : ITestRunner;
  results : IRunResults;
  logger : ITestLogger;
  nunitLogger : ITestLogger;
  CS : TConsole;
  bFinished : boolean;
  Ex : Exception;
begin
  ReportMemoryLeaksOnShutdown := True;
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  exit;
{$ENDIF}
  CS := TConsole.Create;
  try
    try
      //Check command line options, will exit if invalid
      TDUnitX.CheckCommandLine;
      bFinished := False;
      Ex := nil;
      TThread.CreateAnonymousThread(
        procedure
        begin
          try
            try
              //Create the test runner
              runner := TDUnitX.CreateRunner;
              //Tell the runner to use RTTI to find Fixtures
              runner.UseRTTI := True;
              //tell the runner how we will log things
              //Log to the console window
              logger := TDUnitXConsoleLogger.Create(true);
              runner.AddLogger(logger);
              //Generate an NUnit compatible XML File
              nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
              runner.AddLogger(nunitLogger);
              runner.FailsOnNoAsserts := False; //When true, Assertions must be made during tests;

              //Run tests
              results := runner.Execute;
              if not results.AllPassed then
                System.ExitCode := EXIT_ERRORS;

            except
              on E: Exception do
                Ex := E;
            end;
          finally
            bFinished := True;
          end;
        end
      ).Start;

      repeat
        CS.CheckSynchronize(1000);
      until bFinished;

      if Assigned(Ex) then
        raise Ex;

      {$IFNDEF CI}
      //We don't want this happening when running under CI.
      if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
      begin
        System.Write('Done.. press <Enter> key to quit.');
        System.Readln;
      end;
      {$ENDIF}

    except
      on E: Exception do
        System.Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    CS.free;
  end;
end.
