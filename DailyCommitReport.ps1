

# ---- CONFIG ----
$org       = "penny"
$project   = "MyProject"
$repoId    = "940a2d97-cb98-4c6f-b4a9-8329cac96ee5"
$pat       = "<YOUR PAT HERE>"

# SMTP Mail Settings (Local Gmail Testing)
$smtpServer = "smtp.gmail.com"
$smtpPort   = 587
$emailTo    = "pennyvz@gmail.com"
$emailFrom  = "pennyvz@gmail.com" 

# Your Gmail Credentials
$gmailUser  = "pennyvz@gmail.com"
# Paste your 16-character App Password here WITHOUT spaces:
$gmailAppPass = "" 

$SecurePassword = ConvertTo-SecureString $gmailAppPass -AsPlainText -Force
$smtpCredential = New-Object System.Management.Automation.PSCredential($gmailUser, $SecurePassword)

# ---- WEEKEND CHECK ----
$todayLocal = Get-Date
if ($todayLocal.DayOfWeek -in @('Saturday','Sunday')) {
    exit
}

# ---- FEDERAL HOLIDAY FUNCTION ----
function Get-FederalHolidays($year) {
    $holidays = @()
    $holidays += Get-Date "$year-01-01"
    $holidays += Get-Date "$year-06-19"
    $holidays += Get-Date "$year-07-04"
    $holidays += Get-Date "$year-11-11"
    $holidays += Get-Date "$year-12-25"

    function Get-NthWeekday($year, $month, $weekday, $n) {
        $first = Get-Date -Year $year -Month $month -Day 1
        $offset = ([int]$weekday - [int]$first.DayOfWeek + 7) % 7
        return $first.AddDays($offset + 7 * ($n - 1))
    }

    function Get-LastWeekday($year, $month, $weekday) {
        $last = Get-Date -Year $year -Month $month -Day ([DateTime]::DaysInMonth($year, $month))
        $offset = ([int]$last.DayOfWeek - [int]$weekday + 7) % 7
        return $last.AddDays(-$offset)
    }

    $holidays += Get-NthWeekday -year $year -month 1 -weekday ([DayOfWeek]::Monday) -n 3
    $holidays += Get-NthWeekday -year $year -month 2 -weekday ([DayOfWeek]::Monday) -n 3
    $holidays += Get-LastWeekday -year $year -month 5 -weekday ([DayOfWeek]::Monday)
    $holidays += Get-NthWeekday -year $year -month 9 -weekday ([DayOfWeek]::Monday) -n 1
    $holidays += Get-NthWeekday -year $year -month 10 -weekday ([DayOfWeek]::Monday) -n 2
    $holidays += Get-NthWeekday -year $year -month 11 -weekday ([DayOfWeek]::Thursday) -n 4
    return $holidays
}

# ---- HOLIDAY CHECK ----
$year = $todayLocal.Year
$holidays = Get-FederalHolidays $year
if ($todayLocal.Date -in $holidays.Date) {
    exit
}

# ---- DETERMINE DATE RANGE ----
$utcNow = (Get-Date).ToUniversalTime()
if ($utcNow.Hour -lt 17) {
    $targetDate = $utcNow.Date
} else {
    $targetDate = $utcNow.Date.AddDays(-1)
}

$fromDate = $targetDate.ToString("yyyy-MM-ddT00:00:00Z")
$toDate   = $targetDate.ToString("yyyy-MM-ddT23:59:59Z")

# ---- AUTH & GET COMMITS ----
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$url = "https://dev.azure.com/$org/$project/_apis/git/repositories/$repoId/commits?searchCriteria.fromDate=$fromDate&searchCriteria.toDate=$toDate&api-version=7.0"
$response = Invoke-RestMethod -Uri $url -Headers @{Authorization="Basic $base64Auth"}

# ---- TEAM LIST & TIME ZONES (DYNAMIC FROM SQL) ----
$sqlServer = "DESKTOP-LQEABPI\TEST" 
$database  = "DBA_Tools"
$query     = "SELECT DeveloperEmail, TimeZoneID FROM dbo.DeveloperRegistry WHERE IsActive = 1"

# Fetch active roster from your new table
$dbRoster = Invoke-SqlCmd -ServerInstance $sqlServer -Database $database -Query $query

