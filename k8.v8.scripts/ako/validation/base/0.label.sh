ENFORCE=privileged
FILENAME=labelall.sh
WARN=baseline
cat > $FILENAME<<EOF
kubectl label --overwrite ns --all  pod-security.kubernetes.io/enforce=$ENFORCE pod-security.kubernetes.io/warn=$WARN
EOF
chmod 777 $FILENAME
./$FILENAME
