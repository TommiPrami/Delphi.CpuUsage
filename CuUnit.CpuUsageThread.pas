unit CuUnit.CpuUsageThread;

interface

uses
  Winapi.Windows, System.Classes, System.SyncObjs;

const
  DEFAULT_UPDATE_INTERVAL = 1000;

type
  TCpuUsage = class(TThread)
  strict private
    FCriticalSection: TCriticalSection;
    FEvent: TSimpleEvent;
    FLastIdleTime: Int64;
    FLastKernelTime: Int64;
    FLastUserTime: Int64;
    FTotalCpuUsage: Double;
    FUpdaterIntervalMSec: Integer;
    function FileTimeToInt64(const FileTime: TFileTime): Int64;
    function GetTotalCpuUsage: Double;
  protected
    function CalculateTotalCpuUsage: Double;
    procedure Execute; override;
    procedure Lock;
    procedure Unlock;
    procedure TerminateAndWaitFor;
  public
    constructor Create(const AUpdaterInterval: Integer = DEFAULT_UPDATE_INTERVAL); reintroduce;
    destructor Destroy; override;

    property TotalCpuUsage: Double read GetTotalCpuUsage;
  end;

implementation

uses
  System.SysUtils;

{ TCpuUsage }

function TCpuUsage.CalculateTotalCpuUsage: Double;
var
  LIdleTime, LKernelTime, LUserTime: TFileTime;
  LIdleDiff, LKernelDiff, LUserDiff, LTotalCpuTime: Int64;
begin
  if Winapi.Windows.GetSystemTimes(LIdleTime, LKernelTime, LUserTime) then
  begin
    LIdleDiff := FileTimeToInt64(LIdleTime) - FLastIdleTime;
    LKernelDiff := FileTimeToInt64(LKernelTime) - FLastKernelTime;
    LUserDiff := FileTimeToInt64(LUserTime) - FLastUserTime;

    LTotalCpuTime := LKernelDiff + LUserDiff;

    FLastIdleTime := FileTimeToInt64(LIdleTime);
    FLastKernelTime := FileTimeToInt64(LKernelTime);
    FLastUserTime := FileTimeToInt64(LUserTime);

    if LTotalCpuTime > 0 then
      Result := 100.0 - ((LIdleDiff * 100.0) / LTotalCpuTime)
    else
      Result := 0.00;
  end
  else
    Result := 0.00;
end;

constructor TCpuUsage.Create(const AUpdaterInterval: Integer);
begin
  if AUpdaterInterval <= 0 then
    raise EArgumentOutOfRangeException.CreateFmt('Updater interval must be positive, got %d', [AUpdaterInterval]);

  FCriticalSection := TCriticalSection.Create;
  FUpdaterIntervalMSec := AUpdaterInterval;
  FEvent := TSimpleEvent.Create;

  // Seed the baseline times only; a delta sampled over the few microseconds
  // since seeding would be meaningless, so the first real value is calculated
  // by the thread after one full interval
  CalculateTotalCpuUsage;

  inherited Create(False);
end;

destructor TCpuUsage.Destroy;
begin
  TerminateAndWaitFor;

  FCriticalSection.Free;
  FEvent.Free;

  inherited Destroy;
end;

procedure TCpuUsage.Execute;
begin
  NameThreadForDebugging('TCpuUsage');

  while not Terminated do
  begin
    FEvent.WaitFor(FUpdaterIntervalMSec);

    if not Terminated then
    begin
      Lock;
      try
        FTotalCpuUsage := CalculateTotalCpuUsage;
      finally
        Unlock;
      end;
    end;
  end;
end;

function TCpuUsage.FileTimeToInt64(const FileTime: TFileTime): Int64;
begin
  Result := Int64(FileTime.dwHighDateTime) shl 32 or FileTime.dwLowDateTime;
end;

function TCpuUsage.GetTotalCpuUsage: Double;
begin
  Lock;
  try
    Result := FTotalCpuUsage;
  finally
    Unlock;
  end;
end;

procedure TCpuUsage.Lock;
begin
  FCriticalSection.Acquire;
end;

procedure TCpuUsage.TerminateAndWaitFor;
begin
  // If the constructor raised before the thread was created, there is nothing
  // to wake up or wait for
  if ThreadID = 0 then
    Exit;

  Terminate;

  FEvent.SetEvent;

  WaitFor;
end;

procedure TCpuUsage.Unlock;
begin
  FCriticalSection.Release;
end;

end.
