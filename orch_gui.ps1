Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function CheckAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# GUI Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell GUI Tool"
$form.Size = New-Object System.Drawing.Size(400,300)
$form.StartPosition = "CenterScreen"

# Labels
$lblProduct = New-Object System.Windows.Forms.Label
$lblProduct.Text = "Select Product:"
$lblProduct.Location = New-Object System.Drawing.Point(20,20)
$lblProduct.Size = New-Object System.Drawing.Size(100,20)

$lblAction = New-Object System.Windows.Forms.Label
$lblAction.Text = "Select Action:"
$lblAction.Location = New-Object System.Drawing.Point(20,60)
$lblAction.Size = New-Object System.Drawing.Size(100,20)
$lblAction.Visible = $false

# Product Dropdown
$cmbProduct = New-Object System.Windows.Forms.ComboBox
$cmbProduct.Location = New-Object System.Drawing.Point(130,20)
$cmbProduct.Size = New-Object System.Drawing.Size(200,20)
$cmbProduct.DropDownStyle = 'DropDownList'
$cmbProduct.Items.AddRange(@("robot", "studio", "orchestrator"))

# Action Dropdown
$cmbAction = New-Object System.Windows.Forms.ComboBox
$cmbAction.Location = New-Object System.Drawing.Point(130,60)
$cmbAction.Size = New-Object System.Drawing.Size(200,20)
$cmbAction.DropDownStyle = 'DropDownList'
$cmbAction.Visible = $false

# Checkbox for Chrome
$chkChrome = New-Object System.Windows.Forms.CheckBox
$chkChrome.Text = "Include Google Chrome"
$chkChrome.Location = New-Object System.Drawing.Point(20,100)
$chkChrome.Size = New-Object System.Drawing.Size(200,20)

# Run Button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Script"
$btnRun.Location = New-Object System.Drawing.Point(130,140)
$btnRun.Size = New-Object System.Drawing.Size(100,30)

# When product is selected, show action dropdown and populate it
$cmbProduct.Add_SelectedIndexChanged({
    $selectedProduct = $cmbProduct.SelectedItem
    $cmbAction.Items.Clear()

    if ($selectedProduct -eq "orchestrator") {
        $cmbAction.Items.AddRange(@("install", "download", "update"))  # exclude 'connect'
    } else {
        $cmbAction.Items.AddRange(@("install", "download", "connect", "update"))
    }

    $cmbAction.SelectedIndex = 0
    $cmbAction.Visible = $true
    $lblAction.Visible = $true
})

# Run button logic
$btnRun.Add_Click({
    if (-not (CheckAdmin)) {
        [System.Windows.Forms.MessageBox]::Show("Please run PowerShell as Administrator.","Error","OK","Error")
        return
    }

    $global:gaction = $cmbAction.SelectedItem
    $global:gproduct = $cmbProduct.SelectedItem
    $global:chrome = if ($chkChrome.Checked) { "yes" } else { "no" }

    Write-Host "Chosen Action: $global:gaction"
    Write-Host "Chosen Product: $global:gproduct"
    Write-Host "Include Chrome: $global:chrome"

    # Insert your real logic here
})

# Add controls
$form.Controls.Add($lblProduct)
$form.Controls.Add($cmbProduct)
$form.Controls.Add($lblAction)
$form.Controls.Add($cmbAction)
$form.Controls.Add($chkChrome)
$form.Controls.Add($btnRun)

# Show Form
$form.ShowDialog()
