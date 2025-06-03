Add-Type -AssemblyName PresentationFramework

$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$versionFile = Join-Path $downloadFolder "json_files\product_versions.json"
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
    $downloadBtn.IsEnabled = !!$versionBox.SelectedItem
})

function Download-File {
    param (
        [string]$url,
        [string]$savePath
    )

    $psMajor = $PSVersionTable.PSVersion.Major

    if ($psMajor -ge 3) {
        # Use Invoke-WebRequest for PS 3.0 and above
        Invoke-WebRequest -Uri $url -OutFile $savePath -UseBasicParsing
    } else {
        # Use BITS transfer as fallback for older PS versions
        Start-BitsTransfer -Source $url -Destination $savePath
    }
}

$downloadBtn.Add_Click({
    try {
        $waitingWindowXaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        Title='Downloading' SizeToContent='WidthAndHeight' WindowStartupLocation='CenterScreen' ResizeMode='NoResize'>
    <StackPanel Margin='20'>
        <TextBlock Text='Waiting for download to end...' FontSize='14' FontWeight='Bold' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

        $reader = (New-Object System.Xml.XmlNodeReader ([xml]$waitingWindowXaml))
        $waitingWindow = [Windows.Markup.XamlReader]::Load($reader)

        # Show the waiting window non-blocking
        $waitingWindow.Show()

        # Run download async in background job
        $job = Start-Job -ScriptBlock {
            param($product, $version, $selectedItems, $othersTag, $jsonData, $downloadFolder)

            Add-Type -AssemblyName PresentationFramework

            function Download-FileInner {
                param ($url, $savePath)
                $psMajor = $PSVersionTable.PSVersion.Major
                if ($psMajor -ge 3) {
                    Invoke-WebRequest -Uri $url -OutFile $savePath -UseBasicParsing
                } else {
                    Start-BitsTransfer -Source $url -Destination $savePath
                }
            }

            if ($product -eq "Others") {
                if (-not $selectedItems) {
                    throw "Please select at least one component from Others."
                }

                foreach ($item in $selectedItems) {
                    $info = $othersTag[$item]
                    $url = $info.Url
                    $filename = Split-Path $url -Leaf
                    $savePath = Join-Path $downloadFolder $filename
                    Download-FileInner -url $url -savePath $savePath
                }
            } else {
                $url = $jsonData.$product.$version
                $productNameForFile = if ($product -like "*/*") { ($product -split '/')[1] } else { $product }
                $savePath = Join-Path $downloadFolder "$productNameForFile-$version.msi"
                Download-FileInner -url $url -savePath $savePath
            }
        } -ArgumentList $productBox.SelectedItem, $versionBox.SelectedItem, @($othersListBox.SelectedItems), $othersListBox.Tag, $jsonData, $downloadFolder

        # Wait for job to finish
        $job | Wait-Job

        # Check for errors
        $jobResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
        $jobErrors = $job.ChildJobs[0].JobStateInfo.Reason

        # Close waiting window
        $waitingWindow.Dispatcher.Invoke([action]{
            $waitingWindow.Close()
        })

        if ($jobErrors) {
            throw $jobErrors
        }

        [System.Windows.MessageBox]::Show("Download completed.", "Success", "OK", "Information")

        # Remove the job
        Remove-Job -Job $job -Force
    }
    catch {
        if ($waitingWindow -and $waitingWindow.IsVisible) {
            $waitingWindow.Dispatcher.Invoke([action]{
                $waitingWindow.Close()
            })
        }
        [System.Windows.MessageBox]::Show("Download failed: $($_.Exception.Message)", "Error", "OK", "Error")
    }
})

$cancelBtn.Add_Click({ $cancelBtn.IsEnabled = $false })

$window.ShowDialog() | Out-Null
