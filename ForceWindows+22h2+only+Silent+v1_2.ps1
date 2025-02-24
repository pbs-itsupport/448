function Check-Windows10Compatibility {
    $osversion = Get-WMIObject win32_operatingsystem
    $osbuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion).DisplayVersion
    $validBuilds = @("21H2", "2004", "22H1", "20H2", "21H1")

    if ($osversion.Caption -like "*Windows 10*") {
        Write-Host "Windows 10 detected"
        if ($osbuild -in $validBuilds) {
            Write-Host "Build of Windows is compatible"
            return $true
        } else {
            Write-Host "Build of Windows is not compatible: $($osbuild)"
            return $false
        }
    } else {
        Write-Host "Windows 10 not detected: $($osversion.Caption)"
        return $false
    }
}

function Download-WindowsUpgrade {
    $folderPath = "C:\tempnable"
    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory | Out-Null
    }

    if ([Environment]::Is64BitOperatingSystem -eq $true) {
        Write-Host "64-bit Windows detected"
        $updateFile = "windows10.0-kb5015684-x64.cab"
        $downloadURL = "http://b1.download.windowsupdate.com/c/upgr/2022/07/windows10.0-kb5015684-x64_d2721bd1ef215f013063c416233e2343b93ab8c1.cab"
    } else {
        Write-Host "32-bit Windows detected"
        $updateFile = "windows10.0-kb5015684-x86.cab"
        $downloadURL = "http://b1.download.windowsupdate.com/c/upgr/2022/07/windows10.0-kb5015684-x86_3734a3f6f4143b645788cc77154f6288c8054dd5.cab"
    }

    $filePath = "$folderPath\$updateFile"

    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($downloadURL, $filePath)
        Write-Host "Download completed: $filePath"
        return $filePath
    } catch {
        Write-Host "Error downloading update file: $_"
        return $false
    }
}

function Apply-WindowsUpgrade ($filePath) {
    $updaterunArguments = "/online /Add-Package /PackagePath:`"$filePath`" /quiet /norestart"
    $process = Start-Process -FilePath "C:\Windows\system32\dism.exe" -ArgumentList $updaterunArguments -NoNewWindow -PassThru -Wait

    Write-Output "Execution Exit Code: $($process.ExitCode)"

    if ($process.ExitCode -eq 3010) {
        Write-Host "Update installed successfully, but a reboot is required."

        # Set Windows Update Reboot Required flag in the registry
        $rebootFlagPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

        if (-not (Test-Path $rebootFlagPath)) {
            New-Item -Path $rebootFlagPath -Force | Out-Null
            Write-Host "Windows Update Reboot Required flag has been set in the system registry."
        } else {
            Write-Host "Reboot Required flag already exists."
        }
    }

    if ($process.ExitCode -ne 0) {
        Write-Host "Update installation failed with exit code $($process.ExitCode)."
        return $false
    }

    return $true
}

# MAIN EXECUTION FLOW
if (-not (Check-Windows10Compatibility)) { exit 1 }
Write-Host "Proceeding with Windows 10 Upgrade..."
$filePath = Download-WindowsUpgrade
if ($filePath -eq $false) { exit 1 }
if (-not (Apply-WindowsUpgrade -filePath $filePath)) { exit 1 }