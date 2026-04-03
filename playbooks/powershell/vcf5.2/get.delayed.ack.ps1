$user = "root"
$pass = "VMware1!VMware1!"
$targets = @(1,2 ) + (3..6) | ForEach-Object { "172.16.11.$_" }

foreach ($ip in $targets) {
    $conn = Connect-VIServer -Server $ip -User $user -Password $pass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($conn) {
        Get-VMHost -Name $ip | Get-AdvancedSetting -Name "SunRPC.SetNoDelayedAck" | Select-Object @{N='IP';E={$ip}}, Value
        Disconnect-VIServer -Server $conn -Confirm:$false
    } else {
        "Failed to connect to $ip"
    }
}
