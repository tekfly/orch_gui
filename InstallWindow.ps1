Add-Type -AssemblyName PresentationFramework

$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$files = Get-ChildItem -Path $downloadFolder -File | Sort-Object Name

if ($files.Count -eq 0) {
    [System.Windows.MessageBox]::Show("No files found in:`n$downloadFolder", "No files", "OK", "Information")
    exit
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Install UiPath Components" Height="350" Width="450" WindowStartupLocation="CenterScreen" >
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Text="Select files to install:" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
        
        <ListBox Name="FilesListBox" Grid.Row="1" SelectionMode="Extended" />

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="InstallBtn" Content="Install" Width="100" Margin="0,0,10,0" IsEnabled="False"/>
            <Button Name="CancelBtn" Content="Cancel" Width="100"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$filesListBox = $window.FindName("FilesListBox")
$installBtn = $window.FindName("InstallBtn")
$cancelBtn = $window.FindName("CancelBtn")

foreach ($file in $files) {
    $filesListBox.Items.Add($file.Name) | Out-Null
}

$filesListBox.Add_SelectionChanged({
    $installBtn.IsEnabled = ($filesListBox.SelectedItems.Count -gt 0)
})

# Prompt for Studio or Robot
function Prompt-StudioOrRobot {
    $msg = "Selected file looks like a Studio installer.`nAre you installing a Studio? (For Robot choose NO)"
    $result = [System.Windows.MessageBox]::Show($msg, "Choose Install Type", [System.Windows.MessageBoxButton]::YesNoCancel, [System.Windows.MessageBoxImage]::Question)

    switch ($result) {
        'Yes' { return "Studio" }
        'No'  { return "Robot" }
        default { return $null }
    }
}

# Install Studio
function Install-Studio {
    param ($installerPath)
    [System.Windows.MessageBox]::Show("Launching Studio installation from:`n$installerPath", "Studio Install", "OK", "Information")

    $software = "UiPath Studio"
    $installed = Test-Path 'HKLM:\SOFTWARE\UiPath\UiPath Studio'
    if ($installed) {
        Write-Host "$software is already installed." -ForegroundColor Green
        [System.Windows.MessageBox]::Show("$software is already installed.", "Info", "OK", "Information")
    } else {
        Write-Host "$software is not installed. Installing now..." -ForegroundColor Yellow
        [System.Windows.MessageBox]::Show("Starting Studio install... Please wait.", "Installing", "OK", "Information")

        $robot_params = @(
            '/i'
            "`"$installerPath`""
            'ADDLOCAL=DesktopFeature,Robot,RegisterService,Packages,ChromeExtension'
            '/l*vx'
            'log_studio.txt'
            '/qn'
        )

        $exitCode = (Start-Process msiexec.exe -ArgumentList $robot_params -Wait -PassThru).ExitCode

        if ($exitCode -in 0, 1641, 3010) {
            Write-Host "Studio install completed." -ForegroundColor Green
            [System.Windows.MessageBox]::Show("Studio installed successfully.", "Success", "OK", "Information")
        } else {
            Write-Host "Studio install failed. Exit code: $exitCode" -ForegroundColor Red
            [System.Windows.MessageBox]::Show("Studio install failed.`nExit code: $exitCode", "Error", "OK", "Error")
        }
    }
}

# Install Robot
function Install-Robot {
    param ($installerPath)
    [System.Windows.MessageBox]::Show("Launching Robot installation from:`n$installerPath", "Robot Install", "OK", "Information")

    $robot_params = @(
        '/i'
        "`"$installerPath`""
        'ADDLOCAL=Robot,RegisterService'
        '/l*vx'
        'log_robot.txt'
        '/qn'
    )

    $exitCode = (Start-Process msiexec.exe -ArgumentList $robot_params -Wait -PassThru).ExitCode

    if ($exitCode -in 0, 1641, 3010) {
        Write-Host "Robot install completed." -ForegroundColor Green
        [System.Windows.MessageBox]::Show("Robot installed successfully.", "Success", "OK", "Information")
    } else {
        Write-Host "Robot install failed. Exit code: $exitCode" -ForegroundColor Red
        [System.Windows.MessageBox]::Show("Robot install failed.`nExit code: $exitCode", "Error", "OK", "Error")
    }
}

# Install click handler
$installBtn.Add_Click({
    foreach ($selected in $filesListBox.SelectedItems) {
        $fullPath = Join-Path $downloadFolder $selected

        if ($selected -match '^Studio-') {
            $choice = Prompt-StudioOrRobot
            if (-not $choice) { continue }

            if ($choice -eq "Studio") {
                Install-Studio -installerPath $fullPath
            } elseif ($choice -eq "Robot") {
                Install-Robot -installerPath $fullPath
            }
        } else {
            try {
                [System.Windows.MessageBox]::Show("Installing:`n$selected", "Info", "OK", "Information")
                $proc = Start-Process -FilePath $fullPath -Wait -PassThru
                if ($proc.ExitCode -eq 0) {
                    [System.Windows.MessageBox]::Show("Installation finished successfully for:`n$selected", "Success", "OK", "Information")
                } else {
                    [System.Windows.MessageBox]::Show("Installer finished with error code $($proc.ExitCode) for:`n$selected", "Warning", "OK", "Warning")
                }
            } catch {
                [System.Windows.MessageBox]::Show("Failed to start installer:`n$selected`n$($_.Exception.Message)", "Error", "OK", "Error")
            }
        }
    }
})

$cancelBtn.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null
