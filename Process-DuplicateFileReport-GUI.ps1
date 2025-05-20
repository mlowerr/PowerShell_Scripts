Add-Type -AssemblyName System.Windows.Forms

param([string]$ReportFile = "DuplicateFilesReport.txt")
param([string]$DeleteScriptFile = "delete-duplicates-script.txt")


$lines = Get-Content -Path $ReportFile
$deleteCommands = @()
$currentFileGroup = $null
$currentFilePaths = @()

function Show-SelectionDialog {
    param (
        [string]$title,
        [string[]]$options
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size(700,400)
    $form.StartPosition = "CenterScreen"

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Select the file you want to KEEP:"
    $label.AutoSize = $true
    $label.Top = 10
    $label.Left = 10
    $form.Controls.Add($label)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Width = 660
    $listBox.Height = 260
    $listBox.Left = 10
    $listBox.Top = 40
    $listBox.SelectionMode = "One"
    $listBox.Items.AddRange($options)
    $form.Controls.Add($listBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.Anchor = "Bottom,Right"
    $okButton.Top = 310
    $okButton.Left = 590
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    if ($form.ShowDialog() -eq "OK" -and $listBox.SelectedIndex -ge 0) {
        return $listBox.SelectedIndex
    } else {
        return -1
    }
}

foreach ($line in $lines) {
    if ($line.Trim() -eq "" -or $line -match "^Duplicate Files Report") {
        continue
    }

    if ($line -notmatch "^\s") {
        if ($currentFilePaths.Count -gt 1) {
            $title = "$currentFileGroup`nSize: $($currentFileGroup -replace '.*\(Size:\s*(.*?)\)', '$1')"
            $selection = Show-SelectionDialog -title $title -options $currentFilePaths

            if ($selection -ge 0) {
                for ($i = 0; $i -lt $currentFilePaths.Count; $i++) {
                    if ($i -ne $selection) {
                        $deleteCommands += "Remove-Item -LiteralPath `"$($currentFilePaths[$i])`" -Force"
                    }
                }
            }
        }

        $currentFileGroup = $line.Trim()
        $currentFilePaths = @()
    }
    else {
        $currentFilePaths += $line.Trim()
    }
}

# Final group
if ($currentFilePaths.Count -gt 1) {
    $title = "$currentFileGroup`nSize: $($currentFileGroup -replace '.*\(Size:\s*(.*?)\)', '$1')"
    $selection = Show-SelectionDialog -title $title -options $currentFilePaths

    if ($selection -ge 0) {
        for ($i = 0; $i -lt $currentFilePaths.Count; $i++) {
            if ($i -ne $selection) {
                $deleteCommands += "Remove-Item -LiteralPath `"$($currentFilePaths[$i])`" -Force"
            }
        }
    }
}

# Output the deletion script
$deleteCommands | Out-File -FilePath $DeleteScriptFile -Encoding UTF8
[System.Windows.Forms.MessageBox]::Show("Delete script saved to: $DeleteScriptFile", "Done", "OK", "Information")
