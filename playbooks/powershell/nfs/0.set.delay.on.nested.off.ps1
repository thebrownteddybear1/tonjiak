$user = "root"
$pass = "VMware1!VMware1!"
$targets = @(11, 12) + (14..19) | ForEach-Object { "192.168.50.$_" }

foreach ($ip in $targets) {
    $conn = Connect-VIServer -Server $ip -User $user -Password $pass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($conn) {
        # Get Current (Before)
        $setting = Get-VMHost -Name $ip | Get-AdvancedSetting -Name "SunRPC.SetNoDelayedAck"
        $before = $setting.Value
        
        # Set to 1
        Set-AdvancedSetting -AdvancedSetting $setting -Value 1 -Confirm:$false | Out-Null
        
        # Get Current (After)
        $after = (Get-VMHost -Name $ip | Get-AdvancedSetting -Name "SunRPC.SetNoDelayedAck").Value
        
        # Output result
        Get-VMHost -Name $ip | Select-Object @{N='IP';E={$ip}}, @{N='Before';E={$before}}, @{N='After';E={$after}}
        
        Disconnect-VIServer -Server $conn -Confirm:$false
    } else {
        "Failed to connect to $ip"
    }
}
