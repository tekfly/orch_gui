Add-Type -AssemblyName PresentationFramework

# Define paths
$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$versionFile = Join-Path $downloadFolder "product_versions.json"
$jsonUrl = "https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/product_versions.json"  # Replace with real URL

# Ensure folder exists
if (-not (Test-Path $downloadFolder)) {
    New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null
}

# Download JSON file if missing
if (-not (Test-Path $versionFile)) {
    Write-Host "Downloading JSON from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $jsonUrl -OutFile $versionFile -UseBasicParsing
}

# Load JSON
try {
    $jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json
} catch {
    [System.Windows.MessageBox]::Show("Failed to load or parse product_versions.json.", "Error", "OK", "Error")
    exit
}

# Extract available versions per product
$products = @("Orchestrator", "Robot/Studio")
$actionsByProduct = @{
    "Orchestrator" = @("install", "download", "update")
    "Robot/Studio" = @("install", "download", "update", "connect")
}

# GUI XAML
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="UiPath Setup GUI" Height="300" Width="400">
    <Grid Margin="10">
        <StackPanel>
            <TextBlock Text="Select Product:" Margin="0,0,0,5"/>
            <ComboBox Name="ProductBox" Height="25" />
            
            <TextBlock Text="Select Action:" Margin="0,10,0,5"/>
            <ComboBox Name="ActionBox" Height="25" IsEnabled="False" />
            
            <TextBlock Text="Select Version:" Margin="0,10,0,5"/>
            <ComboBox Name="VersionBox" Height="25" IsEnabled="False" />

            <Button Name="SubmitBtn" Content="Run" Height="30" Margin="0,20,0,0"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Parse XAML and find controls
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$productBox = $window.FindName("ProductBox")
$actionBox = $window.FindName("ActionBox")
$versionBox = $window.FindName("VersionBox")
$submitBtn = $window.FindName("SubmitBtn")

# Fill product dropdown
$products | ForEach-Object { $productBox.Items.Add($_) }

# On Product selection
$productBox.Add_SelectionChanged({
    $selectedProduct = $productBox.SelectedItem.ToString()
    
    # Fill action dropdown based on product
    $actionBox.Items.Clear()
    $actionsByProduct[$selectedProduct] | ForEach-Object { $actionBox.Items.Add($_) }
    $actionBox.IsEnabled = $true

    # Fill version dropdown
    $versionBox.Items.Clear()
    $versions = $jsonData.$selectedProduct.PSObject.Properties.Name
    $versions | ForEach-Object { $versionBox.Items.Add($_) }
    $versionBox.IsEnabled = $true
})

# Button click event
$submitBtn.Add_Click({
    $global:gproduct = $productBox.SelectedItem
    $global:gaction = $actionBox.SelectedItem
    $global:gversion = $versionBox.SelectedItem

    if (-not $gproduct -or -not $gaction -or -not $gversion) {
        [System.Windows.MessageBox]::Show("Please select all options.", "Warning", "OK", "Warning")
        return
    }

    $downloadUrl = $jsonData.$gproduct.$gversion
    $savePath = Join-Path $downloadFolder "$gproduct-$gversion.exe"

    # Download file
    Write-Host "Downloading from: $downloadUrl" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $savePath -UseBasicParsing
    [System.Windows.MessageBox]::Show("File downloaded to: $savePath", "Success", "OK", "Info")
    
    $window.Close()
})

# Run GUI
$window.ShowDialog() | Out-Null
