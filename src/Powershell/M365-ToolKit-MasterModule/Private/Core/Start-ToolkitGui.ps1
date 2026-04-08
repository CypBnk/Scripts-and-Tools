function Start-ToolkitGui {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationFramework

    $xamlPath = Join-Path (Get-ToolkitRoot) 'GUI\XAML\MainWindow.xaml'
    if (-not (Test-Path -Path $xamlPath -PathType Leaf)) {
        throw "XAML UI file not found: $xamlPath"
    }

    [xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $lstWorkloads = $window.FindName('LstWorkloads')
    $gridActions = $window.FindName('GridActions')
    $txtLog = $window.FindName('TxtLog')
    $txtStatus = $window.FindName('TxtStatus')
    $btnRefresh = $window.FindName('BtnRefresh')
    $btnRun = $window.FindName('BtnRun')
    $chkNewWindow = $window.FindName('ChkNewWindow')
    $btnPreflight = $window.FindName('BtnPreflight')
    $txtSelectedAction = $window.FindName('TxtSelectedAction')
    $txtSelectedTarget = $window.FindName('TxtSelectedTarget')
    $txtArgs = $window.FindName('TxtArgs')
    $txtPreflight = $window.FindName('TxtPreflight')

    $state = [pscustomobject]@{
        Catalog = Get-ToolkitCatalog
    }

    $writeLog = {
        param([string]$Message)
        $txtLog.AppendText("$(Get-Date -Format 'HH:mm:ss') $Message`r`n")
        $txtLog.ScrollToEnd()
    }

    $getRows = {
        param([string]$Workload)
        @(
            $state.Catalog |
            Where-Object { $_.Workload -eq $Workload } |
            Select-Object Workload, ModuleName, DisplayName, RunType, Command, TargetPath, IsPlaceholder, Args, Prerequisites
        )
    }

    $refreshWorkloads = {
        $items = @($state.Catalog.Workload | Sort-Object -Unique)
        $list = New-Object System.Collections.ArrayList
        foreach ($item in $items) {
            [void]$list.Add($item)
        }

        $lstWorkloads.ItemsSource = $null
        $lstWorkloads.ItemsSource = $list
    }

    $formatArgs = {
        param([object]$ArgValues)
        if ($null -eq $ArgValues) {
            return ''
        }

        (@($ArgValues) -join "`r`n")
    }

    $parseArgs = {
        param([string]$Text)
        if ([string]::IsNullOrWhiteSpace($Text)) {
            return @()
        }

        @(
            $Text -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    & $refreshWorkloads
    $txtSelectedAction.Text = 'None'
    $txtSelectedTarget.Text = ''
    $txtArgs.Text = ''
    $txtPreflight.Text = 'Preflight not run.'

    $lstWorkloads.Add_SelectionChanged({
            $selectedWorkload = [string]$lstWorkloads.SelectedItem
            if ([string]::IsNullOrWhiteSpace($selectedWorkload)) {
                return
            }

            $rows = @(& $getRows -Workload $selectedWorkload)
            $rowList = New-Object System.Collections.ArrayList
            foreach ($row in $rows) {
                [void]$rowList.Add($row)
            }

            $gridActions.ItemsSource = $null
            $gridActions.ItemsSource = $rowList
            $txtStatus.Text = "Selected workload: $selectedWorkload"
            $txtPreflight.Text = 'Preflight not run.'
        })

    $gridActions.Add_SelectionChanged({
            $selectedAction = $gridActions.SelectedItem
            if ($null -eq $selectedAction) {
                $txtSelectedAction.Text = 'None'
                $txtSelectedTarget.Text = ''
                $txtArgs.Text = ''
                $txtPreflight.Text = 'Preflight not run.'
                return
            }

            $txtSelectedAction.Text = [string]$selectedAction.DisplayName
            $txtSelectedTarget.Text = [string]$selectedAction.TargetPath
            $txtArgs.Text = (& $formatArgs -ArgValues $selectedAction.Args)
            $txtPreflight.Text = 'Preflight not run.'
        })

    $btnRefresh.Add_Click({
            $state.Catalog = Get-ToolkitCatalog
            & $refreshWorkloads
            & $writeLog -Message 'Catalog refreshed.'
        })

    $btnPreflight.Add_Click({
            $selectedAction = $gridActions.SelectedItem
            if ($null -eq $selectedAction) {
                & $writeLog -Message 'No action selected for preflight.'
                return
            }

            try {
                $result = Test-ToolkitActionPrerequisites -Action $selectedAction
            }
            catch {
                Write-ToolkitLog -Level ERROR -Source 'Start-ToolkitGui' -Message "Preflight crashed for '$($selectedAction.DisplayName)'" -ErrorRecord $_
                & $writeLog -Message "Preflight error: $($_.Exception.Message)"
                return
            }

            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add($result.Summary)
            foreach ($check in $result.Checks) {
                $statusText = if ($check.Passed) { '[OK]' } else { '[FAIL]' }
                $lines.Add("$statusText $($check.Name) - $($check.Detail)")
            }

            $txtPreflight.Text = ($lines -join "`r`n")
            & $writeLog -Message "Preflight for '$($selectedAction.DisplayName)': $($result.Summary)"
        })

    $btnRun.Add_Click({
            $selectedAction = $gridActions.SelectedItem
            if ($null -eq $selectedAction) {
                & $writeLog -Message 'No action selected.'
                return
            }

            Write-ToolkitLog -Level INFO -Source 'Start-ToolkitGui' -Message "User initiated run: $($selectedAction.DisplayName)"
            & $writeLog -Message "Running: $($selectedAction.DisplayName)"
            $overrideArgs = & $parseArgs -Text $txtArgs.Text
            $runInNewWindow = $false
            if ($null -ne $chkNewWindow -and $chkNewWindow.IsChecked) {
                $runInNewWindow = $true
            }

            if ($runInNewWindow) {
                $result = Start-ToolkitActionInNewWindow -Action $selectedAction -ArgsOverride $overrideArgs
            }
            else {
                $result = Resolve-ToolkitAction -Action $selectedAction -ArgsOverride $overrideArgs
            }

            if ($result.Success) {
                & $writeLog -Message "Success: $($result.Message)"
            }
            else {
                & $writeLog -Message "Error: $($result.Message)"
            }
        })

    $window.ShowDialog() | Out-Null
}