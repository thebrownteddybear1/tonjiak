# Start SSH Service on ESXi hosts 172.16.11.1 to 172.16.11.6
# Requires PowerCLI: Install-Module VMware.PowerCLI -Force

# ============================================================
# CONFIGURATION
# ============================================================
$esxiHosts = 1..6 | ForEach-Object { "172.16.11.$_" }
$username   = "root"
$password   = "VMware1@VMware1@"

# ============================================================
# MAIN
# ============================================================
foreach ($ip in $esxiHosts) {
    Write-Host "`nConnecting to $ip ..." -ForegroundColor Cyan

    try {
        # Connect directly to ESXi host (bypasses vCenter)
        $conn = Connect-VIServer -Server $ip `
                                 -User $username `
                                 -Password $password `
                                 -Force `
                                 -ErrorAction Stop

        # Get SSH service
        $sshService = Get-VMHostService -VMHost $ip | Where-Object { $_.Key -eq "TSM-SSH" }

        if ($sshService.Running) {
            Write-Host "$ip : SSH already running" -ForegroundColor Yellow
        } else {
            Start-VMHostService -HostService $sshService -Confirm:$false | Out-Null
            Write-Host "$ip : SSH started successfully" -ForegroundColor Green
        }

        # Optional: set SSH to start automatically with host
        Set-VMHostService -HostService $sshService -Policy "On" | Out-Null
        Write-Host "$ip : SSH policy set to start automatically" -ForegroundColor Green

        # Disconnect
        Disconnect-VIServer -Server $conn -Confirm:$false

    } catch {
        Write-Host "$ip : FAILED - $_" -ForegroundColor Red
    }
}

Write-Host "`nDone!" -ForegroundColor Cyan