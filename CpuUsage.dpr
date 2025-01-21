program CpuUsage;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Diagnostics,
  System.SysUtils,
  CuUnit.CpuUsageThread in 'CuUnit.CpuUsageThread.pas';

const
  UPDATE_INTERVAL: Integer = 1000;
var
  LCpuUsage: TCpuUsage;
  LWatch: TStopwatch;
begin
  var LCurrentCpuUsage: Double := 0.00;
  var LPreviousCpuUsage : Double := 0.00;
  var LUpdateCounter: Integer := 0;

  try
    LWatch := TStopwatch.StartNew;

    LCpuUsage := TCpuUsage.Create(UPDATE_INTERVAL);
    try

      while True do
      begin
        LCurrentCpuUsage := LCpuUsage.TotalCpuUsage;

        if (Abs(LCurrentCpuUsage - LPreviousCpuUsage) > 0.01) or (LWatch.Elapsed.TotalMilliseconds >= UPDATE_INTERVAL) then
        begin
          WriteLn('CPU USage: ' + FormatFloat('0.00', LCurrentCpuUsage) + '%');
          LPreviousCpuUsage := LCurrentCpuUsage;

          Inc(LUpdateCounter);

          if LUpdateCounter > 45 then
            Break;

          LWatch := TStopwatch.StartNew;
        end;

        Sleep(UPDATE_INTERVAL div 5);
      end;
    finally
      LCpuUsage.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
