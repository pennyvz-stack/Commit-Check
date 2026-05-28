USE [msdb];
GO

-- 1. Create the SQL Agent Job Container
DECLARE @JobId BINARY(16);
EXEC dbo.sp_add_job 
    @job_name = N'Daily Developer Commit Audit', 
    @enabled = 1, 
    @description = N'Queries Azure DevOps API, handles US time zones, and highlights non-compliance in red.',
    @job_id = @JobId OUTPUT;

-- 2. Add Step 1: Call the PowerShell Script
-- NOTE: Modify the path below to point to where you saved the script from Step 1
EXEC dbo.sp_add_jobstep 
    @job_id = @JobId, 
    @step_name = N'Execute Timezone Aware PowerShell Report', 
    @subsystem = N'PowerShell', 
    @command = N'powershell.exe -File "C:\Scripts\DailyCommitReport.ps1"', 
    @retry_attempts = 1, 
    @retry_interval = 5;

-- 3. Create the 7:00 AM Daily Schedule
DECLARE @ScheduleId INT;
EXEC dbo.sp_add_schedule 
    @schedule_name = N'Daily_5AM_Weekday_Schedule', 
    @freq_type = 4,          -- Daily
    @freq_interval = 1,      -- Every day
    @active_start_time = 050000, -- 05:00:00 AM
    @schedule_id = @ScheduleId OUTPUT;

-- 4. Attach Schedule to Job
EXEC dbo.sp_attach_schedule 
    @job_id = @JobId, 
    @schedule_id = @ScheduleId;

-- 5. Target the Local SQL Server Instance
EXEC dbo.sp_add_jobserver 
    @job_id = @JobId, 
    @server_name = N'(local)';
GO