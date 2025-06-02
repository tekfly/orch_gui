Add-Type -AssemblyName PresentationFramework

# Define paths & URLs (adjust these as needed)
$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$versionFile = Join-Path $downloadFolder "product_versions.json"
$jsonUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/product_versions.json"  # Your JSON URL

# Ensure download folder exists
if (-not (Test-Path $downloadFolder)) {
    New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null
}

# Download JSON if not present
if (-not (Test-Path $versionFile)) {
    Write-Host "Downloading version info..."
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

# Define products & actions (only Download for this window)
$products = @("Orchestrator", "Robot/Studio")
$actionsByProduct = @{
    "Orchestrator"   = @("download")
    "Robot/Studio"   = @("download")
}

# XAML UI for Download window
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Download UiPath Components" Height="320" Width="400" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <StackPanel>
            <TextBlock Text="Select Product:" Margin="0,0,0,5"/>
            <ComboBox Name="ProductBox" Height="25"/>

            <TextBlock Text="Select Action:" Margin="0,10,0,5"/>
            <ComboBox Name="ActionBox" Height="25" IsEnabled="False"/>

            <TextBlock Text="Select Version:" Margin="0,10,0,5"/>
            <ComboBox Name="VersionBox" Height="25" IsEnabled="False"/>

            <ProgressBar Name="ProgressBar" Height="20" Margin="0,20,0,0" Minimum="0" Maximum="100" Visibility="Hidden"/>

            <Button Name="DownloadBtn" Content="Download" Height="30" Margin="0,20,0,0" IsEnabled="False"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Load UI from XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$productBox  = $window.FindName("ProductBox")
$actionBox   = $window.FindName("ActionBox")
$versionBox  = $window.FindName("VersionBox")
$downloadBtn = $window.FindName("DownloadBtn")
$progressBar = $window.FindName("ProgressBar")

# Populate Product dropdown
$products | ForEach-Object { $productBox.Items.Add($_) }

# On Product selection → populate Action dropdown (only download here)
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

# On Action selection → populate Version dropdown
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

# Enable Download button when version selected
$versionBox.Add_SelectionChanged({
    if ($versionBox.SelectedItem) {
        $downloadBtn.IsEnabled = $true
    } else {
        $downloadBtn.IsEnabled = $false
    }
})

# Download function with progress bar update
function Download-FileWithProgress {
    param(
        [string]$Url,
        [string]$Destination
    )

    $progressBar.Visibility = 'Visible'
    $progressBar.Value = 0

    $webClient = New-Object System.Net.WebClient

    $webClient.DownloadProgressChanged += {
        param($sender, $e)
        $progressBar.Dispatcher.Invoke([action]{
            $progressBar.Value = $e.ProgressPercentage
        })
    }

    $downloadFinished = $false
    $downloadError = $null

    $webClient.DownloadFileCompleted += {
        param($sender, $e)
        if ($e.Error) {
            $downloadError = $e.Error.Message
        }
        $downloadFinished = $true
    }

    $uri = [Uri]$Url
    $webClient.DownloadFileAsync($uri, $Destination)

    # Wait until download completes
    while (-not $downloadFinished) {
        Start-Sleep -Milliseconds 100
        $window.Dispatcher.Invoke([Action]{},"Background")
    }

    $progressBar.Visibility = 'Hidden'

    if ($downloadError) {
        throw $downloadError
    }
}

# On Download button click
$downloadBtn.Add_Click({
    $product = $productBox.SelectedItem
    $version = $versionBox.SelectedItem
    $url = $jsonData.$product.$version

    if (-not $url) {
        [System.Windows.MessageBox]::Show("Download URL not found for selected product/version.", "Error", "OK", "Error")
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

# Show window
$window.ShowDialog() | Out-Null
