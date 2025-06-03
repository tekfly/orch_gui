Add-Type -AssemblyName PresentationFramework

$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$logFolder = Join-Path $downloadFolder "logs"
$jsonFolder = Join-Path $downloadFolder "json_files"
$versionFile = Join-Path $jsonFolder "product_versions.json"
$componentsFile = Join-Path $jsonFolder "InstallComponents.json"
$jsonUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/product_versions.json"
$componentsUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/InstallComponents.json"

# Ensure directories exist
if (-not (Test-Path $downloadFolder)) { New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $jsonFolder)) { New-Item -Path $jsonFolder -ItemType Directory -Force | Out-Null }

# Download product_versions.json if missing
if (-not (Test-Path $versionFile)) {
    try {
        Invoke-WebRequest -Uri $jsonUrl -OutFile $versionFile -UseBasicParsing
    } catch {
        [System.Windows.MessageBox]::Show("Failed to download product_versions.json.", "Error", "OK", "Error")
        exit
    }
}
# Download InstallComponents.json if missing
if (-not (Test-Path $componentsFile)) {
    try {
        Invoke-WebRequest -Uri $componentsUrl -OutFile $componentsFile -UseBasicParsing
    } catch {
        [System.Windows.MessageBox]::Show("Failed to download InstallComponents.json.", "Error", "OK", "Error")
        exit
    }
}

# Load product_versions.json
try {
    $jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json
} catch {
    [System.Windows.MessageBox]::Show("Failed to parse product_versions.json.", "Error", "OK", "Error")
    exit
}

function Show-InstallTypeDialog {
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Choose Install Type" Height="150" Width="300" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <StackPanel Margin="10">
        <TextBlock Text="Install as Studio or Robot?" FontWeight="Bold" Margin="0,0,0,10"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" >
            <Button Name="StudioBtn" Content="Studio" Width="100" Margin="5"/>
            <Button Name="RobotBtn" Content="Robot" Width="100" Margin="5"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $dialog = [Windows.Markup.XamlReader]::Load($reader)
    $studioBtn = $dialog.FindName("StudioBtn")
    $robotBtn  = $dialog.FindName("RobotBtn")

    $result = $null
    $studioBtn.Add_Click({ $result = "Studio"; $dialog.Close() })
    $robotBtn.Add_Click({ $result = "Robot";  $dialog.Close() })

    $dialog.ShowDialog() | Out-Null
    return $result
}

function Show-ComponentOptions {
    param($installerType)

    if (-not (Test-Path $componentsFile)) {
        [System.Windows.MessageBox]::Show("InstallComponents.json not found!", "Error", "OK", "Error")
        return $null
    }

    $jsonContent = Get-Content $componentsFile -Raw | ConvertFrom-Json
    $allComponents = $jsonContent.components
    $defaults = $jsonContent.defaults.$installerType

    $checkboxesXaml = ""
    foreach ($comp in $allComponents) {
        $isChecked = if ($defaults -contains $comp) { "IsChecked='True'" } else { "" }
        $checkboxesXaml += "<CheckBox Name='chk$comp' Content='$comp' Margin='5' $isChecked />`n"
    }

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Select Components - $installerType" Height="400" Width="350" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <StackPanel Margin="10">
        <TextBlock Text="Select components to install:" FontWeight="Bold" Margin="0,0,0,10"/>
        <ScrollViewer Height="280">
            <StackPanel Name="ComponentsPanel">
                $checkboxesXaml
            </StackPanel>
        </ScrollViewer>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="OkBtn" Content="OK" Width="80" Margin="5"/>
            <Button Name="CancelBtn" Content="Cancel" Width="80" Margin="5"/>
        </StackPanel>
    </StackPanel>
</Window>
"@

    [xml]$xamlXml = $xaml
    $reader = (New-Object System.Xml.XmlNodeReader $xamlXml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $okBtn = $window.FindName("OkBtn")
    $cancelBtn = $window.FindName("CancelBtn")

    $selection = $null

    $okBtn.Add_Click({
        $selection = @()
        foreach ($comp in $allComponents) {
            $chk = $window.FindName("chk$comp")
            if ($chk -and $chk.IsChecked) {
                $selection += $comp
            }
        }
        $window.Close()
    })
    $cancelBtn.Add_Click({
        $window.Close()
    })

    $window.ShowDialog() | Out-Null
    return $selection
}

function Install-WithParams {
    param (
        [string]$installerPath,
        [string[]]$paramsArray,
        [string]$displayName
    )

    $progressXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Installing..." Height="120" Width="300" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" WindowStyle="ToolWindow">
    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
        <TextBlock Name="StatusText" FontWeight="Bold" FontSize="14" Margin="10" Text="Installing $displayName..."/>
        <ProgressBar Name="ProgressBar" Height="20" Width="250" IsIndeterminate="True" Margin="10"/>
    </StackPanel>
</Window>
"@

    [xml]$progressXml = $progressXaml
    $reader = (New-Object System.Xml.XmlNodeReader $progressXml)
    $progressWindow = [Windows.Markup.XamlReader]::Load($reader)

    $installJob = Start-Job -ScriptBlock {
        param($exe, $args)
        $proc = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru
        return $proc.ExitCode
    } -ArgumentList $installerPath, $paramsArray

    $null = $progressWindow.Show()
    while ($installJob.State -eq 'Running') {
        Start-Sleep -Milliseconds 200
    }

    $exitCode = Receive-Job -Job $installJob
    Remove-Job $installJob
    $progressWindow.Dispatcher.Invoke([action] { $progressWindow.Close() })

    return $exitCode
}

[xml]$mainXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Install UiPath Components" Height="450" Width="600" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <TextBlock Text="Filter by file type:" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <CheckBox Name="ChkMsi" Content=".msi" IsChecked="True" Margin="0,0,10,0"/>
            <CheckBox Name="ChkExe" Content=".exe" IsChecked="True" Margin="0,0,10,0"/>
            <CheckBox Name="ChkPs1" Content=".ps1" IsChecked="True"/>
        </StackPanel>

        <ListBox Name="FilesListBox" Grid.Row="1" SelectionMode="Single"/>

        <Button Name="InstallBtn" Grid.Row="2" Content="Install Selected" Height="30" Margin="0,10,0,0" HorizontalAlignment="Right" Width="120"/>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $mainXaml)
