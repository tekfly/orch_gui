Add-Type -AssemblyName PresentationFramework

$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$versionFile = Join-Path $downloadFolder "product_versions.json"
$jsonUrl = "https://raw.githubusercontent.com/tekfly/orch_gui/refs/heads/main/product_versions.json"

if (-not (Test-Path $downloadFolder)) {
    New-Item -Path $downloadFolder -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path $versionFile)) {
    try {
        Invoke-WebRequest -Uri $jsonUrl -OutFile $versionFile -UseBasicParsing
    } catch {
        [System.Windows.MessageBox]::Show("Failed to download product_versions.json.", "Error", "OK", "Error")
        exit
    }
}

try {
    $jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json
} catch {
    [System.Windows.MessageBox]::Show("Failed to load or parse product_versions.json.", "Error", "OK", "Error")
    exit
}

$products = @("Orchestrator", "Robot/Studio", "Others")
$actionsByProduct = @{
    "Orchestrator" = @("download")
    "Robot/Studio" = @("download")
    "Others" = @("download")
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Download UiPath Components" Height="400" Width="500" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <StackPanel>
            <TextBlock Text="Select Product:" Margin="0,0,0,5"/>
            <ComboBox Name="ProductBox" Height="25"/>

            <TextBlock Text="Select Action:" Margin="0,10,0,5"/>
            <ComboBox Name="ActionBox" Height="25" IsEnabled="False"/>

            <TextBlock Text="Select Version:" Margin="0,10,0,5"/>
            <ComboBox Name="VersionBox" Height="25" IsEnabled="False"/>

            <ListBox Name="OthersListBox" Height="100" SelectionMode="Extended" Visibility="Collapsed"/>

            <ProgressBar Name="ProgressBar" Height="20" Margin="0,20,0,0" Minimum="0" Maximum="100" Visibility="Hidden"/>

            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,20,0,0">
                <Button Name="DownloadBtn" Content="Download" Width="100" Height="30" IsEnabled="False" Margin="0,0,10,0"/>
                <Button Name="CancelBtn" Content="Cancel" Width="100" Height="30" IsEnabled="False"/>
            </StackPanel>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$productBox  = $window.FindName("ProductBox")
$actionBox   = $window.FindName("ActionBox")
$versionBox  = $window.FindName("VersionBox")
$othersListBox = $window.FindName("OthersListBox")
$downloadBtn = $window.FindName("DownloadBtn")
$cancelBtn   = $window.FindName("CancelBtn")
$progressBar = $window.FindName("ProgressBar")

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
        $cancelBtn.IsEnabled = $false

        $othersListBox.Items.Clear()
        $othersListBox.Visibility = if ($selectedProduct -eq "Others") { 'Visible' } else { 'Collapsed' }
    }
})

yourJson = $jsonData

$actionBox.Add_SelectionChanged({
    $selectedProduct = $productBox.SelectedItem
    $selectedAction = $actionBox.SelectedItem

    if ($selectedProduct -eq "Others") {
        $othersListBox.Items.Clear()
        $othersListBox.Tag = @{}
        $othersListBox.Visibility = 'Visible'

        $otherProducts = $jsonData.PSObject.Properties.Name | Where-Object { $_ -notin @("Orchestrator", "Robot/Studio") }

        foreach ($otherProduct in $otherProducts) {
            foreach ($ver in $jsonData.$otherProduct.PSObject.Properties.Name) {
                $display = "$otherProduct $ver"
                $othersListBox.Items.Add($display)
                $othersListBox.Tag[$display] = @{
                    Product = $otherProduct
                    Version = $ver
                    Url     = $jsonData.$otherProduct.$ver
                }
            }
        }

        $downloadBtn.IsEnabled = $true
        $versionBox.IsEnabled = $false
    }
    elseif ($selectedProduct -and $selectedAction) {
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

$downloadBtn.Add_Click({
    $product = $productBox.SelectedItem

    if ($product -eq "Others") {
        $selectedItems = @($othersListBox.SelectedItems)
        if (-not $selectedItems) {
            [System.Windows.MessageBox]::Show("Please select at least one component from Others.", "Warning", "OK", "Warning")
            return
        }

        foreach ($item in $selectedItems) {
            $info = $othersListBox.Tag[$item]
            $url = $info.Url
            $filename = Split-Path $url -Leaf
            $savePath = Join-Path $downloadFolder $filename

            try {
                Write-Host "Downloading $filename..."
                Invoke-WebRequest -Uri $url -OutFile $savePath -UseBasicParsing
            } catch {
                Write-Host "Error downloading $filename : $_"
            }
        }

        [System.Windows.MessageBox]::Show("All selected items have been downloaded.", "Done", "OK", "Information")
        return
    }

    $version = $versionBox.SelectedItem
    $url = $jsonData.$product.$version
    if ($product -eq "Robot/Studio") {
        $savePath = Join-Path $downloadFolder "Studio-$version.msi"
    } else {
        $savePath = Join-Path $downloadFolder "$product-$version.msi"
    }

    try {
        Write-Host "Starting download..."
        Invoke-WebRequest -Uri $url -OutFile $savePath -UseBasicParsing
        [System.Windows.MessageBox]::Show("Download completed.`nSaved to: $savePath", "Success", "OK", "Information")
    } catch {
        [System.Windows.MessageBox]::Show("Download failed:`n$($_.Exception.Message)", "Error", "OK", "Error")
    }
})

$cancelBtn.Add_Click({
    $cancelBtn.IsEnabled = $false
})

$window.ShowDialog() | Out-Null
