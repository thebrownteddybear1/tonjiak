# --- CONFIG ---
$NsxManager = "nsx-mgr-01.lab.local"
$Clusters = @("cluster1", "cluster2", "cluster3") # Your 3 Zonal Clusters

Connect-NsxtServer -Server $NsxManager

write-host "`n--- NSX Zonal Transport Zone Validation ---" -ForegroundColor Cyan

foreach ($ClusterName in $Clusters) {
    write-host "[*] Checking Cluster: $ClusterName" -ForegroundColor Yellow
    
    # Get all Transport Nodes (Hosts) in this cluster
    $TNService = Get-NsxtService -Name "com.vmware.nsx.transport_nodes"
    $Nodes = $TNService.list().results | Where-Object { $_.node_deployment_info.resource_type -eq "HostNode" }
    
    # Filter nodes that belong to this specific vCenter Cluster
    # Note: This assumes your Host names match or you can filter by cluster ID
    foreach ($Node in $Nodes) {
        $NodeName = $Node.display_name
        $TZs = $Node.host_switch_spec.host_switches.transport_zone_ids
        
        write-host "  > Host: $NodeName"
        foreach ($TZId in $TZs) {
            $TZName = (Get-NsxtService -Name "com.vmware.nsx.transport_zones").get($TZId).display_name
            write-host "    - Transport Zone: $TZName ($TZId)"
        }
    }
}

Disconnect-NsxtServer -Confirm:$false