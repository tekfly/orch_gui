Add-Type -AssemblyName PresentationFramework

# Create the main window XAML (simplified)
[xml]$xaml = @"
<Window Title="UiPath Manager" Height="200" Width="300">
    <StackPanel Margin="10">
        <TextBlock Name="StatusText" Text="Starting downloads..." Margin="0,0,0,10"/>
        <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100"/>
        <StackPanel Orientation="Horizontal" Margin="0,20,0,0" HorizontalAlignment="Center" >
            <Button Name="BtnDownload" Content="Download" Margin="5" IsEnabled="False" Width="60"/>
            <Button Name="BtnInstall" Content="Install" Margin="5" IsEnabled="False" Width="60"/>
            <Button Name="BtnConnect" Content="Connect" Margin="5" IsEnabled="False" Width="60"/>
            <Button Name="BtnUpdate" Content="Update" Margin="5" IsEnabled="False" Width="60"/>
        </StackPanel>
    </StackPanel>
</Window>
"@

# Load UI
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$statusText = $window.FindName("StatusText")
$progressBar = $window.FindName("ProgressBar")
$btnDownload = $window.FindName("BtnDownload")
$btnInstall = $window.FindName("BtnInstall")
$btnConnect = $window.FindName("BtnConnect")
$btnUpdate = $window.FindName("BtnUpdate")

# Simulate download process (you’d replace with your actual download logic)
Start-Job -ScriptBlock {
    for ($i = 0; $i -le 100; $i += 10) {
        Start-Sleep -Milliseconds 300
        Write-Output $i
    }
} | ForEach-Object {
    $progress = $_
    $progressBar.Dispatcher.Invoke([action]{ $progressBar.Value = $progress })
    $statusText.Dispatcher.Invoke([action]{ $statusText.Text = "Downloading... $progress%" })
}

# Once done enable buttons
$progressBar.Value = 100
$statusText.Text = "Ready."

$btnDownload.IsEnabled = $true
$btnInstall.IsEnabled = $true
$btnConnect.IsEnabled = $true
$btnUpdate.IsEnabled = $true

# Button click handlers open other windows (pseudo code)
$btnDownload.Add_Click({
    # You could dot-source or call a script for DownloadWindow.ps1
    & .\DownloadWindow.ps1
})

$btnInstall.Add_Click({
    & .\InstallWindow.ps1
})

$btnConnect.Add_Click({
    & .\ConnectWindow.ps1
})

$btnUpdate.Add_Click({
    & .\UpdateWindow.ps1
})

# Show main window
$window.ShowDialog() | Out-Null
