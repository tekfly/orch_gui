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
$lblAction = New-Object System.Windows.Forms.Label
$lblAction.Text = "Select Action:"
$lblAction.Location = New-Object System.Drawing.Point(20,20)
$lblAction.Size = New-Object System.Drawing.Size(100,20)

$lblProduct = New-Object System.Windows.Forms.Label
$lblProduct.Text = "Select Product:"
$lblProduct.Location = New-Object System.Drawing.Point(20,60)
$lblProduct.Size = New-Object System.Drawing.Size(100,20)

# Dropdowns
$cmbAction = New-Object System.Windows.Forms.ComboBox
$cmbAction.Location = New-Object System.Drawing.Point(130,20)
$cmbAction.Size = New-Object System.Drawing.Size(200,20)
$cmbAction.Items.AddRange(@("install", "download", "connect", "update"))

$cmbProduct = New-Object System.Windows.Forms.ComboBox
$cmbProduct.Location = New-Object System.Drawing.Point(130,60)
$cmbProduct.Size = New-Object System.Drawing.Size(200,20)
$cmbProduct.Items.AddRange(@("robot", "studio", "orchestrator"))

# Checkbox for Chrome
$chkChrome = New-Object System.Windows.Forms.CheckBox
$chkChrome.Text = "Include Google Chrome"
$chkChrome.Location = New-Object System.Drawing.Point(20,100)
$chkChrome.Size = New-Object System.Drawing.Size(200,20)

# Button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Script"
$btnRun.Location = New-Object System.Drawing.Point(130,140)
$btnRun.Size = New-Object System.Drawing.Size(100,30)

$btnRun.Add_Click({
    if (-not (CheckAdmin)) {
        [System.Windows.Forms.MessageBox]::Show("Please run PowerShell as Administrator.","Error","OK","Error")
        return
    }

    $global:gaction = $cmbAction.SelectedItem
    $global:gproduct = $cmbProduct.SelectedItem
    $global:chrome = if ($chkChrome.Checked) { "yes" } else { "no" }

    # Example execution logic
    Write-Host "Chosen Action: $global:gaction"
    Write-Host "Chosen Product: $global:gproduct"
    Write-Host "Include Chrome: $global:chrome"

    # Call your real functions here
    if ($global:gaction -eq "install") {
        if ($global:chrome -eq "yes") {
            download_chrome
            install_chrome
        }
        if ($global:gproduct -eq "robot") {
            down_install_tools
            download_robot
            install_robot
            confirm_certificate_exist
        }
        elseif ($global:gproduct -eq "studio") {
            down_install_tools
            download_robot
            install_studio
            confirm_certificate_exist
        }
        elseif ($global:gproduct -eq "orchestrator") {
            down_install_tools
            download_uipath_ps
            download_url_rewrite
            download_dotnet
            download_orchestrator
            run_uipath_PS
            install_url_rewrite
            install_dotnet
            confirm_certificate_exist
            install_orchestrator
        }
    }
})

# Add controls
$form.Controls.Add($lblAction)
$form.Controls.Add($lblProduct)
$form.Controls.Add($cmbAction)
$form.Controls.Add($cmbProduct)
$form.Controls.Add($chkChrome)
$form.Controls.Add($btnRun)

# Show Form
$form.ShowDialog()
