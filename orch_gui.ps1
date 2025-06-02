Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function CheckAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Load version data from JSON file
$versionFile = "product_versions.json"
if (-not (Test-Path $versionFile)) {
    [System.Windows.Forms.MessageBox]::Show("Missing file: $versionFile", "Error", "OK", "Error")
    exit
}

$jsonData = Get-Content $versionFile -Raw | ConvertFrom-Json

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell GUI Tool"
$form.Size = New-Object System.Drawing.Size(420, 300)
$form.StartPosition = "CenterScreen"

# Label - Product
$lblProduct = New-Object System.Windows.Forms.Label
$lblProduct.Text = "Select Product:"
$lblProduct.Location = New-Object System.Drawing.Point(20, 20)
$lblProduct.Size = New-Object System.Drawing.Size(100, 20)

# Dropdown - Product
$cmbProduct = New-Object System.Windows.Forms.ComboBox
$cmbProduct.Location = New-Object System.Drawing.Point(130, 20)
$cmbProduct.Size = New-Object System.Drawing.Size(250, 20)
$cmbProduct.DropDownStyle = 'DropDownList'
$cmbProduct.Items.AddRange(@("robot", "studio", "orchestrator"))

# Label - Version
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "Select Version:"
$lblVersion.Location = New-Object System.Drawing.Point(20, 60)
$lblVersion.Size = New-Object System.Drawing.Size(100, 20)
$lblVersion.Visible = $false

# Dropdown - Version
$cmbVersion = New-Object System.Windows.Forms.ComboBox
$cmbVersion.Location = New-Object System.Drawing.Point(130, 60)
$cmbVersion.Size = New-Object System.Drawing.Size(250, 20)
$cmbVersion.DropDownStyle = 'DropDownList'
$cmbVersion.Visible = $false

# Label - Action
$lblAction = New-Object System.Windows.Forms.Label
$lblAction.Text = "Select Action:"
$lblAction.Location = New-Object System.Drawing.Point(20, 100)
$lblAction.Size = New-Object System.Drawing.Size(100, 20)
$lblAction.Visible = $false

# Dropdown - Action
$cmbAction = New-Object System.Windows.Forms.ComboBox
$cmbAction.Location = New-Object System.Drawing.Point(130, 100)
$cmbAction.Size = New-Object System.Drawing.Size(250, 20)
$cmbAction.DropDownStyle = 'DropDownList'
$cmbAction.Visible = $false

# Checkbox - Chrome
$chkChrome = New-Object System.Windows.Forms.CheckBox
$chkChrome.Text = "Include Google Chrome"
$chkChrome.Location = New-Object System.Drawing.Point(20, 140)
$chkChrome.Size = New-Object System.Drawing.Size(200, 20)

# Button - Run Script
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Script"
$btnRun.Location = New-Object System.Drawing.Point(150, 180)
$btnRun.Size = New-Object System.Drawing.Size(100, 30)

# Event - Product Selection
$cmbProduct.Add_SelectedIndexChanged({
    $selectedProduct = $cmbProduct.SelectedItem

    # Populate version dropdown
    $cmbVersion.Items.Clear()
    if ($jsonData.$selectedProduct) {
        $jsonData.$selectedProduct.PSObject.Properties.Name | ForEach-Object {
            $cmbVersion.Items.Add($_)
        }
        $cmbVersion.SelectedIndex = 0
        $cmbVersion.Visible = $true
        $lblVersion.Visible = $true
    }

    # Populate action dropdown
    $cmbAction.Items.Clear()
    if ($selectedProduct -eq "orchestrator") {
        $cmbAction.Items.AddRange(@("install", "download", "update"))
    } else {
        $cmbAction.Items.AddRange(@("install", "download", "connect", "update"))
    }

    $cmbAction.SelectedIndex = 0
    $cmbAction.Visible = $true
    $lblAction.Visible = $true
})

# Event - Run Button Click
$btnRun.Add_Click({
    if (-not (CheckAdmin)) {
        [System.Windows.Forms.MessageBox]::Show("Please run PowerShell as Administrator.", "Error", "OK", "Error")
        return
    }

    $global:gproduct = $cmbProduct.SelectedItem
    $global:version = $cmbVersion.SelectedItem
    $global:gaction = $cmbAction.SelectedItem
    $global:chrome = if ($chkChrome.Checked) { "yes" } else { "no" }

    $url = $jsonData.$global:gproduct.$global:version

    # Simulate logic (replace with your real functions)
    Write-Host "Product: $global:gproduct"
    Write-Host "Version: $global:version"
    Write-Host "Action: $global:gaction"
    Write-Host "Include Chrome: $global:chrome"
    Write-Host "Download URL: $url"

    [System.Windows.Forms.MessageBox]::Show("Action: $global:gaction`nProduct: $global:gproduct`nVersion: $global:version`nURL: $url", "Confirmation", "OK", "Information")
})

# Add Controls to Form
$form.Controls.Add($lblProduct)
$form.Controls.Add($cmbProduct)
$form.Controls.Add($lblVersion)
$form.Controls.Add($cmbVersion)
$form.Controls.Add($lblAction)
$form.Controls.Add($cmbAction)
$form.Controls.Add($chkChrome)
$form.Controls.Add($btnRun)

# Run the Form
$form.ShowDialog()
