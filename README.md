## 🚀 General Deployment Steps

1. **Roster Setup:** Run `01_Create_Table.sql` in SSMS to build the developer registry.
2. **Script Host:** Save `DailyCommitReport.ps1` to `C:\Scripts\` and add your production credentials/tokens.
3. **Automation:** Run `02_Provision_Agent_Job.sql` in SSMS to schedule the 7:00 AM execution.


## 🚀 Deployment Instructions

Follow these steps in order to provision the compliance audit tracking tool:

### 1. Database Schema Configuration
Run the table setup script to create your developer source-of-truth roster.
* **File to execute:** `01_Create_Table.sql` inside SSMS.
* **Database Target:** `DBA_Tools` (or your preferred administrative catalog).

### 2. PowerShell Script Host File
Deploy the engine script to the host server directory.
* **File to move:** `DailyCommitReport.ps1`
* **Target Host Path:** `C:\Scripts\DailyCommitReport.ps1`
* **Security Requirements:** Ensure the Windows domain or local service account executing your *SQL Server Agent* service has explicit **Read & Execute** NTFS file permissions on that folder and script.
* **Environment Variables:** Open the script and populate your production `$pat` (Personal Access Token), Azure `$org`, and corporate SMTP mail settings.

### 3. Automated SQL Server Agent Job Provisioning
Register the daily automation runner.
* **File to execute:** `02_Provision_Agent_Job.sql` inside SSMS.
* **Schedule:** Configured by default to automatically trigger every weekday morning at exactly **7:00 AM**.

---

## Compliance Alert Handling & UI Styling

The reporting engine evaluates developer code submissions against their localized working schedules. If a developer fails to push code within their designated 24-hour lookback window, the reporting script dynamically highlights their row in **bold red text** within the morning email delivery for immediate executive review.