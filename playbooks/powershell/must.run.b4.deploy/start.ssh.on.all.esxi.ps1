# Ensure Single Mode is active at the start
Set-PowerCLIConfiguration -DefaultVIServerMode Single -Scope User -Confirm:$false | Out-Null

$ips = 11..19 | ForEach-Object { "192.168.50.$_" }
$user = "root"
$pass = "VMware1!VMware1!"

foreach ($ip in $ips) {
    try {
        Write-host "Connect"
        $conn = Connect-VIServer -Server $ip -User $user -Password $pass -ErrorAction Stop 
        
        write-host "Get Service"
        $ssh = Get-VMHostService -VMHost $ip | Where-Object {$_.Key -eq "TSM-SSH"}
        
        write-host "Action (Suppressing the table output)"
        $ssh | Set-VMHostService -Policy "On" -Confirm:$false 
	write-host "start service"
        $ssh | Start-VMHostService -Confirm:$false 
        
        # Final Verification
        $status = Get-VMHostService -VMHost $ip | Where-Object {$_.Key -eq "TSM-SSH"}
        if ($status.Running -eq $true) {
            Write-Host "[OK] $ip : SSH is ENABLED and RUNNING" -ForegroundColor Green
        } else {
            Write-Host "[!!] $ip : SSH is Policy ON but NOT RUNNING" -ForegroundColor Yellow
        }
        
        Disconnect-VIServer -Server $ip -Confirm:$false 
    }
    catch {
        Write-Host "[FAIL] $ip : Connection failed (Check credentials/network)" -ForegroundColor Red
    }
}
