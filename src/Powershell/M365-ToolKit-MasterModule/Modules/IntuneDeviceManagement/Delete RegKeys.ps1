################################
# Delete stale scheduled tasks #
################################
$enrollmentID = ((Get-ScheduledTask | Where-Object { $_.TaskPath -like "*EnterpriseMGMT\*-*" }).Taskpath).Split("\")[4]
$ScheduledTasks = (Get-ScheduledTask | Where-Object { $_.TaskPath -like "*EnterpriseMGMT\$enrollmentID*" })

foreach ($task in $ScheduledTasks) {
    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
}
$ConfirmPreference = "none"

##############################
# Delete stale registry keys #
##############################

$TargetPath1 = "HKLM:\SOFTWARE\Microsoft\Enrollments\" + $enrollmentID
$TargetPath2 = "HKLM:\SOFTWARE\Microsoft\Enrollments\Status\" + $enrollmentID
$TargetPath3 = "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\" + $enrollmentID
$TargetPath4 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\" + $enrollmentID
$TargetPath5 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\" + $enrollmentID
$TargetPath6 = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\" + $enrollmentID
$TargetPath7 = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\" + $enrollmentID
$TargetPath8 = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\" + $enrollmentID
Get-Item -Path $TargetPath1 | Remove-item -Confirm:$false -Force
Get-Item -Path $TargetPath2 | Remove-item -Confirm:$false -Force
Get-Item -Path $TargetPath3 | Remove-item -Confirm:$false -Force
Get-Item -Path $TargetPath4 | Remove-item -Confirm:$false -Force
Get-Item -Path $TargetPath5 | Remove-item -Confirm:$false -Force
Get-Item -Path $TargetPath6 | Remove-item -Confirm:$false -Force
Get-Item -Path $TargetPath7 | Remove-item -Confirm:$false -Force
Get-Item -Path $TargetPath8 | Remove-item -Confirm:$false -Force

#######################################
# Delete stale scheduled tasks folder #
#######################################

Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\EnterpriseMgmt\$enrollmentID" | remove-item -Confirm:$false -Force

############################################
# Delete the Intune enrollment certificate #
############################################
Get-ChildItem -Path cert:\localMachine\my -Recurse | where-object { $_.Issuer -like "*Microsoft Intune MDM Device CA*" } | Remove-Item -Force
Start-Sleep 5

################################
# Start the enrollment process #
################################
Start-Process -FilePath "c:\Windows\system32\deviceenroller.exe" -ArgumentList "/c /AutoEnrollMDM"

#######################
# Unused Script Parts #
#######################
<#
#$enrollmentID = "********-****-****-*****-************"
$ScheduledTasks
$enrollmentID
Get-Item -Path "HKLM:\SOFTWARE\TestKey" | Remove-ItemProperty -name $_.property -Force -Verbose
.\PsExec.exe -s -i -accepteula powershell -ExecutionPolicy Unrestricted -file "c:\install\Delete RegKeys.ps1"
$TargetPath1 = "HKLM:\SOFTWARE\TestKey"
$TargetPath1 = "HKLM:\SOFTWARE\Microsoft\Enrollments\********-****-****-*****-************\"
$Values = Get-Item -Path $TargetPath1 
foreach ($Value in $Values)
{
    Write-Host ("wert: "+$Value.Property)
    Remove-ItemProperty -name $Value.Property -Path $TargetPath1
}#>
