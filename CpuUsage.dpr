program CpuUsage;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Diagnostics,
  System.SysUtils,
  CuUnit.CpuUsageThread in 'CuUnit.CpuUsageThread.pas';

var
  LCpuUsage: TCpuUsage;
  LWatch: TStopwatch;
begin
  try
    LWatch := TStopwatch.StartNew;

    LCpuUsage := TCpuUsage.Create(5000);
    try
      while LWatch.Elapsed.TotalSeconds < 180 do
      begin
        Sleep(1000);

        WriteLn('CPU USage: ' + FormatFloat('0.00', LCpuUsage.TotalCpuUsage) + '%');
      end;
    finally
      LCpuUsage.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
