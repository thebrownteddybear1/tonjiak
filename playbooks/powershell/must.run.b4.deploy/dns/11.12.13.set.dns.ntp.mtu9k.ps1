$user = "root"
$pass = "VMware1@VMware1@"
$target = "192.168.50.53"
$hosts = "192.168.50.11", "192.168.50.12", "192.168.50.13"

# Suppress warnings and ignore certs
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings $false -Confirm:$false

foreach ($ip in $hosts) {
    Write-Host "`n>>> Configuring $ip <<<" -ForegroundColor Cyan
    try {
        $s = Connect-VIServer -Server $ip -User $user -Password $pass -ErrorAction Stop
        
        # 1. DNS Update
        Get-VMHostNetwork -VMHost $ip | Set-VMHostNetwork -DnsAddress $target -Confirm:$false | Out-Null
        
        # 2. NTP Cleanup & Set (Only remove if servers exist)
        $currentNtp = Get-VMHostNtpServer -VMHost $ip
        if ($currentNtp) {
            $currentNtp | ForEach-Object { Remove-VMHostNtpServer -VMHost $ip -NtpServer $_ -Confirm:$false }
        }
        Add-VmHostNtpServer -VMHost $ip -NtpServer $target -Confirm:$false | Out-Null
        
        # 3. Enable/Start Services
        Get-VMHostService -VMHost $ip | Where-Object { $_.Key -in "TSM-SSH","TSM","ntpd" } | ForEach-Object {
            Set-VMHostService -HostService $_ -Policy "On" -Confirm:$false | Out-Null
            Start-VMHostService -HostService $_ -Confirm:$false | Out-Null
        }

        # 4. Networking MTU 9000
        Write-Host "Updating MTU to 9000..." -ForegroundColor Yellow
        Get-VirtualSwitch -VMHost $ip -Name "vSwitch0" | Set-VirtualSwitch -MTU 9000 -Confirm:$false
        Get-VMHostNetworkAdapter -VMHost $ip -Name "vmk0" | Set-VMHostNetworkAdapter -Mtu 9000 -Confirm:$false

        Disconnect-VIServer -Server $ip -Confirm:$false
        Write-Host "DONE: $ip is ready for VCF." -ForegroundColor Green
    } 
    catch {
        Write-Host "ERROR: Could not configure $ip. Check connectivity/credentials." -ForegroundColor Red
    }
}
