Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function CheckAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# === Paths ===
$downloadFolder = Join-Path "$env:USERPROFILE\Downloads" "UiPath_temp"
if (-not (Test-Path $downloadFolder)) {
    New-Item -Path $downloadFolder -ItemType Directory | Out-Null
}

$versionFile = Join-Path $downloadFolder "product_versions.json"
$remoteJsonUrl = "https://raw.githubusercontent.com/your-username/your-repo/main/product_versions.json"

function Update-VersionFile {
    try {
        Invoke-WebRequest -Uri $remoteJsonUrl -OutFile $versionFile -UseBasicParsing
        Write-Host "Updated local version file from remote source." -ForegroundColor Green
        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to download version info from:`n$remoteJsonUrl", "Error", "OK", "Error")
        return $false
    }
}

# Auto-update JSON if missing or outdated
if (-not (Test-Path $versionFile) -or ((Get-Item $versionFile).LastWriteTime -lt (Get-Date).AddDays(-1))) {
    Write-Host "Version file missing or outdated. Downloading..."
    $ok = Update-VersionFile
    if (-not $ok) { exit }
}

# Load JSON
$jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json

# === GUI Setup ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "UiPath Installation Tool"
$form.Size = New-Object System.Drawing.Size(450, 300)
$form.StartPosition = "CenterScreen"

# Product Label
$lblProduct = New-Object System.Windows.Forms.Label
$lblProduct.Text = "Select Product:"
$lblProduct.Location = New-Object System.Drawing.Point(20, 20)
$lblProduct.Size = New-Object System.Drawing.Size(100, 20)

# Product Dropdown
$cmbProduct = New-Object System.Windows.Forms.ComboBox
$cmbProduct.Location = New-Object System.Drawing.Point(130, 20)
$cmbProduct.Size = New-Object System.Drawing.Size(280, 20)
$cmbProduct.DropDownStyle = 'DropDownList'
$cmbProduct.Items.AddRange(@("robot", "studio", "orchestrator"))

# Version Label
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "Select Version:"
$lblVersion.Location = New-Object System.Drawing.Point(20, 60)
$lblVersion.Size = New-Object System.Drawing.Size(100, 20)
$lblVersion.Visible = $false

# Version Dropdown
$cmbVersion = New-Object System.Windows.Forms.ComboBox
$cmbVersion.Location = New-Object System.Drawing.Point(130, 60)
$cmbVersion.Size = New-Object System.Drawing.Size(280, 20)
$cmbVersion.DropDownStyle = 'DropDownList'
$cmbVersion.Visible = $false

# Action Label
$lblAction = New-Object System.Windows.Forms.Label
$lblAction.Text = "Select Action:"
$lblAction.Location = New-Object System.Drawing.Point(20, 100)
$lblAction.Size = New-Object System.Drawing.Size(100, 20)
$lblAction.Visible = $false

# Action Dropdown
$cmbAction = New-Object System.Windows.Forms.ComboBox
$cmbAction.Location = New-Object System.Drawing.Point(130, 100)
$cmbAction.Size = New-Object System.Drawing.Size(280, 20)
$cmbAction.DropDownStyle = 'DropDownList'
$cmbAction.Visible = $false

# Manual Refresh Button
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh Versions"
$btnRefresh.Location = New-Object System.Drawing.Point(20, 140)
$btnRefresh.Size = New-Object System.Drawing.Size(130, 30)

# Submit Button
$btnSubmit = New-Object System.Windows.Forms.Button
$btnSubmit.Text = "Submit"
$btnSubmit.Location = New-Object System.Drawing.Point(280, 200)
$btnSubmit.Size = New-Object System.Drawing.Size(130, 40)

# === Events ===

# On Product Select
$cmbProduct.Add_SelectedIndexChanged({
    $cmbVersion.Items.Clear()
    $cmbAction.Items.Clear()
    $selectedProduct = $cmbProduct.SelectedItem

    if ($selectedProduct) {
        $versions = $jsonData.$selectedProduct.PSObject.Properties.Name
        $cmbVersion.Items.AddRange($versions)
        $cmbVersion.Visible = $true
        $lblVersion.Visible = $true

        $actions = @("install", "download", "update")
        if ($selectedProduct -ne "orchestrator") {
            $actions += "connect"
        }
        $cmbAction.Items.AddRange($actions)
        $cmbAction.Visible = $true
        $lblAction.Visible = $true
    }
})

# Manual Refresh
$btnRefresh.Add_Click({
    if (Update-VersionFile) {
        $jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json
        [System.Windows.Forms.MessageBox]::Show("Version data refreshed.", "Info", "OK", "Information")
    }
})

# On Submit
$btnSubmit.Add_Click({
    $product = $cmbProduct.SelectedItem
    $version = $cmbVersion.SelectedItem
    $action = $cmbAction.SelectedItem

    if (-not $product -or -not $version -or -not $action) {
        [System.Windows.Forms.MessageBox]::Show("Please select all options.", "Missing Info", "OK", "Warning")
        return
    }

    $url = $jsonData.$product.$version
    $summary = "Product: $product`nVersion: $version`nAction: $action`nURL: $url"
    [System.Windows.Forms.MessageBox]::Show($summary, "Selected Options", "OK", "Information")

    # Save to file in UiPath_temp
    $logPath = Join-Path $downloadFolder "selection_log.txt"
    $summary | Out-File -FilePath $logPath -Encoding UTF8 -Append
})

# === Add to Form ===
$form.Controls.AddRange(@(
    $lblProduct, $cmbProduct,
    $lblVersion, $cmbVersion,
    $lblAction, $cmbAction,
    $btnSubmit, $btnRefresh
))

# === Show Form ===
[void]$form.ShowDialog()
