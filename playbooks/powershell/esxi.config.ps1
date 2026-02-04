$user = "root"
$pass = "VMware1!VMware1!"
$target = "192.168.50.53"
$hosts = "192.168.50.14", "192.168.50.15", "192.168.50.16", "192.168.50.17", "192.168.50.18", "192.168.50.19"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

foreach ($ip in $hosts) {
    Write-Host "Configuring $ip..." -Cyan
    $s = Connect-VIServer -Server $ip -User $user -Password $pass
    
    # 1. Update DNS
    Get-VMHostNetwork -VMHost $ip | Set-VMHostNetwork -DnsServer $target -Confirm:$false
    
    # 2. Wipe old NTP servers and add the new one
    Get-VMHostNtpServer -VMHost $ip | Remove-VMHostNtpServer -Confirm:$false
    Add-VmHostNtpServer -VMHost $ip -NtpServer $target -Confirm:$false
    
    # 3. Enable and Start SSH, Shell, and NTP Services
    Get-VMHostService -VMHost $ip | Where-Object { $_.Key -in "TSM-SSH","TSM","ntpd" } | ForEach-Object {
        Set-VMHostService -HostService $_ -Policy "On" -Confirm:$false
        Start-VMHostService -HostService $_ -Confirm:$false
    }

    Disconnect-VIServer -Server $ip -Confirm:$false
    Write-Host "Done with $ip" -Green
}