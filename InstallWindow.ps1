Add-Type -AssemblyName PresentationFramework

$downloadFolder = Join-Path $env:USERPROFILE "Downloads\UiPath_temp"
$files = Get-ChildItem -Path $downloadFolder -File | Sort-Object Name

if ($files.Count -eq 0) {
    [System.Windows.MessageBox]::Show("No files found in:`n$downloadFolder", "No files", "OK", "Information")
    exit
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Install UiPath Components" Height="350" Width="450" WindowStartupLocation="CenterScreen" >
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Text="Select files to install:" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
        
        <ListBox Name="FilesListBox" Grid.Row="1" SelectionMode="Extended" />

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="InstallBtn" Content="Install" Width="100" Margin="0,0,10,0" IsEnabled="False"/>
            <Button Name="CancelBtn" Content="Cancel" Width="100"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$filesListBox = $window.FindName("FilesListBox")
$installBtn = $window.FindName("InstallBtn")
$cancelBtn = $window.FindName("CancelBtn")

foreach ($file in $files) {
    $filesListBox.Items.Add($file.Name) | Out-Null
}

$filesListBox.Add_SelectionChanged({
    $installBtn.IsEnabled = ($filesListBox.SelectedItems.Count -gt 0)
})

# Helper function to prompt user Studio or Robot choice
function Prompt-StudioOrRobot {
    $msg = "Selected file looks like a Studio installer.`nPlease choose what to install:"
    $result = [System.Windows.MessageBox]::Show($msg, "Choose Install Type", [System.Windows.MessageBoxButton]::YesNoCancel, [System.Windows.MessageBoxImage]::Question)

    # Map buttons: Yes = Studio, No = Robot, Cancel = Cancel
    switch ($result) {
        'Yes' { return "Studio" }
        'No'  { return "Robot" }
        default { return $null }
    }
}

$installBtn.Add_Click({
    foreach ($selected in $filesListBox.SelectedItems) {
        $fullPath = Join-Path $downloadFolder $selected

        # If file starts with "Studio-" (case insensitive)
        if ($selected -match '^Studio-') {
            $choice = Prompt-StudioOrRobot
            if (-not $choice) {
                # User cancelled, skip this file
                continue
            }

            # For demonstration, show choice message, replace with your logic
            [System.Windows.MessageBox]::Show("Installing $choice from file:`n$selected", "Info", "OK", "Information")
            
            # Start-Process example: you can pass arguments or handle differently
            # Start-Process -FilePath $fullPath -ArgumentList "/installType=$choice" -Verb RunAs
            # (Uncomment and adjust above line if your installer supports arguments)
        } else {
            # For other files, just launch as usual
            try {
                Start-Process -FilePath $fullPath -Verb RunAs
            }
            catch {
                [System.Windows.MessageBox]::Show("Failed to start installer:`n$selected`n$($_.Exception.Message)", "Error", "OK", "Error")
            }
        }
    }
})

$cancelBtn.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null
