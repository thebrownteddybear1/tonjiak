$pvcUrl = "http://build-squid.vcfd.broadcom.net/build/mts/release/bora-24966933/publish/PROD/metadata/productVersionCatalog/v1/productVersionCatalog.json"
$vcfVersion = "9.0.1.0"

$vcfInstallBinaries = $true
$vcfPatchBinaries = $true

$vcfComponents = @(
    "ESX_HOST",
    "VCENTER",
    "NSX_T_MANAGER",
    "SDDC_MANAGER_VCF",
    "VRSLCM",
    "VROPS",
    "VCF_OPS_CLOUD_PROXY",
    "VRA"
)

#$vcfToplevelRootDir = "/Users/wlam/Desktop/VCF901"
$vcfToplevelRootDir = "/root/tonjiak/vcf9/offlinedepot/depot/vcf9.01"

### DO NOT EDIT BEYOND HERE ###

$dryRun = $false

$vsanHclUrl = "https://partnerweb.vmware.com/service/vsan/all.json"
$cwd = (Get-Location).Path

function Write-ColoredHost ([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Green) {
    Write-Host $Message -ForegroundColor $Color
}

if ($pvcUrl -match "^(https?://[^/]+(?:/[^/]+)*/PROD/)") {
    $vcfBaseUri = $matches[1]
} else {
    exit
}

if($dryRun) {
    Write-Host "DRYRUN ONLY - NO DOWNLOADS" -ForegroundColor Red
}

$vcfComponentLists = ((Invoke-WebRequest -Uri $pvcUrl).Content | ConvertFrom-Json).patches

Write-ColoredHost "Creating $vcfToplevelRootDir Directory ..."
if (Test-Path $vcfToplevelRootDir) {
    Write-Host "Directory $vcfToplevelRootDir already exists. Re-creating for a clean state." -ForegroundColor Yellow
    Remove-Item -Path $vcfToplevelRootDir -Recurse -Force
}
New-Item -ItemType Directory -Path $vcfToplevelRootDir -Force | Out-Null

Set-Location $vcfToplevelRootDir

# Metadata

$SubDirs = @(
    "PROD/COMP",
    "PROD/metadata",
    "PROD/vsan",
    "PROD/metadata/manifest/v1",
    "PROD/metadata/productVersionCatalog/v1",
    "PROD/COMP/SDDC_MANAGER_VCF/Compatibility",
    "PROD/vsan/hcl"
)
foreach ($dir in $SubDirs) {
    Write-ColoredHost "Creating ${dir} ..."
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Write-ColoredHost "Downloading Compatibility file ..."
if($dryRun -eq $false) {
    $accessToken = ""
    try {
        $authPayload = @{
            client_id     = "vsphere_hcllib"
            client_secret = "cb65f5ac-cb38-4326-a48f-c0e8b23a2d38"
            grant_type    = "client_credentials"
        }
        $tokenResponse = Invoke-RestMethod -Uri "https://auth.esp.vmware.com/api/auth/v1/tokens" -Method Post -Body $authPayload -ContentType "application/x-www-form-urlencoded"
        $accessToken = $tokenResponse.access_token
    }
    catch {
        Write-Error "Failed to get access token: $($_.Exception.Message)"
        # Decide if script should continue or exit
        # exit 1
    }

    if ($accessToken) {
        try {
            $headers = @{ "X-Vmw-Esp-Client" = $accessToken }
            Invoke-WebRequest -Uri "https://vvs.esp.vmware.com/v1/products/bundles/type/vcf-lcm-v2-bundle?format=json" -Headers $headers -OutFile "PROD/COMP/SDDC_MANAGER_VCF/Compatibility/VmwareCompatibilityData.json" -UseBasicParsing
        }
        catch {
            Write-Error "Failed to download VmwareCompatibilityData.json: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Skipping VCF Compat Data file download as access token could not be retrieved."
    }
}

Write-ColoredHost "Downloading vSAN HCL Files ..."
if($dryRun -eq $false) {
    Invoke-WebRequest -Uri $vsanHclUrl -OutFile "PROD/vsan/hcl/all.json"
    $allJsonContent = (Invoke-WebRequest -Uri $vsanHclUrl).Content | ConvertFrom-Json

    $lastupdateJson = [ordered]@{
        "timestamp" = ${allJsonContent}.timestamp
        "jsonUpdatedTime" = ${allJsonContent}.jsonUpdatedTime
    }
}

Write-ColoredHost "Creating vSAN HCL lastupdatedtime.json"
Set-Content -Path "PROD/vsan/hcl/lastupdatedtime.json" -Value $($lastupdateJson | ConvertTo-Json)

Write-ColoredHost "Downloading PVC files ..."
if($dryRun -eq $false) {
    Invoke-WebRequest -Uri $pvcUrl -OutFile "PROD/metadata/productVersionCatalog/v1/productVersionCatalog.json"
    Invoke-WebRequest -Uri "${vcfBaseUri}metadata/productVersionCatalog/v1/productVersionCatalog.sig" -OutFile "PROD/metadata/productVersionCatalog/v1/productVersionCatalog.sig"
}

Write-ColoredHost "Downloading Manifest file ..."
if($dryRun -eq $false) {
    Invoke-WebRequest -Uri "${vcfBaseUri}metadata/manifest/v1/vcfManifest.json" -OutFile "PROD/metadata/manifest/v1/vcfManifest.json"
}

# Binaries
$downloadedFiles = @()
foreach($vcfComponent in $vcfComponents) {

    # Special case for ESX as it shows up as PATCH
    $vcfTypes = @()
    if($vcfComponent -eq "ESX_HOST") {
        $vcfTypes = "PATCH"
    } else {
        if($vcfInstallBinaries -eq $true) {
            $vcfTypes += "INSTALL"
        }

        if($vcfPatchBinaries -eq $true) {
            $vcfTypes += "PATCH"
        }
    }

    $vcfComponentDownloadDirectory = "PROD/COMP/${vcfComponent}"
    $vcfComponentDownloadDirectory = "PROD/COMP/${vcfComponent}"

    Write-ColoredHost "Creating component directory ${vcfComponentDownloadDirectory} ..."
    New-Item -ItemType Directory -Path $vcfComponentDownloadDirectory -Force | Out-Null

    $vcfComponentFileNames = (($vcfComponentLists.${vcfComponent} | where {$_.productVersion -match $vcfVersion}).artifacts.bundles | where {$vcfTypes -contains $_.type}).binaries.fileName

    foreach ($vcfComponentFileName in $vcfComponentFileNames) {
        if($downloadedFiles -notcontains $vcfComponentFileName) {
            $vcfComponentDownloadUrl = "${vcfBaseUri}COMP/${vcfComponent}/${vcfComponentFileName}"

            if($vcfComponent -eq "NSX_T_MANAGER") {
                if ($vcfComponentFileName -match "\.(\d+)\.ova$") {
                    $componentVersion = $matches[1]

                    $vcfComponentMetadataFilename = "VMware-NSX-T-${vcfVersion}.${componentVersion}.vlcp"
                    $vcfComponentMetadataDownloadUrl = "${vcfBaseUri}COMP/${vcfComponent}/${vcfComponentMetadataFilename}"

                    Write-ColoredHost "Downloading ${vcfComponentMetadataFilename} ..."
                    if($dryRun -eq $false) {
                        Invoke-WebRequest -Uri $vcfComponentMetadataDownloadUrl -OutFile "PROD/COMP/${vcfComponent}/${vcfComponentMetadataFilename}"
                    }
                }
            }

            Write-ColoredHost "`tDownloading ${vcfComponentFileName} ..."
            if($dryRun -eq $false) {
                Invoke-WebRequest -Uri $vcfComponentDownloadUrl -OutFile "${vcfComponentDownloadDirectory}/${vcfComponentFileName}"
            }

            $downloadedFiles+=$vcfComponentFileName
        }
    }
}

Set-Location $cwd