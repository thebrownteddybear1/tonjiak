$user = "root"
$pass = "VMware1!VMware1!"
$targets = @(11, 12) + (14..19) | ForEach-Object { "192.168.50.$_" }

$results = foreach ($ip in $targets) {
    $conn = Connect-VIServer -Server $ip -User $user -Password $pass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($conn) {
        $hostObj = Get-VMHost -Name $ip
        # Corrected cmdlet: Get-VMHostNetworkAdapter
        $hostObj | Get-VMHostNetworkAdapter -VMKernel | Select-Object `
            @{N='Host_Mgmt_IP'; E={$ip}}, 
            Name, 
            IP, 
            Mac, 
            PortGroupName, 
            MTU
        Disconnect-VIServer -Server $conn -Confirm:$false
    } else {
        Write-Warning "Could not connect to $ip"
    }
}

$results | Format-Table -AutoSize
