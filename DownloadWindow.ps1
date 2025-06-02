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

            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,20,0,0">
                <Button Name="DownloadBtn" Content="Download" Width="100" Height="30" IsEnabled="False" Margin="0,0,10,0"/>
                <Button Name="CancelBtn" Content="Cancel" Width="100" Height="30" IsEnabled="False"/>
            </StackPanel>
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
$cancelBtn   = $window.FindName("CancelBtn")
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
        $cancelBtn.IsEnabled = $false
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
            $cancelBtn.IsEnabled = $false
        }
    }
})

# Enable Download button when version selected
$versionBox.Add_SelectionChanged({
    if ($versionBox.SelectedItem) {
        $downloadBtn.IsEnabled = $true
        $cancelBtn.IsEnabled = $false
    } else {
        $downloadBtn.IsEnabled = $false
        $cancelBtn.IsEnabled = $false
    }
})

# Cancellation token source for async download
$cancellationTokenSource = $null

# Async download function with HttpClient, progress, and cancellation support
function Download-FileAsync {
    param(
        [string]$Url,
        [string]$Destination,
        [System.Threading.CancellationToken]$CancellationToken
    )

    $httpClient = [System.Net.Http.HttpClient]::new()

    try {
        $response = $httpClient.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $CancellationToken).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode()

        $totalBytes = $response.Content.Headers.ContentLength
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()

        $fileStream = [System.IO.File]::Create($Destination)
        $buffer = New-Object byte[] 81920
        $totalRead = 0

        while (($read = $stream.ReadAsync($buffer, 0, $buffer.Length, $CancellationToken).GetAwaiter().GetResult()) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read

            # Update progress bar on UI thread
            $progressPercent = if ($totalBytes) { [math]::Round(($totalRead / $totalBytes) * 100) } else { 0 }
            $progressBar.Dispatcher.Invoke([Action]{
                $progressBar.Value = $progressPercent
            })
        }
        $fileStream.Close()
        $stream.Close()
    } finally {
        $httpClient.Dispose()
    }
}

# Helper function to get file version if available
function Get-FileVersion {
    param([string]$Path)
    try {
        return (Get-Item $Path).VersionInfo.FileVersion
    } catch {
        return $null
    }
}

# Helper function to ask user action on existing file
function Ask-UserAction {
    param([string]$message)

    $result = [System.Windows.MessageBox]::Show(
        $message + "`nDelete = Yes, Rename = No, Cancel = Cancel",
        "File Exists",
        [System.Windows.MessageBoxButton]::YesNoCancel,
        [System.Windows.MessageBoxImage]::Question
    )
    return $result
}

# On Download button click
$downloadBtn.Add_Click({
    $downloadBtn.IsEnabled = $false
    $cancelBtn.IsEnabled = $true

    $product = $productBox.SelectedItem
    $version = $versionBox.SelectedItem
    $url = $jsonData.$product.$version
    $savePath = Join-Path $downloadFolder "$product-$version.msi"

    try {
    Write-Host "Starting direct Invoke-WebRequest download..."
    Invoke-WebRequest -Uri $url -OutFile $savePath -UseBasicParsing
    Write-Host "Download completed successfully."
    [System.Windows.MessageBox]::Show("Download completed.`nSaved to: $savePath", "Success", "OK", "Information")
}
catch {
    Write-Host "Download error: $_"
    [System.Windows.MessageBox]::Show("Download failed:`n$($_.Exception.Message)", "Error", "OK", "Error")
}



    if (-not $url) {
        [System.Windows.MessageBox]::Show("Download URL not found for selected product/version.", "Error", "OK", "Error")
        $downloadBtn.IsEnabled = $true
        $cancelBtn.IsEnabled = $false
        return
    }

    $fileName = Split-Path $url -Leaf
    $savePath = Join-Path $downloadFolder $fileName

    $fileExists = Test-Path $savePath -PathType Leaf
    $fileVersion = if ($fileExists) { Get-FileVersion $savePath } else { $null }
    $comparisonVersion = $version

    $proceedDownload = $true

    if ($fileExists) {
        # Basic version comparison logic
        # Note: If MSI file version is empty, user is prompted
        if ($fileVersion -eq $comparisonVersion) {
            [System.Windows.MessageBox]::Show("File already exists with the same version. No need to download.", "Info", "OK", "Information")
            $proceedDownload = $false
        } elseif (-not $fileVersion) {
            $userChoice = Ask-UserAction "Cannot validate the file version."
            switch ($userChoice) {
                'Yes' { Remove-Item $savePath -Force }
                'No'  { Rename-Item $savePath "$savePath.old" }
                default { $proceedDownload = $false }
            }
        } else {
            $msg = ""
            if ($fileVersion -gt $comparisonVersion) {
                $msg = "A newer version exists locally."
            } elseif ($fileVersion -lt $comparisonVersion) {
                $msg = "An older version exists locally."
            }
            $userChoice = Ask-UserAction "$msg`nDo you want to delete, rename, or cancel?"
            switch ($userChoice) {
                'Yes' { Remove-Item $savePath -Force }
                'No'  { Rename-Item $savePath "$savePath.old" }
                default { $proceedDownload = $false }
            }
        }
    }

    if (-not $proceedDownload) {
        $downloadBtn.IsEnabled = $true
        $cancelBtn.IsEnabled = $false
        return
    }

    $cancellationTokenSource = [System.Threading.CancellationTokenSource]::new()

    # Run the download task asynchronously so UI stays responsive
    [System.Threading.Tasks.Task]::Run([Action]{
        try {
            Download-FileAsync -Url $url -Destination $savePath -CancellationToken $cancellationTokenSource.Token
            $window.Dispatcher.Invoke([Action]{
                [System.Windows.MessageBox]::Show("Download completed.`nSaved to: $savePath", "Success", "OK", "Information")
                $progressBar.Value = 0
                $progressBar.Visibility = 'Hidden'
                $downloadBtn.IsEnabled = $true
                $cancelBtn.IsEnabled = $false
            })
        }
        catch [System.OperationCanceledException] {
            $window.Dispatcher.Invoke([Action]{
                [System.Windows.MessageBox]::Show("Download canceled by user.", "Canceled", "OK", "Warning")
                $progressBar.Value = 0
                $progressBar.Visibility = 'Hidden'
                $downloadBtn.IsEnabled = $true
                $cancelBtn.IsEnabled = $false
            })
        }
        catch {
            $window.Dispatcher.Invoke([Action]{
                [System.Windows.MessageBox]::Show("Download failed:`n$($_.Exception.Message)", "Error", "OK", "Error")
                $progressBar.Value = 0
                $progressBar.Visibility = 'Hidden'
                $downloadBtn.IsEnabled = $true
                $cancelBtn.IsEnabled = $false
            })
        }
    })


    $progressBar.Visibility = 'Visible'
})

# On Cancel button click
$cancelBtn.Add_Click({
    if ($cancellationTokenSource) {
        $cancellationTokenSource.Cancel()
        $cancelBtn.IsEnabled = $false
    }
})

# Show window
$window.ShowDialog() | Out-Null
