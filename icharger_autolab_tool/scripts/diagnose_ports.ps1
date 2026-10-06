<#
.SYNOPSIS
    Comprehensive Windows COM Port & Serial Hardware Diagnostic Utility
.DESCRIPTION
    Audits Windows COM ports across Registry, WMI/CIM, and PnP entities.
    Identifies USB-to-Serial chipsets (FTDI, CP210x, CH340, PL2303, Arduino CDC),
    normalizes hardware paths (including \\.\COM10+ syntax), and tests port locks.
.PARAMETER TestAccess
    Attempts a non-destructive open/close to test for lock/busy state (EACCES/EBUSY).
.PARAMETER AsJson
    Outputs diagnostic results formatted as a JSON string.
#>
[CmdletBinding()]
param (
    [switch]$TestAccess,
    [switch]$AsJson
)

$KnownChipsets = @{
    "0403" = "FTDI USB-to-Serial"
    "10C4" = "Silicon Labs CP210x"
    "1A86" = "WCH QinHeng CH340 / CH341"
    "067B" = "Prolific PL2303"
    "2341" = "Arduino / Atmel CDC"
    "2A03" = "Arduino Uno / Mega (CDC)"
    "2E8A" = "Raspberry Pi (Pico CDC)"
    "0483" = "STMicroelectronics Virtual COM"
}

function Format-Win32ComPath {
    param ([string]$PortName)
    if ([string]::IsNullOrWhiteSpace($PortName)) { return $PortName }
    $clean = $PortName.Trim()
    if ($clean -match '^COM(\d+)$') {
        $num = [int]$matches[1]
        if ($num -ge 10) {
            return "\\.\$clean"
        }
    }
    return $clean
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Lab Control Suite - Windows Serial Diagnostic Utility    " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$discoveredPorts = [System.Collections.Generic.List[PSCustomObject]]::new()

# 1. Query Registry HARDWARE\DEVICEMAP\SERIALCOMM
$regPath = "HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM"
if (Test-Path $regPath) {
    $regProps = Get-ItemProperty -Path $regPath
    foreach ($prop in $regProps.PSObject.Properties) {
        if ($prop.Name -notmatch '^PS.*') {
            $port = [string]$prop.Value
            $obj = [PSCustomObject]@{
                PortName         = $port
                Win32Path        = Format-Win32ComPath -PortName $port
                Source           = "Registry (SERIALCOMM)"
                DevicePath       = $prop.Name
                Description      = "Virtual / Hardware COM Port"
                Chipset          = "Standard Serial Port"
                Manufacturer     = "Unknown"
                HardwareID       = "N/A"
                AccessStatus     = "Not Tested"
            }
            $discoveredPorts.Add($obj)
        }
    }
}

# 2. Query CIM / WMI Win32_SerialPort
try {
    $wmiPorts = Get-CimInstance -ClassName Win32_SerialPort -ErrorAction SilentlyContinue
    foreach ($wp in $wmiPorts) {
        $port = $wp.DeviceID
        $existing = $discoveredPorts | Where-Object { $_.PortName -eq $port }
        if ($existing) {
            $existing.Description = $wp.Description
            $existing.Manufacturer = $wp.Manufacturer
            $existing.Source += ", CIM (Win32_SerialPort)"
        } else {
            $obj = [PSCustomObject]@{
                PortName         = $port
                Win32Path        = Format-Win32ComPath -PortName $port
                Source           = "CIM (Win32_SerialPort)"
                DevicePath       = $wp.PNPDeviceID
                Description      = $wp.Description
                Chipset          = "Standard Serial"
                Manufacturer     = $wp.Manufacturer
                HardwareID       = $wp.PNPDeviceID
                AccessStatus     = "Not Tested"
            }
            $discoveredPorts.Add($obj)
        }
    }
} catch {
    Write-Verbose "Win32_SerialPort query failed or returned no items."
}

# 3. Query Win32_PnPEntity for USB CDC / Serial Chips
try {
    $pnpEntities = Get-CimInstance -ClassName Win32_PnPEntity -Filter "PNPClass = 'Ports' or Caption like '%(COM%'" -ErrorAction SilentlyContinue
    foreach ($pnp in $pnpEntities) {
        if ($pnp.Caption -match '\((COM\d+)\)') {
            $port = $matches[1]
            $chipset = "Generic Serial Device"
            $hwId = ($pnp.HardwareID | Select-Object -First 1)

            foreach ($vid in $KnownChipsets.Keys) {
                if ($hwId -match "VID_$vid" -or $pnp.DeviceID -match "VID_$vid") {
                    $chipset = $KnownChipsets[$vid]
                    break
                }
            }

            $existing = $discoveredPorts | Where-Object { $_.PortName -eq $port }
            if ($existing) {
                $existing.Description = $pnp.Caption
                $existing.Manufacturer = $pnp.Manufacturer
                $existing.Chipset = $chipset
                $existing.HardwareID = $pnp.DeviceID
                $existing.Source += ", PnP"
            } else {
                $obj = [PSCustomObject]@{
                    PortName         = $port
                    Win32Path        = Format-Win32ComPath -PortName $port
                    Source           = "Win32_PnPEntity"
                    DevicePath       = $pnp.DeviceID
                    Description      = $pnp.Caption
                    Chipset          = $chipset
                    Manufacturer     = $pnp.Manufacturer
                    HardwareID       = $pnp.DeviceID
                    AccessStatus     = "Not Tested"
                }
                $discoveredPorts.Add($obj)
            }
        }
    }
} catch {
    Write-Verbose "Win32_PnPEntity query failed."
}

# 4. Optional Accessibility / Busy Lock Test
if ($TestAccess) {
    try {
        Add-Type -AssemblyName System -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.IO.Ports -ErrorAction SilentlyContinue
    } catch {}
    foreach ($dp in $discoveredPorts) {
        try {
            $testPort = New-Object System.IO.Ports.SerialPort($dp.PortName)
            $testPort.ReadTimeout = 200
            $testPort.WriteTimeout = 200
            $testPort.Open()
            $dp.AccessStatus = "Available / Unlocked (OK)"
            $testPort.Close()
            $testPort.Dispose()
        } catch [System.UnauthorizedAccessException] {
            $dp.AccessStatus = "LOCKED / IN USE (EACCES / EBUSY - Another process holds this port)"
        } catch [System.IO.IOException] {
            $dp.AccessStatus = "IO ERROR ($($_.Exception.Message))"
        } catch {
            $dp.AccessStatus = "ERROR: $($_.Exception.Message)"
        }
    }
}

if ($AsJson) {
    $discoveredPorts | ConvertTo-Json -Depth 4
} else {
    if ($discoveredPorts.Count -eq 0) {
        Write-Host "`n[!] No active COM ports found on this Windows system." -ForegroundColor Yellow
        Write-Host "    If you have plugged in a USB-to-Serial converter (CH340, FTDI, CP210x):" -ForegroundColor Gray
        Write-Host "    1. Check Windows Device Manager under 'Ports (COM & LPT)'." -ForegroundColor Gray
        Write-Host "    2. Verify OEM driver installation (CH341SER.EXE, CP210x_Windows_Drivers, or FTDI VCP)." -ForegroundColor Gray
        Write-Host "    3. Ensure USB cable supports data (not power-only)." -ForegroundColor Gray
    } else {
        Write-Host "`n[+] Discovered $($discoveredPorts.Count) Serial Port(s):" -ForegroundColor Green
        $discoveredPorts | Format-Table PortName, Win32Path, Chipset, AccessStatus, Description -AutoSize
    }
}