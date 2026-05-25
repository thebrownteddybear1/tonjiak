$user = "root"
$pass = "VMware1!VMware1!"
$targets = @(11, 12) + (14..19) | ForEach-Object { "192.168.50.$_" }

foreach ($ip in $targets) {
    $conn = Connect-VIServer -Server $ip -User $user -Password $pass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($conn) {
        Get-VMHost -Name $ip | Get-AdvancedSetting -Name "SunRPC.SetNoDelayedAck" | Select-Object @{N='IP';E={$ip}}, Value
        Disconnect-VIServer -Server $conn -Confirm:$false
    } else {
        "Failed to connect to $ip"
    }
}
