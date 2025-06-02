Add-Type -AssemblyName PresentationFramework

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
            <TextBlock Name="StatusText" Text="Starting downloads..." Margin="0,0,0,20" FontWeight="Bold" FontSize="14" TextAlignment="Center"/>

            <WrapPanel HorizontalAlignment="Center" >
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
$statusText = $window.FindName("StatusText")
$progressBar = $window.FindName("ProgressBar")
$btnDownload = $window.FindName("BtnDownload")
$btnInstall = $window.FindName("BtnInstall")
$btnConnect = $window.FindName("BtnConnect")
$btnUpdate = $window.FindName("BtnUpdate")

# Helper to update UI safely
function Update-UI {
    param([scriptblock]$action)
    $window.Dispatcher.Invoke($action)
}

# Function to download the two files with progress
function Download-FilesAsync {
    $filesToDownload = @(
        @{ Url = $productVersionsUrl; FileName = "product_versions.json" },
        @{ Url = $downloadWindowUrl; FileName = "DownloadWindow.ps1" }
    )
    $total = $filesToDownload.Count

    for ($i=0; $i -lt $total; $i++) {
        $file = $filesToDownload[$i]
        $savePath = Join-Path $downloadFolder $file.FileName

        Update-UI { $statusText.Text = "Downloading $($file.FileName) ($($i+1)/$total)..." }

        try {
            Invoke-WebRequest -Uri $file.Url -OutFile $savePath -UseBasicParsing -ErrorAction Stop
        } catch {
            Update-UI { [System.Windows.MessageBox]::Show("Failed to download $($file.FileName):`n$($_.Exception.Message)", "Error", "OK", "Error") }
        }

        $percent = [int](($i+1)/$total*100)
        Update-UI { $progressBar.Value = $percent }
    }

    Update-UI {
        $statusText.Text = "Downloads complete."
        $btnDownload.IsEnabled = $true
        $btnInstall.IsEnabled = $true
        $btnConnect.IsEnabled = $true
        $btnUpdate.IsEnabled = $true
        $progressBar.Value = 100
        [System.Windows.MessageBox]::Show("Files downloaded to:`n$downloadFolder", "Download Complete", "OK", "Information")
    }
}

# Start downloads immediately on window loaded
$window.Add_Loaded({
    # Run download async so UI stays responsive
    $ps = [powershell]::Create()
    $ps.AddScript(${function:Download-FilesAsync}) | Out-Null
    $ps.BeginInvoke()
})

# Dummy handlers for other buttons
$btnDownload.Add_Click({
    [System.Windows.MessageBox]::Show("Download button clicked.", "Info", "OK", "Information")
})

$btnInstall.Add_Click({
    [System.Windows.MessageBox]::Show("Install clicked - implement install logic.", "Info", "OK", "Information")
})

$btnConnect.Add_Click({
    [System.Windows.MessageBox]::Show("Connect clicked - implement connect logic.", "Info", "OK", "Information")
})

$btnUpdate.Add_Click({
    [System.Windows.MessageBox]::Show("Update clicked - implement update logic.", "Info", "OK", "Information")
})

# Show the window
$window.ShowDialog() | Out-Null
