FQDN="depot.corp.internal"

cat > server_openssl.cnf <<EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[ req_distinguished_name ]
C  = US
ST = CA
L  = Palo Alto
O  = WilliamLam
OU = R&D
CN = ${FQDN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${FQDN}
EOF

openssl genrsa -out rootCA.key 4096
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config server_openssl.cnf
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.pem -subj "/C=US/ST=CA/L=Palo Alto/O=WilliamLam/OU=R&D/CN=WilliamLam-RootCA"
openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 825 -sha256 -extensions req_ext -extfile server_openssl.cnf
cat server.crt rootCA.pem > depot-fullchain.pem
# python3 http_server_auth.py --bind 0.0.0.0 --user vcf --password VMware1!VMware1! --port 443 --directory /root/tonjiak/vcf9/offlinedepot/depot/vcf9.1 \
#  --certfile server.crt --keyfile server.key &
