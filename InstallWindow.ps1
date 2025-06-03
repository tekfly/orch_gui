# Add GUI assembly
Add-Type -AssemblyName PresentationFramework

# Paths
$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$componentJsonPath = Join-Path $downloadFolder "install_components.json"

# Load installer files
$files = Get-ChildItem -Path $downloadFolder -File | Where-Object { $_.Extension -match '\.(exe|msi|ps1)$' } | Sort-Object Name
if ($files.Count -eq 0) {
    [System.Windows.MessageBox]::Show("No files found in:`n$downloadFolder", "No files", "OK", "Information")
    exit
}

# Load components from JSON
try {
    $componentData = Get-Content $componentJsonPath -Raw | ConvertFrom-Json
    $allComponents = $componentData.components
    $defaultComponents = $componentData.defaults
} catch {
    [System.Windows.MessageBox]::Show("Could not load install_components.json.`n$($_.Exception.Message)", "Error", "OK", "Error")
    exit
}

# GUI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Install UiPath Components" Height="500" Width="500" WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <TextBlock Text="Select files to install:" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>

    <ListBox Name="FilesListBox" Grid.Row="1" SelectionMode="Extended" Height="120"/>

    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,10">
      <Button Name="InstallBtn" Content="Install" Width="100" Margin="0,0,10,0" IsEnabled="False"/>
      <Button Name="CancelBtn" Content="Cancel" Width="100"/>
    </StackPanel>

    <StackPanel Grid.Row="3" Orientation="Vertical" Visibility="Collapsed" Name="ComponentPanel">
      <TextBlock Text="Select additional components:" Margin="0,0,0,5" FontWeight="Bold"/>
      <ListBox Name="ComponentsListBox" Height="150" SelectionMode="Multiple"/>
    </StackPanel>
  </Grid>
</Window>
"@

# Load window
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$filesListBox = $window.FindName("FilesListBox")
$installBtn = $window.FindName("InstallBtn")
$cancelBtn = $window.FindName("CancelBtn")
$componentsListBox = $window.FindName("ComponentsListBox")
$componentPanel = $window.FindName("ComponentPanel")

foreach ($file in $files) {
    $filesListBox.Items.Add($file.Name) | Out-Null
}

$filesListBox.Add_SelectionChanged({
    $installBtn.IsEnabled = ($filesListBox.SelectedItems.Count -gt 0)
})

function Show-ComponentOptions {
    param ($installerType)
    $componentPanel.Visibility = 'Visible'
    $componentsListBox.Items.Clear()
    foreach ($item in $allComponents) {
        $li = New-Object System.Windows.Controls.ListBoxItem
        $li.Content = $item
        if ($item -in $defaultComponents.$installerType) {
            $li.IsSelected = $true
        }
        $componentsListBox.Items.Add($li)
    }
}

function Get-SelectedComponents {
    $selectedComponents = @()
    foreach ($item in $componentsListBox.SelectedItems) {
        $selectedComponents += $item.Content
    }
    return "ADDLOCAL=" + ($selectedComponents -join ",")
}

function Install-WithParams {
    param ($installerPath, $paramsArray)

    [System.Windows.MessageBox]::Show("Please wait...", "Installing", "OK", "Information")
    $exitCode = (Start-Process msiexec.exe -ArgumentList $paramsArray -Wait -PassThru).ExitCode
    if ($exitCode -in 0,1641,3010) {
        [System.Windows.MessageBox]::Show("Installation succeeded.", "Success", "OK", "Information")
    } else {
        [System.Windows.MessageBox]::Show("Installation failed. Exit code: $exitCode", "Failure", "OK", "Error")
    }
}

$installBtn.Add_Click({
    foreach ($selected in $filesListBox.SelectedItems) {
        $fullPath = Join-Path $downloadFolder $selected

        if ($selected -match '^Studio-') {
            $type = [System.Windows.MessageBox]::Show("Install as Studio? (No = Robot)", "Install Type", 'YesNoCancel', 'Question')
            if ($type -eq 'Cancel') { continue }
            $installerType = if ($type -eq 'Yes') { 'Studio' } else { 'Robot' }
            Show-ComponentOptions -installerType $installerType
            $window.Dispatcher.Invoke([action]{})

            $params = @(
                '/i',
                "\"$fullPath\"",
                (Get-SelectedComponents),
                '/l*vx',
                (Join-Path $downloadFolder "log_$($installerType.ToLower()).txt"),
                '/qn'
            )
            Install-WithParams -installerPath $fullPath -paramsArray $params
        }
        elseif ($selected -match '^Chrome') {
            $exitCode = (Start-Process -FilePath $fullPath -ArgumentList "/silent /install" -Verb RunAs -Wait -PassThru).ExitCode
            $msg = if ($exitCode -in 0,1641,3010) { "Chrome installed successfully." } else { "Chrome install failed. Exit code: $exitCode" }
            [System.Windows.MessageBox]::Show($msg, "Chrome Install", "OK", "Information")
        }
        else {
            $proc = Start-Process -FilePath $fullPath -Wait -PassThru
            $msg = if ($proc.ExitCode -eq 0) { "Installed successfully." } else { "Failed with exit code: $($proc.ExitCode)" }
            [System.Windows.MessageBox]::Show($msg, "Info", "OK", "Information")
        }
    }
})

$cancelBtn.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null
