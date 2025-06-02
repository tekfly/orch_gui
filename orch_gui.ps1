# Ensure Windows Forms assembly is loaded
Add-Type -AssemblyName System.Windows.Forms

# Global vars
$global:downloadFolder = Join-Path $env:USERPROFILE "Downloads"  # Or wherever your main download folder is
$global:download_folder_software = Join-Path $global:downloadFolder 'Uipath_temp'

# Load JSON data with product versions & URLs
function Load-VersionData {
    $jsonPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'product_versions.json'
    if (-not (Test-Path $jsonPath)) {
        [System.Windows.Forms.MessageBox]::Show("JSON file not found: $jsonPath","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
    $jsonContent = Get-Content $jsonPath -Raw
    try {
        $data = $jsonContent | ConvertFrom-Json
        return $data
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to parse JSON file.`n$_","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
}

# Initialize global version data
$versionData = Load-VersionData

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "UiPath Installer GUI"
$form.Size = New-Object System.Drawing.Size(400,280)
$form.StartPosition = "CenterScreen"

# Product label and combobox
$labelProduct = New-Object System.Windows.Forms.Label
$labelProduct.Location = New-Object System.Drawing.Point(20,20)
$labelProduct.Size = New-Object System.Drawing.Size(100,20)
$labelProduct.Text = "Select Product:"
$form.Controls.Add($labelProduct)

$comboProduct = New-Object System.Windows.Forms.ComboBox
$comboProduct.Location = New-Object System.Drawing.Point(140,20)
$comboProduct.Size = New-Object System.Drawing.Size(200,20)
$comboProduct.DropDownStyle = 'DropDownList'
$form.Controls.Add($comboProduct)

# Version label and combobox
$labelVersion = New-Object System.Windows.Forms.Label
$labelVersion.Location = New-Object System.Drawing.Point(20,60)
$labelVersion.Size = New-Object System.Drawing.Size(100,20)
$labelVersion.Text = "Select Version:"
$form.Controls.Add($labelVersion)

$comboVersion = New-Object System.Windows.Forms.ComboBox
$comboVersion.Location = New-Object System.Drawing.Point(140,60)
$comboVersion.Size = New-Object System.Drawing.Size(200,20)
$comboVersion.DropDownStyle = 'DropDownList'
$form.Controls.Add($comboVersion)

# Action label and combobox
$labelAction = New-Object System.Windows.Forms.Label
$labelAction.Location = New-Object System.Drawing.Point(20,100)
$labelAction.Size = New-Object System.Drawing.Size(100,20)
$labelAction.Text = "Select Action:"
$form.Controls.Add($labelAction)

$comboAction = New-Object System.Windows.Forms.ComboBox
$comboAction.Location = New-Object System.Drawing.Point(140,100)
$comboAction.Size = New-Object System.Drawing.Size(200,20)
$comboAction.DropDownStyle = 'DropDownList'
$form.Controls.Add($comboAction)

# Populate Product ComboBox with keys from JSON
$products = $versionData.PSObject.Properties | ForEach-Object { $_.Name }
$comboProduct.Items.AddRange($products)

# Action options
$actions = @("Download", "Install", "Update")
$comboAction.Items.AddRange($actions)
$comboAction.Enabled = $false  # Disabled until product selected

# Update Versions when Product changes
$comboProduct.Add_SelectedIndexChanged({
    $comboVersion.Items.Clear()
    $selectedProduct = $comboProduct.SelectedItem
    if (-not [string]::IsNullOrEmpty($selectedProduct)) {
        # Enable action dropdown
        $comboAction.Enabled = $true

        # Get version list for the product
        $versionList = @()
        if ($versionData.$selectedProduct) {
            $versionList = $versionData.$selectedProduct.PSObject.Properties | ForEach-Object { $_.Name }
        }
        # Sort versions nicely (optional)
        $sortedVersions = $versionList | Sort-Object {[version]$_} -Descending
        $comboVersion.Items.AddRange($sortedVersions)

        # Select first version by default if available
        if ($comboVersion.Items.Count -gt 0) {
            $comboVersion.SelectedIndex = 0
        }
    }
})

# OK Button
$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Location = New-Object System.Drawing.Point(140,150)
$btnOk.Size = New-Object System.Drawing.Size(75,23)
$btnOk.Text = "Run"
$form.Controls.Add($btnOk)

# Cancel Button
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(265,150)
$btnCancel.Size = New-Object System.Drawing.Size(75,23)
$btnCancel.Text = "Cancel"
$form.Controls.Add($btnCancel)

$btnCancel.Add_Click({ $form.Close() })

# Define the download_robot function
function download_robot {
    # Ensure the software folder exists
    if (-not (Test-Path $global:download_folder_software)) {
        New-Item -ItemType Directory -Path $global:download_folder_software -Force | Out-Null
    }

    $global:down_robot = Join-Path $global:download_folder_software "UiPathStudio.msi"

    if (Test-Path $global:down_robot -PathType Leaf) {
        Write-Host "File (UiPathStudio.msi) already exists - Checking version..." -ForegroundColor Yellow
        $file_exist = $true

        $msiversion = (Get-Item $global:down_robot).VersionInfo.FileVersion
        $comparisonVersion = $global:gversion

        if (-not $msiversion) {
            Write-Host "Cannot validate the MSI version." -ForegroundColor Yellow
            $delete_rename = Read-Host "Delete(d)/Rename(r)/Nothing(n)?"
        }
        elseif ($msiversion -eq $comparisonVersion) {
            Write-Host "File already exists with the same version. Skipping download." -ForegroundColor Green
            return
        }
        else {
            if ([version]$msiversion -gt [version]$comparisonVersion) {
                Write-Host "A newer version exists." -ForegroundColor Yellow
                $delete_rename = Read-Host "Delete(d)/Rename(r)/Nothing(n)?"
            }
            elseif ([version]$msiversion -lt [version]$comparisonVersion) {
                Write-Host "An older version exists." -ForegroundColor Yellow
                $delete_rename = Read-Host "Delete(d)/Rename(r)/Nothing(n)?"
            }
        }

        if ($delete_rename -eq 'd') {
            Remove-Item -Path $global:down_robot -Force
            Write-Host "File deleted. Downloading new version..." -ForegroundColor Green
            download_robot
            return
        }
        elseif ($delete_rename -eq 'r') {
            $newName = "$($global:down_robot).old"
            Rename-Item -Path $global:down_robot -NewName $newName -Force
            Write-Host "File renamed. Downloading new version..." -ForegroundColor Green
            download_robot
            return
        }
        else {
            Write-Host "Keeping existing file. Skipping download." -ForegroundColor Yellow
            return
        }
    }
    else {
        Write-Host "File not found. Starting download..." -ForegroundColor Yellow
        # Get URL from JSON for selected product/version
        $sourceURL = $versionData.'Robot/Studio'[$global:gversion]
        if (-not $sourceURL) {
            Write-Host "Download URL not found for selected version $($global:gversion)." -ForegroundColor Red
            return
        }

        try {
            Invoke-WebRequest -Uri $sourceURL -OutFile $global:down_robot -UseBasicParsing
            Write-Host "File downloaded successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Error downloading file: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
}

# Run Button Click event
$btnOk.Add_Click({
    $global:gproduct = $comboProduct.SelectedItem
    $global:gversion = $comboVersion.SelectedItem
    $global:gaction = $comboAction.SelectedItem

    if (-not $global:gproduct -or -not $global:gversion -or -not $global:gaction) {
        [System.Windows.Forms.MessageBox]::Show("Please select Product, Version, and Action.","Validation",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    Write-Host "Selected Product: $global:gproduct"
    Write-Host "Selected Version: $global:gversion"
    Write-Host "Selected Action: $global:gaction"

    # For demo, just run download_robot if action is Download and product matches
    if ($global:gaction -eq "Download") {
        if ($global:gproduct -eq "Robot/Studio") {
            download_robot
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Download function only implemented for Robot/Studio in this demo.","Info",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    elseif ($global:gaction -eq "Install") {
        # Implement Install logic here
        [System.Windows.Forms.MessageBox]::Show("Install action selected. Not implemented in this demo.","Info")
    }
    elseif ($global:gaction -eq "Update") {
        # Implement Update logic here
        [System.Windows.Forms.MessageBox]::Show("Update action selected. Not implemented in this demo.","Info")
    }
})

# Show form
[void]$form.ShowDialog()
