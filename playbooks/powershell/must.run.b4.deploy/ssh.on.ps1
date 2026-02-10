$ip = "192.168.50.11"
$user = "root"
$pass = "VMware1!VMware1!"

$conn = Connect-VIServer -Server $ip -User $user -Password $pass -ErrorAction Stop
$ssh = Get-VmHostService -VMHost $ip | Where-Object {$_.Key -eq "TSM-SSH"}
Set-VMHostService -HostService $ssh -Policy "On" -Confirm:$false
Start-VMHostService -HostService $ssh -Confirm:$false
Disconnect-VIServer -Server $conn -Confirm:$false