# Convert the SQL results into the formats our loop expects
$developers = $dbRoster.DeveloperEmail
$developerTimeZones = @{}
foreach ($row in $dbRoster) {
    $developerTimeZones[$row.DeveloperEmail] = $row.TimeZoneID
} # <--- FIXED: Added missing closing bracket here

# ---- PROCESS DATA ----
$commitCounts = @{}; $lastCommitLocal = @{}
foreach ($dev in $developers) { $commitCounts[$dev] = 0; $lastCommitLocal[$dev] = $null }

foreach ($commit in $response.value) {
    $email = $commit.author.email
    $timestamp = [DateTime]$commit.author.date
    if ($commitCounts.ContainsKey($email)) {
        $commitCounts[$email]++
        $localTime = [TimeZoneInfo]::ConvertTimeFromUtc($timestamp.ToUniversalTime(), [TimeZoneInfo]::FindSystemTimeZoneById($developerTimeZones[$email]))
        if ($lastCommitLocal[$email] -eq $null -or $localTime -gt $lastCommitLocal[$email]) { $lastCommitLocal[$email] = $localTime }
    }
}

# ---- BUILD HTML TABLE ROWS ----
$reportDate = $targetDate.ToString("yyyy-MM-dd")
$tableRows = ""

# Sort developers dynamically by last commit time
$sortedDevs = $developers | Sort-Object { $lastCommitLocal[$_] } -Descending

foreach ($dev in $sortedDevs) {
    if ($lastCommitLocal[$dev]) {
        $timeStr = $lastCommitLocal[$dev].ToString("yyyy-MM-dd HH:mm:ss")
        $style = ""
    } else {
        # CRITICAL: Applies bold red inline styling if no commits exist
        $timeStr = "<strong>NO COMMITS</strong>"
        $style = " style='color: #cc0000; background-color: #fce8e6;'"
    }

    $tableRows += "<tr$style>
        <td style='padding: 8px; border: 1px solid #ddd;'>$dev</td>
        <td style='padding: 8px; border: 1px solid #ddd;'>$($developerTimeZones[$dev])</td>
        <td style='padding: 8px; border: 1px solid #ddd; text-align: center;'>$($commitCounts[$dev])</td>
        <td style='padding: 8px; border: 1px solid #ddd;'>$timeStr</td>
    </tr>"
}

# Add Total Summary Row
$totalCommits = ($commitCounts.Values | Measure-Object -Sum).Sum
$tableRows += "<tr style='background-color: #f2f2f2; font-weight: bold;'>
    <td style='padding: 8px; border: 1px solid #ddd;'>TOTAL</td>
    <td style='padding: 8px; border: 1px solid #ddd;'>N/A</td>
    <td style='padding: 8px; border: 1px solid #ddd; text-align: center;'>$totalCommits</td>
    <td style='padding: 8px; border: 1px solid #ddd;'>-</td>
</tr>"

# ---- CONSTRUCT FULL EMAIL BODY ----
$emailBody = @"
<html>
<head>
    <style>
        body { font-family: Calibri, Arial, sans-serif; font-size: 14px; color: #333; }
        table { border-collapse: collapse; width: 100%; max-width: 700px; margin-top: 15px; }
        th { background-color: #1f4e78; color: white; padding: 10px; text-align: left; border: 1px solid #ddd; }
    </style>
</head>
<body>
    <p>Good morning,</p>
    <p>Here is the automated Daily Commit Report for <strong>$reportDate</strong> tracking developer activity within their localized end-of-day windows.</p>
    
    <table>
        <thead>
            <tr>
                <th>Developer</th>
                <th>Local Time Zone</th>
                <th style='text-align: center;'>Commits Today</th>
                <th>Last Commit (Local Time)</th>
            </tr>
        </thead>
        <tbody>
            $tableRows
        </tbody>
    </table>
    
    <p style='font-size: 11px; color: #777; margin-top: 25px;'>This is an automated database administration report.</p>
</body>
</html>
"@

# ---- SEND EMAIL (UPDATED WITH SSL & CREDENTIALS) ----
Send-MailMessage -SmtpServer $smtpServer -Port $smtpPort -To $emailTo -From $emailFrom `
    -Subject "Daily Commit Compliance Report - $reportDate" -Body $emailBody -BodyAsHtml -Encoding Utf8 `
    -Credential $smtpCredential -UseSsl