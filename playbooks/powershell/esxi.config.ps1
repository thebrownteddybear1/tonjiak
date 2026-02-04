$user = "root"
$pass = "VMware1!VMware1!"
$target = "192.168.50.53"
$hosts = "192.168.50.14", "192.168.50.15", "192.168.50.16", "192.168.50.17", "192.168.50.18", "192.168.50.19"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

foreach ($ip in $hosts) {
    Write-Host "Configuring $ip..." -ForegroundColor Cyan
    $s = Connect-VIServer -Server $ip -User $user -Password $pass -ErrorAction Stop
    
    # 1. Update DNS (Changed to -DnsAddress)
    Get-VMHostNetwork -VMHost $ip | Set-VMHostNetwork -DnsAddress $target -Confirm:$false
    
    # 2. Remove all old NTP servers and add the new one
    $oldNtp = Get-VMHostNtpServer -VMHost $ip
    if ($oldNtp) {
        $oldNtp | Remove-VMHostNtpServer -Confirm:$false
    }
    Add-VmHostNtpServer -VMHost $ip -NtpServer $target -Confirm:$false
    
    # 3. Enable and Start SSH, Shell, and NTP Services
    Get-VMHostService -VMHost $ip | Where-Object { $_.Key -in "TSM-SSH","TSM","ntpd" } | ForEach-Object {
        Set-VMHostService -HostService $_ -Policy "On" -Confirm:$false
        Start-VMHostService -HostService $_ -Confirm:$false
    }

    Disconnect-VIServer -Server $ip -Confirm:$false
    Write-Host "Done with $ip" -ForegroundColor Green
}