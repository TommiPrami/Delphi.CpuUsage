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
    constructor Create(CreateSuspended: Boolean); reintroduce;  overload;
    constructor Create(const AUpdaterInterval: Integer = DEFAULT_UPDATE_INTERVAL); overload;
    destructor Destroy; override;

    property TotalCpuUsage: Double read GetTotalCpuUsage;
  end;

implementation

uses
  System.Math;

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
  FCriticalSection := TCriticalSection.Create;
  FUpdaterIntervalMSec := AUpdaterInterval;
  FEvent := TSimpleEvent.Create;

  // One call needed to initialize
  CalculateTotalCpuUsage;

  Lock;
  try
    FTotalCpuUsage := CalculateTotalCpuUsage;
  finally
    Unlock;
  end;

  inherited Create(False);
end;

constructor TCpuUsage.Create(CreateSuspended: Boolean);
begin
  Create(DEFAULT_UPDATE_INTERVAL);
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

      FEvent.ResetEvent;
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
  Terminate;

  FEvent.SetEvent;

  WaitFor;
end;

procedure TCpuUsage.Unlock;
begin
  FCriticalSection.Release;
end;

end.
