Add-Type -AssemblyName PresentationFramework

# Define paths & URLs
$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$versionFile = Join-Path $downloadFolder "product_versions.json"
$jsonUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/product_versions.json"

# Ensure download folder exists
if (-not (Test-Path $downloadFolder)) {
    New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null
}

# Download JSON if not present
if (-not (Test-Path $versionFile)) {
    try {
        Invoke-WebRequest -Uri $jsonUrl -OutFile $versionFile -UseBasicParsing
    } catch {
        [System.Windows.MessageBox]::Show("Failed to download product_versions.json.", "Error", "OK", "Error")
        exit
    }
}

# Load and parse JSON
try {
    $jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json
} catch {
    [System.Windows.MessageBox]::Show("Failed to load or parse product_versions.json.", "Error", "OK", "Error")
    exit
}

# Define products & actions
$products = @("Orchestrator", "Robot/Studio")
$actionsByProduct = @{
    "Orchestrator"   = @("download")
    "Robot/Studio"   = @("download")
}

# UI XAML
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Download UiPath Components" Height="360" Width="420" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <StackPanel>
            <TextBlock Text="Select Product:" Margin="0,0,0,5"/>
            <ComboBox Name="ProductBox" Height="25"/>

            <TextBlock Text="Select Action:" Margin="0,10,0,5"/>
            <ComboBox Name="ActionBox" Height="25" IsEnabled="False"/>

            <TextBlock Text="Select Version:" Margin="0,10,0,5"/>
            <ComboBox Name="VersionBox" Height="25" IsEnabled="False"/>

            <ProgressBar Name="ProgressBar" Height="20" Margin="0,20,0,0" Minimum="0" Maximum="100" Visibility="Hidden"/>

            <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                <Button Name="DownloadBtn" Content="Download" Width="100" Margin="0,0,10,0" IsEnabled="False"/>
                <Button Name="CancelBtn" Content="Cancel" Width="100" IsEnabled="False"/>
            </StackPanel>
        </StackPanel>
    </Grid>
</Window>
"@

# Load UI
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$productBox  = $window.FindName("ProductBox")
$actionBox   = $window.FindName("ActionBox")
$versionBox  = $window.FindName("VersionBox")
$downloadBtn = $window.FindName("DownloadBtn")
$cancelBtn   = $window.FindName("CancelBtn")
$progressBar = $window.FindName("ProgressBar")

# Populate product dropdown
$products | ForEach-Object { $productBox.Items.Add($_) }

$productBox.Add_SelectionChanged({
    $selectedProduct = $productBox.SelectedItem
    if ($selectedProduct) {
        $actionBox.Items.Clear()
        $actionsByProduct[$selectedProduct] | ForEach-Object { $actionBox.Items.Add($_) }
        $actionBox.IsEnabled = $true
        $versionBox.Items.Clear()
        $versionBox.IsEnabled = $false
        $downloadBtn.IsEnabled = $false
    }
})

$actionBox.Add_SelectionChanged({
    $selectedProduct = $productBox.SelectedItem
    $selectedAction = $actionBox.SelectedItem
    if ($selectedProduct -and $selectedAction) {
        $versionBox.Items.Clear()
        $jsonSection = $jsonData.PSObject.Properties |
            Where-Object { $_.Name -eq $selectedProduct } |
            Select-Object -ExpandProperty Value

        if ($jsonSection) {
            $jsonSection.PSObject.Properties.Name |
                Sort-Object -Descending |
                ForEach-Object { $versionBox.Items.Add($_) }
            $versionBox.IsEnabled = $true
            $downloadBtn.IsEnabled = $false
        }
    }
})

$versionBox.Add_SelectionChanged({
    if ($versionBox.SelectedItem) {
        $downloadBtn.IsEnabled = $true
    } else {
        $downloadBtn.IsEnabled = $false
    }
})

# Global state
$global:webClient = $null
$global:downloadFinished = $false
$global:downloadError = $null

function Download-FileWithProgress {
    param(
        [string]$Url,
        [string]$Destination
    )

    $progressBar.Visibility = 'Visible'
    $progressBar.Value = 0
    $cancelBtn.IsEnabled = $true

    $global:webClient = New-Object System.Net.WebClient
    $global:downloadFinished = $false
    $global:downloadError = $null

    Register-ObjectEvent -InputObject $global:webClient -EventName DownloadProgressChanged -Action {
        $e = $EventArgs
        $progressBar.Dispatcher.Invoke([action]{
            $progressBar.Value = $e.ProgressPercentage
        })
    } | Out-Null

    Register-ObjectEvent -InputObject $global:webClient -EventName DownloadFileCompleted -Action {
        $e = $EventArgs
        if ($e.Error) {
            $global:downloadError = $e.Error.Message
        }
        $global:downloadFinished = $true
    } | Out-Null

    $global:webClient.DownloadFileAsync($Url, $Destination)

    while (-not $global:downloadFinished) {
        Start-Sleep -Milliseconds 100
        $window.Dispatcher.Invoke([Action]{}, "Background")
    }

    $progressBar.Visibility = 'Hidden'
    $cancelBtn.IsEnabled = $false

    if ($global:downloadError) {
        throw $global:downloadError
    }
}

# Download button click
$downloadBtn.Add_Click({
    $product = $productBox.SelectedItem
    $version = $versionBox.SelectedItem
    $url = $jsonData.$product.$version

    if (-not $url) {
        [System.Windows.MessageBox]::Show("Download URL not found.", "Error", "OK", "Error")
        return
    }

    $fileName = Split-Path $url -Leaf
    $savePath = Join-Path $downloadFolder $fileName

    try {
        Download-FileWithProgress -Url $url -Destination $savePath
        [System.Windows.MessageBox]::Show("Download completed.`nSaved to: $savePath", "Success", "OK", "Information")
    } catch {
        [System.Windows.MessageBox]::Show("Download failed:`n$($_.Exception.Message)", "Error", "OK", "Error")
    }
})

# Cancel button click
$cancelBtn.Add_Click({
    if ($global:webClient -and $global:webClient.IsBusy) {
        $global:webClient.CancelAsync()
        $global:downloadError = "Download cancelled by user."
        $global:downloadFinished = $true
        $progressBar.Visibility = 'Hidden'
        $cancelBtn.IsEnabled = $false
        [System.Windows.MessageBox]::Show("Download cancelled.", "Cancelled", "OK", "Warning")
    }
})

# Show window
$window.ShowDialog() | Out-Null
