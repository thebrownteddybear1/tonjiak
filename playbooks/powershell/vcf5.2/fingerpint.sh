#!/bin/bash
# Get SSL Thumbprint from ESXi hosts 172.16.11.1 to 172.16.11.6

# ============================================================
# CONFIGURATION
# ============================================================
HOSTS=$(seq 1 6 | awk '{print "172.16.11."$1}')

# ============================================================
# MAIN
# ============================================================
echo ""
echo "============================================================"
echo " ESXi SSL Thumbprint Scanner"
echo "============================================================"

for ip in $HOSTS; do
    echo ""
    echo "Scanning $ip ..."

    # Get SHA1 fingerprint
    SHA1=$(echo "" | openssl s_client -connect ${ip}:443 -showcerts 2>/dev/null | \
           openssl x509 -noout -fingerprint -sha1 2>/dev/null | \
           awk -F'=' '{print $2}')

    # Get SHA256 fingerprint
    SHA256=$(echo "" | openssl s_client -connect ${ip}:443 -showcerts 2>/dev/null | \
             openssl x509 -noout -fingerprint -sha256 2>/dev/null | \
             awk -F'=' '{print $2}')

    # Get expiry date
    EXPIRY=$(echo "" | openssl s_client -connect ${ip}:443 -showcerts 2>/dev/null | \
             openssl x509 -noout -enddate 2>/dev/null | \
             awk -F'=' '{print $2}')

    if [ -z "$SHA1" ]; then
        echo "  STATUS  : UNREACHABLE or SSL not available"
    else
        echo "  SHA-1   : $SHA1"
        echo "  SHA-256 : $SHA256"
        echo "  Expiry  : $EXPIRY"
    fi
done

echo ""
echo "============================================================"
echo " DONE"
echo "============================================================"
echo ""