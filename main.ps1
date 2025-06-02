Add-Type -AssemblyName PresentationFramework

# Relaunch script as admin if not already
function Ensure-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            [System.Windows.MessageBox]::Show("Admin permissions are required to run this script.", "Permission Denied", "OK", "Error")
        }
        exit
    }
}

# Ensure admin rights
Ensure-Admin

# Set execution policy if needed
$currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
if ($currentPolicy -ne "RemoteSigned") {
    try {
        Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
    } catch {
        [System.Windows.MessageBox]::Show("Failed to set execution policy: `n$($_.Exception.Message)", "Policy Error", "OK", "Error")
    }
}



# Paths and URLs
$global:downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$productVersionsUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/product_versions.json"
$downloadWindowUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/DownloadWindow.ps1"

# Ensure download folder exists
if (-not (Test-Path $downloadFolder)) {
    New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null
}

# XAML UI with progress bar at top
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="UiPath Main Window" Height="250" Width="400" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Width="350" >
            <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100" Margin="0,0,0,10"/>
            <TextBlock Name="StatusText" Text="Ready" Margin="0,0,0,20" FontWeight="Bold" FontSize="14" TextAlignment="Center"/>
            <WrapPanel HorizontalAlignment="Center" >
                <Button Name="BtnFiles" Width="80" Margin="5" Content="UpdateFiles" IsEnabled="True"/>
                <Button Name="BtnDownload" Width="80" Margin="5" Content="Download" IsEnabled="False"/>
                <Button Name="BtnInstall" Width="80" Margin="5" Content="Install" IsEnabled="False"/>
                <Button Name="BtnConnect" Width="80" Margin="5" Content="Connect" IsEnabled="False"/>
                <Button Name="BtnUpdate" Width="80" Margin="5" Content="Update" IsEnabled="False"/>
            </WrapPanel>
        </StackPanel>
    </Grid>
</Window>
"@

# Load UI
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$statusText   = $window.FindName("StatusText")
$progressBar  = $window.FindName("ProgressBar")
$btnFiles     = $window.FindName("BtnFiles")
$btnDownload  = $window.FindName("BtnDownload")
$btnInstall   = $window.FindName("BtnInstall")
$btnConnect   = $window.FindName("BtnConnect")
$btnUpdate    = $window.FindName("BtnUpdate")

function Download-Files {
    $files = @(
        @{ Url = $productVersionsUrl; FileName = "product_versions.json" },
        @{ Url = $downloadWindowUrl; FileName = "DownloadWindow.ps1" }
    )
    $count = $files.Count

    for ($i = 0; $i -lt $count; $i++) {
        $file = $files[$i]
        $savePath = Join-Path $downloadFolder $file.FileName

        $statusText.Text = "Downloading $($file.FileName)..."
        $progressBar.Value = [math]::Round(($i / $count) * 100)

        try {
            Invoke-WebRequest -Uri $file.Url -OutFile $savePath -UseBasicParsing -ErrorAction Stop
        } catch {
            [System.Windows.MessageBox]::Show("Failed to download $($file.FileName):`n$($_.Exception.Message)", "Error", "OK", "Error")
            return
        }
    }

    $progressBar.Value = 100
    $statusText.Text = "Downloads complete."
    $btnDownload.IsEnabled = $true
    $btnInstall.IsEnabled = $true
    $btnConnect.IsEnabled = $true
    $btnUpdate.IsEnabled = $true
    [System.Windows.MessageBox]::Show("Files downloaded to:`n$downloadFolder", "Done", "OK", "Information")
}

# Trigger download immediately when the window loads
$window.Add_Loaded({
    Download-Files
})

# Re-download when clicking "UpdateFiles"
$btnFiles.Add_Click({
    $statusText.Text = "Updating files..."
    $progressBar.Value = 0
    Download-Files
})

# Placeholder buttons
$btnDownload.Add_Click({ 
    #[System.Windows.MessageBox]::Show("Download clicked.") 
    & "$($global:downloadFolder)\DownloadWindow.ps1"
})
$btnInstall.Add_Click({ [System.Windows.MessageBox]::Show("Install clicked.") })
$btnConnect.Add_Click({ [System.Windows.MessageBox]::Show("Connect clicked.") })
$btnUpdate.Add_Click({ [System.Windows.MessageBox]::Show("Update clicked.") })

# Show the window
$window.ShowDialog() | Out-Null
