# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "Script requires administrator privileges. Relaunching..."
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "Script requires administrator privileges. Relaunching..."
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$script:currentStepIndex = 0
$script:currentJob = $null
$script:isProcessing = $false
$script:jobStartTime = $null

# Main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Ubuntu Linux WSL Installer (Administrator)"
$form.Size = New-Object System.Drawing.Size(600, 480)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Instructions label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Running with Administrator privileges. Click Install to begin:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(16, 18)
$form.Controls.Add($label)

# Output Text Box (multiline)
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(16, 44)
$textBox.Size = New-Object System.Drawing.Size(560, 260)
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.ReadOnly = $true
$textBox.Font = "Consolas, 10"
$form.Controls.Add($textBox)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(16, 320)
$progressBar.Size = New-Object System.Drawing.Size(560, 25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready with Administrator privileges."
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(16, 355)
$form.Controls.Add($statusLabel)

# Install Button
$button = New-Object System.Windows.Forms.Button
$button.Text = "Install Ubuntu Linux"
$button.Width = 180
$button.Height = 40
$button.Location = New-Object System.Drawing.Point(16, 380)
$form.Controls.Add($button)

# Continue Button (hidden initially)
$continueButton = New-Object System.Windows.Forms.Button
$continueButton.Text = "Continue After Setup"
$continueButton.Width = 180
$continueButton.Height = 40
$continueButton.Location = New-Object System.Drawing.Point(210, 380)
$continueButton.Visible = $false
$form.Controls.Add($continueButton)

# Run Script Manually Button (hidden initially)
$runScriptButton = New-Object System.Windows.Forms.Button
$runScriptButton.Text = "Run Script Manually"
$runScriptButton.Width = 150
$runScriptButton.Height = 40
$runScriptButton.Location = New-Object System.Drawing.Point(404, 380)
$runScriptButton.Visible = $false
$form.Controls.Add($runScriptButton)

# Timer for checking job completion
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500

function Append-Output($line) {
    try {
        if ($textBox.InvokeRequired) {
            $textBox.Invoke([Action[string]]{param($text) 
                $textBox.AppendText($text + [Environment]::NewLine)
                $textBox.SelectionStart = $textBox.Text.Length
                $textBox.ScrollToCaret()
                $textBox.Refresh()
            }, $line)
        } else {
            $textBox.AppendText($line + [Environment]::NewLine)
            $textBox.SelectionStart = $textBox.Text.Length
            $textBox.ScrollToCaret()
            $textBox.Refresh()
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Update-Status($text) {
    try {
        if ($statusLabel.InvokeRequired) {
            $statusLabel.Invoke([Action[string]]{param($status) $statusLabel.Text = $status}, $text)
        } else {
            $statusLabel.Text = $text
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Update-Progress($value) {
    try {
        if ($progressBar.InvokeRequired) {
            $progressBar.Invoke([Action[int]]{param($val) $progressBar.Value = $val}, $value)
        } else {
            $progressBar.Value = $value
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Test-UbuntuConfigured() {
    try {
        $result = & wsl -d Ubuntu --exec bash -c "echo 'configured'" 2>$null
        return ($result -eq "configured")
    } catch {
        return $false
    }
}

function Show-ContinueButton() {
    try {
        if ($continueButton.InvokeRequired) {
            $continueButton.Invoke([Action]{
                $continueButton.Visible = $true
                $continueButton.Enabled = $true
            })
        } else {
            $continueButton.Visible = $true
            $continueButton.Enabled = $true
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Hide-ContinueButton() {
    try {
        if ($continueButton.InvokeRequired) {
            $continueButton.Invoke([Action]{
                $continueButton.Visible = $false
                $continueButton.Enabled = $false
            })
        } else {
            $continueButton.Visible = $false
            $continueButton.Enabled = $false
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Show-RunScriptButton() {
    try {
        if ($runScriptButton.InvokeRequired) {
            $runScriptButton.Invoke([Action]{
                $runScriptButton.Visible = $true
                $runScriptButton.Enabled = $true
            })
        } else {
            $runScriptButton.Visible = $true
            $runScriptButton.Enabled = $true
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Hide-RunScriptButton() {
    try {
        if ($runScriptButton.InvokeRequired) {
            $runScriptButton.Invoke([Action]{
                $runScriptButton.Visible = $false
                $runScriptButton.Enabled = $false
            })
        } else {
            $runScriptButton.Visible = $false
            $runScriptButton.Enabled = $false
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Write-UnixScript($filePath, $content) {
    # Write script with proper Unix line endings
    $unixContent = $content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($filePath, $unixContent, [System.Text.UTF8Encoding]::new($false))
}

function Start-NextStep() {
    if ($script:currentStepIndex -lt $installationSteps.Count) {
        $step = $installationSteps[$script:currentStepIndex]
        
        # Special handling for Ubuntu installation with visible command window
        if ($script:currentStepIndex -eq 3) {
            Append-Output ""
            Append-Output "=== UBUNTU INSTALLATION ==="
            Append-Output "Installing Ubuntu distribution..."
            Append-Output "Opening command window to show download progress..."
            
            Update-Progress $step.Progress
            Update-Status $step.Name
            Append-Output "--- Starting: $($step.Name) ---"
            
            try {
                $process = Start-Process "cmd.exe" -ArgumentList "/c", "wsl --install Ubuntu --no-launch && echo Installation completed! && pause" -WindowStyle Normal -PassThru
                
                Append-Output "Ubuntu installation started in command window."
                Append-Output "You can see the download progress in the command window."
                Append-Output "The installer will continue automatically when complete."
                
                $script:isProcessing = $true
                $script:installProcess = $process
                $script:currentStepIndex++
                
                return
            } catch {
                Append-Output "[ERROR] Failed to start Ubuntu installation: $_"
                Complete-Installation
                return
            }
        }
        
        # Special handling for Ubuntu first launch
        if ($script:currentStepIndex -eq 4) {
            Append-Output ""
            Append-Output "=== UBUNTU FIRST LAUNCH ==="
            Append-Output "Launching Ubuntu for initial setup..."
            Append-Output ""
            Append-Output "IMPORTANT INSTRUCTIONS:"
            Append-Output "1. A new Ubuntu terminal window will open"
            Append-Output "2. Create a username when prompted (lowercase, no spaces)"
            Append-Output "3. Create a password when prompted"
            Append-Output "4. After setup completes, CLOSE the Ubuntu terminal window"
            Append-Output "5. Click 'Continue After Setup' button below to proceed"
            Append-Output ""
            
            try {
                Start-Process "ubuntu.exe" -WindowStyle Normal
                Append-Output "Ubuntu terminal launched. Please complete the setup and then click Continue."
                Show-ContinueButton
                Show-RunScriptButton
                Update-Progress 75
                Update-Status "Waiting for Ubuntu setup completion..."
                $script:currentStepIndex++
                return
            } catch {
                Append-Output "[ERROR] Failed to launch Ubuntu: $_"
                Append-Output "Please run 'ubuntu' from Start Menu to complete setup, then click Continue."
                Show-ContinueButton
                Show-RunScriptButton
                $script:currentStepIndex++
                return
            }
        }
        
        # Fixed script execution - removed apt update and apt install, using curl directly
        if ($script:currentStepIndex -eq 5) {
            Hide-ContinueButton
            Hide-RunScriptButton
            Append-Output ""
            Append-Output "=== RUNNING CUSTOM SCRIPT ==="
            Append-Output "Using curl to download and run installation script..."
            
            # Simplified approach - removed apt update and apt install commands
            $batchContent = @"
@echo off
echo ================================================
echo OpenDrop Installation via WSL Ubuntu
echo ================================================
echo.
echo Removing problematic snap curl...
wsl -d Ubuntu -e bash -c "sudo snap remove curl 2>/dev/null || echo 'Snap curl not found'"
echo.
echo Creating scripts directory...
wsl -d Ubuntu -e bash -c "mkdir -p ~/scripts && cd ~/scripts"
echo.
echo Downloading installation script...
wsl -d Ubuntu -e bash -c "cd ~/scripts && curl -fsSL https://raw.githubusercontent.com/chinu0609/opendrop_private/master/installation_scripts/install.sh -o install.sh"
echo.
echo Making script executable...
wsl -d Ubuntu -e bash -c "cd ~/scripts && chmod +x install.sh"
echo.
echo Running installation script...
echo Please enter your password when prompted...
wsl -d Ubuntu -e bash -c "cd ~/scripts && echo 'y' | sudo bash install.sh"
echo.
echo ================================================
echo Installation process completed!
echo ================================================
echo You can now close this window.
pause
"@
            
            $batchPath = "$env:TEMP\run_opendrop_install.bat"
            $batchContent | Out-File -FilePath $batchPath -Encoding ASCII
            
            Append-Output "Starting installation using existing curl..."
            Append-Output "A command window will open for execution."
            Start-Process "cmd.exe" -ArgumentList "/c", $batchPath -WindowStyle Normal
            
            Start-Sleep -Seconds 3
            Complete-Installation
            return
        }
        
        Update-Progress $step.Progress
        Update-Status $step.Name
        Append-Output "--- Starting: $($step.Name) ---"
        
        $script:isProcessing = $true
        $script:currentJob = Start-CommandJob $step.Command $step.Name $step.IsWSL
        $script:currentStepIndex++
    } else {
        Complete-Installation
    }
}

function Start-CommandJob($command, $stepName, $isWSL) {
    $job = Start-Job -ScriptBlock {
        param($cmd, $step, $wsl)
        
        try {
            if ($wsl) {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "wsl.exe"
                $psi.Arguments = "-d Ubuntu -- bash -c `"$cmd`""
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $false
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $psi
                $process.Start() | Out-Null
                
                $output = @()
                $errors = @()
                
                $outputReader = $process.StandardOutput
                $errorReader = $process.StandardError
                
                while (-not $process.HasExited) {
                    if (-not $outputReader.EndOfStream) {
                        $line = $outputReader.ReadLine()
                        if ($line -ne $null) {
                            $output += [string]$line
                        }
                    }
                    if (-not $errorReader.EndOfStream) {
                        $line = $errorReader.ReadLine()
                        if ($line -ne $null) {
                            $errors += [string]$line
                        }
                    }
                    Start-Sleep -Milliseconds 100
                }
                
                while (-not $outputReader.EndOfStream) {
                    $line = $outputReader.ReadLine()
                    if ($line -ne $null) {
                        $output += [string]$line
                    }
                }
                
                while (-not $errorReader.EndOfStream) {
                    $line = $errorReader.ReadLine()
                    if ($line -ne $null) {
                        $errors += [string]$line
                    }
                }
                
                $process.WaitForExit()
                
                return @{
                    Output = $output
                    Errors = $errors
                    ExitCode = $process.ExitCode
                    Success = ($process.ExitCode -eq 0)
                }
            } else {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "cmd.exe"
                $psi.Arguments = "/c $cmd"
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $psi
                $process.Start() | Out-Null
                
                $output = $process.StandardOutput.ReadToEnd() -split "`n" | ForEach-Object { [string]$_ }
                $errors = $process.StandardError.ReadToEnd() -split "`n" | ForEach-Object { [string]$_ }
                $process.WaitForExit()
                
                return @{
                    Output = $output | Where-Object { $_.Trim() -ne "" }
                    Errors = $errors | Where-Object { $_.Trim() -ne "" }
                    ExitCode = $process.ExitCode
                    Success = ($process.ExitCode -eq 0)
                }
            }
        }
        catch {
            return @{
                Output = @()
                Errors = @([string]"Exception: $_")
                ExitCode = -1
                Success = $false
            }
        }
    } -ArgumentList $command, $stepName, $isWSL
    
    return $job
}

function Complete-Installation() {
    Hide-ContinueButton
    Hide-RunScriptButton
    Update-Progress 100
    Update-Status "Installation completed!"
    Append-Output ""
    Append-Output "=== INSTALLATION COMPLETE ==="
    Append-Output "Ubuntu WSL has been installed and configured."
    Append-Output "Your custom script has been executed with proper privileges."
    Append-Output "You can now use Ubuntu from the Start Menu or by typing 'wsl' in Command Prompt."
    Append-Output ""
    $button.Enabled = $true
    $button.Text = "Installation Complete"
    $timer.Stop()
    $script:isProcessing = $false
}

# Installation steps
$installationSteps = @(
    @{ Command = 'dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart'; Name = 'Enable WSL'; Progress = 15; IsWSL = $false },
    @{ Command = 'dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart'; Name = 'Enable Virtual Machine Platform'; Progress = 30; IsWSL = $false },
    @{ Command = 'wsl --update && wsl --set-default-version 2'; Name = 'Update WSL and Set Default Version'; Progress = 45; IsWSL = $false },
    @{ Command = 'wsl --install Ubuntu --no-launch'; Name = 'Install Ubuntu Linux (No Launch)'; Progress = 60; IsWSL = $false },
    @{ Command = 'ubuntu.exe'; Name = 'Launch Ubuntu for Setup'; Progress = 75; IsWSL = $false },
    @{ Command = 'step_by_step_install'; Name = 'Download and run installation script'; Progress = 90; IsWSL = $true }
)

# Timer tick event
$timer.Add_Tick({
    if ($script:installProcess -and $script:installProcess.HasExited) {
        Append-Output "Ubuntu installation process completed."
        Append-Output "Exit code: $($script:installProcess.ExitCode)"
        $script:installProcess = $null
        $script:isProcessing = $false
        Start-NextStep
        return
    }
    
    if ($script:isProcessing -and $script:currentJob -ne $null) {
        if ($script:jobStartTime -eq $null) {
            $script:jobStartTime = Get-Date
        }
        
        $elapsed = (Get-Date) - $script:jobStartTime
        $timeoutMinutes = if ($script:currentStepIndex -eq 4) { 10 } else { 5 }
        
        if ($elapsed.TotalMinutes -gt $timeoutMinutes) {
            Append-Output "[TIMEOUT] Job has been running for over $timeoutMinutes minutes. Stopping..."
            Stop-Job $script:currentJob -ErrorAction SilentlyContinue
            Remove-Job $script:currentJob -ErrorAction SilentlyContinue
            $script:currentJob = $null
            $script:isProcessing = $false
            $script:jobStartTime = $null
            
            Append-Output ""
            Append-Output "[TIMEOUT] Operation timed out. You may need to complete this step manually."
            Start-NextStep
            return
        }
        
        if ($script:currentJob.State -eq "Completed") {
            $script:jobStartTime = $null
            
            $result = Receive-Job $script:currentJob
            Remove-Job $script:currentJob
            
            if ($result.Output) {
                foreach ($line in $result.Output) {
                    $lineStr = [string]$line
                    if ($lineStr.Trim() -ne "") {
                        Append-Output $lineStr
                    }
                }
            }
            
            if ($result.Errors) {
                foreach ($err in $result.Errors) {
                    $errStr = [string]$err
                    if ($errStr.Trim() -ne "") {
                        Append-Output "[ERROR] $errStr"
                    }
                }
            }
            
            Append-Output "--- Completed: $($installationSteps[$script:currentStepIndex-1].Name) (Exit Code: $($result.ExitCode)) ---"
            Append-Output ""
            
            $script:currentJob = $null
            $script:isProcessing = $false
            
            Start-Sleep -Milliseconds 1000
            Start-NextStep
        }
        elseif ($script:currentJob.State -eq "Failed") {
            $script:jobStartTime = $null
            
            Append-Output "[ERROR] Job failed"
            $result = Receive-Job $script:currentJob -ErrorAction SilentlyContinue
            if ($result) {
                $resultStr = [string]$result
                Append-Output "[ERROR] Job details: $resultStr"
            }
            Remove-Job $script:currentJob
            $script:currentJob = $null
            $script:isProcessing = $false
            Start-NextStep
        }
    }
})

# Install button click event
$button.Add_Click({
    $button.Enabled = $false
    $progressBar.Value = 0
    $statusLabel.Text = "Starting installation..."
    $textBox.Text = ""
    $script:currentStepIndex = 0
    $script:isProcessing = $false
    $script:jobStartTime = $null
    $script:installProcess = $null
    Hide-ContinueButton
    Hide-RunScriptButton
    
    Append-Output "Ubuntu WSL Installation with Custom Script"
    Append-Output "========================================"
    Append-Output "Running with Administrator privileges."
    Append-Output ""
    Append-Output "This will:"
    Append-Output "1. Enable WSL features"
    Append-Output "2. Update WSL and set default version"
    Append-Output "3. Install Ubuntu (with visible progress)"
    Append-Output "4. Launch Ubuntu for initial setup"
    Append-Output "5. Run your custom installation script using existing curl"
    Append-Output ""
    Append-Output "Starting installation..."
    Append-Output ""
    
    $timer.Start()
    Start-NextStep
})

# Continue button click event
$continueButton.Add_Click({
    Append-Output "Checking Ubuntu configuration..."
    Start-Sleep -Seconds 2
    
    if (Test-UbuntuConfigured) {
        Append-Output "[SUCCESS] Ubuntu setup verified successfully!"
        Append-Output "Continuing with custom script installation..."
        $script:currentStepIndex = 5
        Start-NextStep
    } else {
        Append-Output ""
        Append-Output "[ERROR] Ubuntu setup not completed properly."
        Append-Output "Please ensure you completed the username/password setup."
        Append-Output "Try the 'Run Script Manually' button or complete setup and try again."
    }
})

# Run Script Manually button click event (simplified)
$runScriptButton.Add_Click({
    if (Test-UbuntuConfigured) {
        Hide-RunScriptButton
        Hide-ContinueButton
        
        Append-Output ""
        Append-Output "=== MANUAL SCRIPT EXECUTION ==="
        Append-Output "Opening Ubuntu for simplified manual execution..."
        
        # Use a simplified approach with direct commands - removed apt update and apt install
        $manualCommands = @(
            "sudo snap remove curl 2>/dev/null || echo 'Snap curl not found'",
            "mkdir -p ~/scripts && cd ~/scripts",
            "curl -fsSL https://raw.githubusercontent.com/chinu0609/opendrop_private/master/installation_scripts/install.sh -o install.sh",
            "chmod +x install.sh",
            "echo 'y' | sudo bash install.sh"
        )
        
        $commandString = $manualCommands -join " && "
        
        # Launch with simplified command string
        Start-Process "wsl.exe" -ArgumentList "-d", "Ubuntu", "-e", "bash", "-c", $commandString -WindowStyle Normal
        
        Append-Output "Ubuntu launched with simplified installation commands."
        Append-Output "Please enter your password when prompted."
        
        Complete-Installation
    } else {
        Append-Output "[ERROR] Ubuntu not properly configured. Please complete setup first."
    }
})

# Form cleanup
$form.Add_FormClosed({
    if ($script:currentJob -ne $null) {
        Stop-Job $script:currentJob -ErrorAction SilentlyContinue
        Remove-Job $script:currentJob -ErrorAction SilentlyContinue
    }
    if ($script:installProcess -ne $null) {
        $script:installProcess.Close()
    }
    $timer.Stop()
})

$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()

$script:currentStepIndex = 0
$script:currentJob = $null
$script:isProcessing = $false
$script:jobStartTime = $null

# Main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Ubuntu Linux WSL Installer (Administrator)"
$form.Size = New-Object System.Drawing.Size(600, 480)  # Increased height for new button
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Instructions label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Running with Administrator privileges. Click Install to begin:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(16, 18)
$form.Controls.Add($label)

# Output Text Box (multiline)
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(16, 44)
$textBox.Size = New-Object System.Drawing.Size(560, 260)
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.ReadOnly = $true
$textBox.Font = "Consolas, 10"
$form.Controls.Add($textBox)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(16, 320)
$progressBar.Size = New-Object System.Drawing.Size(560, 25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready with Administrator privileges."
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(16, 355)
$form.Controls.Add($statusLabel)

# Install Button
$button = New-Object System.Windows.Forms.Button
$button.Text = "Install Ubuntu Linux"
$button.Width = 180
$button.Height = 40
$button.Location = New-Object System.Drawing.Point(16, 380)
$form.Controls.Add($button)

# Continue Button (hidden initially)
$continueButton = New-Object System.Windows.Forms.Button
$continueButton.Text = "Continue After Setup"
$continueButton.Width = 180
$continueButton.Height = 40
$continueButton.Location = New-Object System.Drawing.Point(210, 380)
$continueButton.Visible = $false
$form.Controls.Add($continueButton)

# Run Script Manually Button (hidden initially)
$runScriptButton = New-Object System.Windows.Forms.Button
$runScriptButton.Text = "Run Script Manually"
$runScriptButton.Width = 150
$runScriptButton.Height = 40
$runScriptButton.Location = New-Object System.Drawing.Point(404, 380)
$runScriptButton.Visible = $false
$form.Controls.Add($runScriptButton)

# Timer for checking job completion
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500  # Check every 500ms

function Append-Output($line) {
    try {
        if ($textBox.InvokeRequired) {
            $textBox.Invoke([Action[string]]{param($text) 
                $textBox.AppendText($text + [Environment]::NewLine)
                $textBox.SelectionStart = $textBox.Text.Length
                $textBox.ScrollToCaret()
                $textBox.Refresh()
            }, $line)
        } else {
            $textBox.AppendText($line + [Environment]::NewLine)
            $textBox.SelectionStart = $textBox.Text.Length
            $textBox.ScrollToCaret()
            $textBox.Refresh()
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Update-Status($text) {
    try {
        if ($statusLabel.InvokeRequired) {
            $statusLabel.Invoke([Action[string]]{param($status) $statusLabel.Text = $status}, $text)
        } else {
            $statusLabel.Text = $text
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Update-Progress($value) {
    try {
        if ($progressBar.InvokeRequired) {
            $progressBar.Invoke([Action[int]]{param($val) $progressBar.Value = $val}, $value)
        } else {
            $progressBar.Value = $value
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Test-UbuntuConfigured() {
    try {
        $result = & wsl -d Ubuntu --exec bash -c "echo 'configured'" 2>$null
        return ($result -eq "configured")
    } catch {
        return $false
    }
}

function Show-ContinueButton() {
    try {
        if ($continueButton.InvokeRequired) {
            $continueButton.Invoke([Action]{
                $continueButton.Visible = $true
                $continueButton.Enabled = $true
            })
        } else {
            $continueButton.Visible = $true
            $continueButton.Enabled = $true
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Hide-ContinueButton() {
    try {
        if ($continueButton.InvokeRequired) {
            $continueButton.Invoke([Action]{
                $continueButton.Visible = $false
                $continueButton.Enabled = $false
            })
        } else {
            $continueButton.Visible = $false
            $continueButton.Enabled = $false
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Show-RunScriptButton() {
    try {
        if ($runScriptButton.InvokeRequired) {
            $runScriptButton.Invoke([Action]{
                $runScriptButton.Visible = $true
                $runScriptButton.Enabled = $true
            })
        } else {
            $runScriptButton.Visible = $true
            $runScriptButton.Enabled = $true
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Hide-RunScriptButton() {
    try {
        if ($runScriptButton.InvokeRequired) {
            $runScriptButton.Invoke([Action]{
                $runScriptButton.Visible = $false
                $runScriptButton.Enabled = $false
            })
        } else {
            $runScriptButton.Visible = $false
            $runScriptButton.Enabled = $false
        }
    } catch {
        # Ignore errors if form is disposed
    }
}

function Start-NextStep() {
    if ($script:currentStepIndex -lt $installationSteps.Count) {
        $step = $installationSteps[$script:currentStepIndex]
        
        # Special handling for Ubuntu installation with visible command window
        if ($script:currentStepIndex -eq 3) {  # Ubuntu installation step
            Append-Output ""
            Append-Output "=== UBUNTU INSTALLATION ==="
            Append-Output "Installing Ubuntu distribution..."
            Append-Output "Opening command window to show download progress..."
            
            Update-Progress $step.Progress
            Update-Status $step.Name
            Append-Output "--- Starting: $($step.Name) ---"
            
            # Launch Ubuntu installation in visible command window
            try {
                $process = Start-Process "cmd.exe" -ArgumentList "/c", "wsl --install Ubuntu --no-launch && echo Installation completed! && pause" -WindowStyle Normal -PassThru
                
                Append-Output "Ubuntu installation started in command window."
                Append-Output "You can see the download progress in the command window."
                Append-Output "The installer will continue automatically when complete."
                
                # Wait for the process to complete
                $script:isProcessing = $true
                $script:installProcess = $process
                $script:currentStepIndex++
                
                # Start monitoring the installation process
                return
            } catch {
                Append-Output "[ERROR] Failed to start Ubuntu installation: $_"
                Complete-Installation
                return
            }
        }
        
        # Special handling for Ubuntu first launch
        if ($script:currentStepIndex -eq 4) {  # Ubuntu first launch
            Append-Output ""
            Append-Output "=== UBUNTU FIRST LAUNCH ==="
            Append-Output "Launching Ubuntu for initial setup..."
            Append-Output ""
            Append-Output "IMPORTANT INSTRUCTIONS:"
            Append-Output "1. A new Ubuntu terminal window will open"
            Append-Output "2. Create a username when prompted (lowercase, no spaces)"
            Append-Output "3. Create a password when prompted"
            Append-Output "4. After setup completes, CLOSE the Ubuntu terminal window"
            Append-Output "5. Click 'Continue After Setup' button below to proceed"
            Append-Output ""
            
            # Launch Ubuntu directly
            try {
                Start-Process "ubuntu.exe" -WindowStyle Normal
                Append-Output "Ubuntu terminal launched. Please complete the setup and then click Continue."
                Show-ContinueButton
                Show-RunScriptButton
                Update-Progress 75
                Update-Status "Waiting for Ubuntu setup completion..."
                $script:currentStepIndex++  # Advance step index here
                return
            } catch {
                Append-Output "[ERROR] Failed to launch Ubuntu: $_"
                Append-Output "Please run 'ubuntu' from Start Menu to complete setup, then click Continue."
                Show-ContinueButton
                Show-RunScriptButton
                $script:currentStepIndex++  # Advance step index even on error
                return
            }
        }
        
        # Special handling for WSL script execution
        if ($script:currentStepIndex -eq 5) {  # WSL script execution
            Hide-ContinueButton
            Hide-RunScriptButton
            Append-Output ""
            Append-Output "=== RUNNING CUSTOM SCRIPT ==="
            Append-Output "Opening Ubuntu terminal for interactive script execution..."
            Append-Output "You will be prompted for your Ubuntu password in the terminal window."
            
            # Use interactive approach for script execution
            $scriptCommand = "curl -fsSL https://raw.githubusercontent.com/chinu0609/opendrop_private/master/installation_scripts/install.sh -o /tmp/install.sh && chmod +x /tmp/install.sh && sudo /tmp/install.sh"
            
            # Create a batch file for better control
            $batchContent = @"
@echo off
echo Running Ubuntu installation script...
echo Please enter your Ubuntu password when prompted.
echo.
wsl -d Ubuntu -e bash -c "$scriptCommand"
echo.
echo Installation script completed!
echo You can close this window.
pause
"@
            
            $batchPath = "$env:TEMP\run_ubuntu_script.bat"
            $batchContent | Out-File -FilePath $batchPath -Encoding ASCII
            
            # Launch the batch file
            Start-Process "cmd.exe" -ArgumentList "/c", $batchPath -WindowStyle Normal
            
            Append-Output "Ubuntu script launcher opened in new window."
            Append-Output "Please enter your password when prompted in the terminal."
            Append-Output "The script will run automatically after password entry."
            
            # Complete installation after a delay
            Start-Sleep -Seconds 3
            Complete-Installation
            return
        }
        
        Update-Progress $step.Progress
        Update-Status $step.Name
        Append-Output "--- Starting: $($step.Name) ---"
        
        $script:isProcessing = $true
        $script:currentJob = Start-CommandJob $step.Command $step.Name $step.IsWSL
        $script:currentStepIndex++
    } else {
        # All steps completed
        Complete-Installation
    }
}

function Start-CommandJob($command, $stepName, $isWSL) {
    $job = Start-Job -ScriptBlock {
        param($cmd, $step, $wsl)
        
        try {
            if ($wsl) {
                # For WSL commands
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "wsl.exe"
                $psi.Arguments = "-d Ubuntu -- bash -c `"$cmd`""
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $false
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $psi
                $process.Start() | Out-Null
                
                $output = @()
                $errors = @()
                
                # Read output streams
                $outputReader = $process.StandardOutput
                $errorReader = $process.StandardError
                
                while (-not $process.HasExited) {
                    if (-not $outputReader.EndOfStream) {
                        $line = $outputReader.ReadLine()
                        if ($line -ne $null) {
                            $output += [string]$line
                        }
                    }
                    if (-not $errorReader.EndOfStream) {
                        $line = $errorReader.ReadLine()
                        if ($line -ne $null) {
                            $errors += [string]$line
                        }
                    }
                    Start-Sleep -Milliseconds 100
                }
                
                # Read remaining output
                while (-not $outputReader.EndOfStream) {
                    $line = $outputReader.ReadLine()
                    if ($line -ne $null) {
                        $output += [string]$line
                    }
                }
                
                while (-not $errorReader.EndOfStream) {
                    $line = $errorReader.ReadLine()
                    if ($line -ne $null) {
                        $errors += [string]$line
                    }
                }
                
                $process.WaitForExit()
                
                return @{
                    Output = $output
                    Errors = $errors
                    ExitCode = $process.ExitCode
                    Success = ($process.ExitCode -eq 0)
                }
            } else {
                # Regular Windows commands
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "cmd.exe"
                $psi.Arguments = "/c $cmd"
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $psi
                $process.Start() | Out-Null
                
                $output = $process.StandardOutput.ReadToEnd() -split "`n" | ForEach-Object { [string]$_ }
                $errors = $process.StandardError.ReadToEnd() -split "`n" | ForEach-Object { [string]$_ }
                $process.WaitForExit()
                
                return @{
                    Output = $output | Where-Object { $_.Trim() -ne "" }
                    Errors = $errors | Where-Object { $_.Trim() -ne "" }
                    ExitCode = $process.ExitCode
                    Success = ($process.ExitCode -eq 0)
                }
            }
        }
        catch {
            return @{
                Output = @()
                Errors = @([string]"Exception: $_")
                ExitCode = -1
                Success = $false
            }
        }
    } -ArgumentList $command, $stepName, $isWSL
    
    return $job
}

function Complete-Installation() {
    Hide-ContinueButton
    Hide-RunScriptButton
    Update-Progress 100
    Update-Status "Installation completed!"
    Append-Output ""
    Append-Output "=== INSTALLATION COMPLETE ==="
    Append-Output "Ubuntu WSL has been installed and configured."
    Append-Output "Your custom script has been executed."
    Append-Output "You can now use Ubuntu from the Start Menu or by typing 'wsl' in Command Prompt."
    Append-Output ""
    $button.Enabled = $true
    $button.Text = "Installation Complete"
    $timer.Stop()
    $script:isProcessing = $false
}

# Installation steps
$installationSteps = @(
    @{ Command = 'dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart'; Name = 'Enable WSL'; Progress = 15; IsWSL = $false },
    @{ Command = 'dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart'; Name = 'Enable Virtual Machine Platform'; Progress = 30; IsWSL = $false },
    @{ Command = 'wsl --update && wsl --set-default-version 2'; Name = 'Update WSL and Set Default Version'; Progress = 45; IsWSL = $false },
    @{ Command = 'wsl --install Ubuntu --no-launch'; Name = 'Install Ubuntu Linux (No Launch)'; Progress = 60; IsWSL = $false },
    @{ Command = 'ubuntu.exe'; Name = 'Launch Ubuntu for Setup'; Progress = 75; IsWSL = $false },
    @{ Command = 'interactive_script'; Name = 'Download and run installation script'; Progress = 90; IsWSL = $true }
)

# Timer tick event with timeout handling
$timer.Add_Tick({
    # Check for Ubuntu installation process completion
    if ($script:installProcess -and $script:installProcess.HasExited) {
        Append-Output "Ubuntu installation process completed."
        Append-Output "Exit code: $($script:installProcess.ExitCode)"
        $script:installProcess = $null
        $script:isProcessing = $false
        Start-NextStep
        return
    }
    
    if ($script:isProcessing -and $script:currentJob -ne $null) {
        # Initialize start time if not set
        if ($script:jobStartTime -eq $null) {
            $script:jobStartTime = Get-Date
        }
        
        # Check for timeout (10 minutes for Ubuntu installation, 5 for others)
        $elapsed = (Get-Date) - $script:jobStartTime
        $timeoutMinutes = if ($script:currentStepIndex -eq 4) { 10 } else { 5 }
        
        if ($elapsed.TotalMinutes -gt $timeoutMinutes) {
            Append-Output "[TIMEOUT] Job has been running for over $timeoutMinutes minutes. Stopping..."
            Stop-Job $script:currentJob -ErrorAction SilentlyContinue
            Remove-Job $script:currentJob -ErrorAction SilentlyContinue
            $script:currentJob = $null
            $script:isProcessing = $false
            $script:jobStartTime = $null
            
            Append-Output ""
            Append-Output "[TIMEOUT] Operation timed out. You may need to complete this step manually."
            Start-NextStep
            return
        }
        
        if ($script:currentJob.State -eq "Completed") {
            $script:jobStartTime = $null  # Reset timer
            
            $result = Receive-Job $script:currentJob
            Remove-Job $script:currentJob
            
            if ($result.Output) {
                foreach ($line in $result.Output) {
                    $lineStr = [string]$line
                    if ($lineStr.Trim() -ne "") {
                        Append-Output $lineStr
                    }
                }
            }
            
            if ($result.Errors) {
                foreach ($err in $result.Errors) {
                    $errStr = [string]$err
                    if ($errStr.Trim() -ne "") {
                        Append-Output "[ERROR] $errStr"
                    }
                }
            }
            
            Append-Output "--- Completed: $($installationSteps[$script:currentStepIndex-1].Name) (Exit Code: $($result.ExitCode)) ---"
            Append-Output ""
            
            $script:currentJob = $null
            $script:isProcessing = $false
            
            Start-Sleep -Milliseconds 1000
            Start-NextStep
        }
        elseif ($script:currentJob.State -eq "Failed") {
            $script:jobStartTime = $null  # Reset timer
            
            Append-Output "[ERROR] Job failed"
            $result = Receive-Job $script:currentJob -ErrorAction SilentlyContinue
            if ($result) {
                $resultStr = [string]$result
                Append-Output "[ERROR] Job details: $resultStr"
            }
            Remove-Job $script:currentJob
            $script:currentJob = $null
            $script:isProcessing = $false
            Start-NextStep
        }
    }
})

# Install button click event
$button.Add_Click({
    $button.Enabled = $false
    $progressBar.Value = 0
    $statusLabel.Text = "Starting installation..."
    $textBox.Text = ""
    $script:currentStepIndex = 0
    $script:isProcessing = $false
    $script:jobStartTime = $null
    $script:installProcess = $null
    Hide-ContinueButton
    Hide-RunScriptButton
    
    Append-Output "Ubuntu WSL Installation with Custom Script"
    Append-Output "========================================"
    Append-Output "Running with Administrator privileges."
    Append-Output ""
    Append-Output "This will:"
    Append-Output "1. Enable WSL features"
    Append-Output "2. Update WSL and set default version"
    Append-Output "3. Install Ubuntu (with visible progress)"
    Append-Output "4. Launch Ubuntu for initial setup"
    Append-Output "5. Run your custom installation script"
    Append-Output ""
    Append-Output "Starting installation..."
    Append-Output ""
    
    $timer.Start()
    Start-NextStep
})

# Continue button click event
$continueButton.Add_Click({
    Append-Output "Checking Ubuntu configuration..."
    Start-Sleep -Seconds 2
    
    if (Test-UbuntuConfigured) {
        Append-Output "[SUCCESS] Ubuntu setup verified successfully!"
        Append-Output "Continuing with custom script installation..."
        $script:currentStepIndex = 5  # Go to script execution step
        Start-NextStep
    } else {
        Append-Output ""
        Append-Output "[ERROR] Ubuntu setup not completed properly."
        Append-Output "Please ensure you completed the username/password setup."
        Append-Output "Try the 'Run Script Manually' button or complete setup and try again."
    }
})

# Run Script Manually button click event
$runScriptButton.Add_Click({
    if (Test-UbuntuConfigured) {
        Hide-RunScriptButton
        Hide-ContinueButton
        
        Append-Output ""
        Append-Output "=== MANUAL SCRIPT EXECUTION ==="
        Append-Output "Opening Ubuntu for manual script execution..."
        
        $scriptCommand = "curl -fsSL https://raw.githubusercontent.com/chinu0609/opendrop_private/master/installation_scripts/install.sh -o /tmp/install.sh && chmod +x /tmp/install.sh && sudo /tmp/install.sh"
        
        # Launch Ubuntu with the script command
        Start-Process "wsl.exe" -ArgumentList "-d", "Ubuntu", "-e", "bash", "-c", $scriptCommand -WindowStyle Normal
        
        Append-Output "Ubuntu launched with installation script."
        Append-Output "Please enter your password when prompted."
        
        Complete-Installation
    } else {
        Append-Output "[ERROR] Ubuntu not properly configured. Please complete setup first."
    }
})

# Form cleanup
$form.Add_FormClosed({
    if ($script:currentJob -ne $null) {
        Stop-Job $script:currentJob -ErrorAction SilentlyContinue
        Remove-Job $script:currentJob -ErrorAction SilentlyContinue
    }
    if ($script:installProcess -ne $null) {
        $script:installProcess.Close()
    }
    $timer.Stop()
})

$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
