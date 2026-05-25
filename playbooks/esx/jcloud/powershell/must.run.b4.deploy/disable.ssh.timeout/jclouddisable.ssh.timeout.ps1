$ips = 1..3| ForEach-Object { "192.168.52.$_" }
$user = "root"
$pass = "VMware1@VMware1@"

foreach ($ip in $ips) {
    try {
        $conn = Connect-VIServer -Server $ip -User $user -Password $pass -ErrorAction Stop
        
        # Idle timeout - disconnects idle SSH sessions (seconds, 0 = never)
        Get-AdvancedSetting -Entity $ip -Name "UserVars.ESXiShellInteractiveTimeOut" | 
            Set-AdvancedSetting -Value 0 -Confirm:$false

        # Shell timeout - time before SSH service auto-disables itself (seconds, 0 = never)
        Get-AdvancedSetting -Entity $ip -Name "UserVars.ESXiShellTimeOut" | 
            Set-AdvancedSetting -Value 0 -Confirm:$false

        Write-Host "[OK] $ip : SSH timeout set" -ForegroundColor Green
        Disconnect-VIServer -Server $ip -Confirm:$false
    }
    catch {
        Write-Host "[FAIL] $ip : $($_.Exception.Message)" -ForegroundColor Red
    }
}