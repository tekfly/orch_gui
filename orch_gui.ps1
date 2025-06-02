Add-Type -AssemblyName PresentationFramework

# Define paths
$global:downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$global:versionFile = Join-Path $downloadFolder "product_versions.json"
$global:jsonUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/product_versions.json"  # Replace with your raw GitHub URL

# Ensure folder exists
if (-not (Test-Path $downloadFolder)) {
    New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null
}

# Download JSON if not present
if (-not (Test-Path $versionFile)) {
    Write-Host "🔄 Downloading version info..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $jsonUrl -OutFile $versionFile -UseBasicParsing
    } catch {
        [System.Windows.MessageBox]::Show("❌ Failed to download product_versions.json.", "Error", "OK", "Error")
        exit
    }
}

# Load and parse JSON
try {
    $jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json
} catch {
    [System.Windows.MessageBox]::Show("❌ Failed to load or parse product_versions.json.", "Error", "OK", "Error")
    exit
}

# Define valid options
$products = @("Orchestrator", "Robot/Studio")
$actionsByProduct = @{
    "Orchestrator"   = @("install", "download", "update")
    "Robot/Studio"   = @("install", "download", "update", "connect")
}

# Create XAML UI with ProgressBar added
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="UiPath Setup GUI" Height="350" Width="400">
    <Grid Margin="10">
        <StackPanel>
            <TextBlock Text="Select Product:" Margin="0,0,0,5"/>
            <ComboBox Name="ProductBox" Height="25"/>

            <TextBlock Text="Select Action:" Margin="0,10,0,5"/>
            <ComboBox Name="ActionBox" Height="25" IsEnabled="False"/>

            <TextBlock Text="Select Version:" Margin="0,10,0,5"/>
            <ComboBox Name="VersionBox" Height="25" IsEnabled="False"/>

            <ProgressBar Name="DownloadProgressBar" Height="20" Margin="0,20,0,0" Minimum="0" Maximum="100" Value="0"/>

            <Button Name="SubmitBtn" Content="Run" Height="30" Margin="0,20,0,0"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Load UI from XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$productBox       = $window.FindName("ProductBox")
$actionBox        = $window.FindName("ActionBox")
$versionBox       = $window.FindName("VersionBox")
$submitBtn        = $window.FindName("SubmitBtn")
$progressBar      = $window.FindName("DownloadProgressBar")

# Populate Product dropdown
$products | ForEach-Object { $productBox.Items.Add($_) }

# On Product selection → populate Action dropdown
$productBox.Add_SelectionChanged({
    $selectedProduct = $productBox.SelectedItem.ToString()

    # Enable and populate ActionBox
    $actionBox.Items.Clear()
    $actionsByProduct[$selectedProduct] | ForEach-Object { $actionBox.Items.Add($_) }
    $actionBox.IsEnabled = $true

    # Clear VersionBox and disable
    $versionBox.Items.Clear()
    $versionBox.IsEnabled = $false

    # Reset progress bar
    $progressBar.Value = 0
})

# On Action selection → populate Version dropdown
$actionBox.Add_SelectionChanged({
    $selectedProduct = $productBox.SelectedItem.ToString()
    $selectedAction = $actionBox.SelectedItem.ToString()

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
        }

        # Reset progress bar
        $progressBar.Value = 0
    }
})

# On Submit - download with progress
$submitBtn.Add_Click({
    $global:gproduct = $productBox.SelectedItem
    $global:gaction = $actionBox.SelectedItem
    $global:gversion = $versionBox.SelectedItem

    if (-not $gproduct -or -not $gaction -or -not $gversion) {
        [System.Windows.MessageBox]::Show("⚠️ Please select all options.", "Warning", "OK", "Warning")
        return
    }

    $downloadUrl = $jsonData.$gproduct.$gversion
    if (-not $downloadUrl) {
        [System.Windows.MessageBox]::Show("❌ Version URL not found in JSON.", "Error", "OK", "Error")
        return
    }

    $fileName = Split-Path $downloadUrl -Leaf
    $savePath = Join-Path $downloadFolder $fileName

    # Reset progress bar
    $progressBar.Value = 0

    # Create a .NET WebClient explicitly
    $webClient = New-Object System.Net.WebClient

    # Register DownloadProgressChanged event
    $progressEvent = Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
        $progressBar.Dispatcher.Invoke([action]{
            $progressBar.Value = $Event.SourceEventArgs.ProgressPercentage
        })
    }

    # Register DownloadFileCompleted event
    $completedEvent = Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -Action {
        if ($Event.SourceEventArgs.Error) {
            [System.Windows.MessageBox]::Show("❌ Download failed: $($Event.SourceEventArgs.Error.Message)", "Error", "OK", "Error")
        } else {
            [System.Windows.MessageBox]::Show("✅ Downloaded to: $savePath", "Success", "OK", "Info")
            $window.Close()
        }

        # Unregister events to avoid leaks
        Unregister-Event -SourceIdentifier $progressEvent.Name
        Unregister-Event -SourceIdentifier $completedEvent.Name
    }

    try {
        $uri = [Uri]$downloadUrl
        # Start async download
        $webClient.DownloadFileAsync($uri, $savePath)
    } catch {
        [System.Windows.MessageBox]::Show("❌ Download error: $($_.Exception.Message)", "Error", "OK", "Error")
        # Unregister events in case of error
        Unregister-Event -SourceIdentifier $progressEvent.Name
        Unregister-Event -SourceIdentifier $completedEvent.Name
    }
})


# Show the GUI
$window.ShowDialog() | Out-Null