$mainWindow = [Windows.Markup.XamlReader]::Load($reader)

$chkMsi = $mainWindow.FindName("ChkMsi")
$chkExe = $mainWindow.FindName("ChkExe")
$chkPs1 = $mainWindow.FindName("ChkPs1")
$filesListBox = $mainWindow.FindName("FilesListBox")
$installBtn = $mainWindow.FindName("InstallBtn")

function Load-Files {
    $filesListBox.Items.Clear()
    $filters = @()
    if ($chkMsi.IsChecked) { $filters += "*.msi" }
    if ($chkExe.IsChecked) { $filters += "*.exe" }
    if ($chkPs1.IsChecked) { $filters += "*.ps1" }

    if ($filters.Count -eq 0) { return }

    foreach ($filter in $filters) {
        Get-ChildItem -Path $downloadFolder -Filter $filter -File | ForEach-Object {
            $filesListBox.Items.Add($_.Name) | Out-Null
        }
    }
}

Load-Files

$chkMsi.Add_Checked({ Load-Files })
$chkMsi.Add_Unchecked({ Load-Files })
$chkExe.Add_Checked({ Load-Files })
$chkExe.Add_Unchecked({ Load-Files })
$chkPs1.Add_Checked({ Load-Files })
$chkPs1.Add_Unchecked({ Load-Files })

$installBtn.Add_Click({

    $selectedFile = $filesListBox.SelectedItem
    if (-not $selectedFile) {
        [System.Windows.MessageBox]::Show("Please select a file to install.", "No Selection", "OK", "Warning")
        return
    }

    $Global:installType = $null

    if ($selectedFile -match "Studio|Robot") {
        $Global:installType = Show-InstallTypeDialog
        if (-not $Global:installType) { return }
    }

    $selectedComponents = @()
    if ($Global:installType -eq "Studio" -or $Global:installType -eq "Robot") {
        $selectedComponents = Show-ComponentOptions -installerType $Global:installType
        if (-not $selectedComponents -or $selectedComponents.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No components selected. Installation cancelled.", "Cancelled", "OK", "Information")
            return
        }
    }

    $installerFullPath = Join-Path $downloadFolder $selectedFile
    $extension = [IO.Path]::GetExtension($selectedFile).ToLower()
    $installParams = @()

    switch ($extension) {
        ".msi" {
            $installParams = @("/i", "`"$installerFullPath`"", "/qn")
            if ($selectedComponents) {
                $componentsString = $selectedComponents -join ","
                $installParams += "/v`"COMPONENTS=$componentsString`""
            }
        }
        ".exe" {
            $installParams = @("/S")
        }
        ".ps1" {
            $paramString = $selectedComponents -join ","
            $installParams = @("-ExecutionPolicy", "Bypass", "-File", "`"$installerFullPath`"", "-Components", "`"$paramString`"")
        }
        default {
            [System.Windows.MessageBox]::Show("Unsupported file type: $extension", "Error", "OK", "Error")
            return
        }
    }

    $exitCode = Install-WithParams -installerPath $installerFullPath -paramsArray $installParams -displayName $selectedFile

    if ($exitCode -eq 0) {
        [System.Windows.MessageBox]::Show("Installation completed successfully.", "Success", "OK", "Information")
    } else {
        [System.Windows.MessageBox]::Show("Installation failed with exit code $exitCode.", "Error", "OK", "Error")
    }
})

$mainWindow.ShowDialog() | Out-Null
