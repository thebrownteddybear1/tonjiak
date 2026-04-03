# Get RSA fingerprints for ESXi hosts 172.16.11.1 to 172.16.11.6

$hosts = 1..6 | ForEach-Object { "172.16.11.$_" }

foreach ($ip in $hosts) {
    Write-Host "`nScanning $ip ..." -ForegroundColor Cyan
    try {
        $result = & ssh-keyscan -t rsa $ip 2>$null
        if ($result) {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            $result | Out-File -FilePath $tmpFile -Encoding ascii
            $fingerprint = & ssh-keygen -lf $tmpFile 2>&1
            Remove-Item $tmpFile -Force
            Write-Host "$ip : $fingerprint" -ForegroundColor Green
        } else {
            Write-Host "$ip : UNREACHABLE or SSH not enabled" -ForegroundColor Red
        }
    } catch {
        Write-Host "$ip : ERROR - $_" -ForegroundColor Red
    }
}