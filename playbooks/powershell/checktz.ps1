# --- CONFIG ---
$NsxManager = "192.168.50.40"
$Clusters = @("cluster1", "cluster2", "cluster3")
# Use your NSX admin credentials when prompted

Connect-NsxtServer -Server $NsxManager

write-host "`n--- AUDITING NSX ZONAL CONFIGURATION (192.168.50.40) ---" -ForegroundColor Cyan

# Get all Transport Zones to build a lookup table
$TZService = Get-NsxtService -Name "com.vmware.nsx.transport_zones"
$AllTZs = $TZService.list().results
$TZMap = @{}
foreach ($tz in $AllTZs) { $TZMap[$tz.id] = $tz.display_name }

foreach ($ClusterName in $Clusters) {
    write-host "[*] Checking Cluster: $ClusterName" -ForegroundColor Yellow
    
    # Get the Transport Node Profile (TNP) for the cluster if it exists
    $TNPService = Get-NsxtService -Name "com.vmware.nsx.transport_node_profiles"
    # Note: In a production VCF lab, the TNP name usually matches the cluster or a standard 'TNP-Compute'
    
    # List all Host Transport Nodes
    $TNService = Get-NsxtService -Name "com.vmware.nsx.transport_nodes"
    $Hosts = $TNService.list().results | Where-Object { $_.node_deployment_info.resource_type -eq "HostNode" }

    foreach ($Host in $Hosts) {
        # Check if the host belongs to the current cluster (basic name match for labs)
        if ($Host.display_name -like "*$ClusterName*") {
            $HostTZs = $Host.host_switch_spec.host_switches.transport_zone_ids
            $TZNames = foreach ($id in $HostTZs) { $TZMap[$id] }
            
            write-host "  > Host: $($Host.display_name)"
            write-host "    Zones: $($TZNames -join ', ')" -ForegroundColor ( ($TZNames -contains "Overlay") ? "Green" : "Red" )
        }
    }
}

Disconnect-NsxtServer -Confirm:$false