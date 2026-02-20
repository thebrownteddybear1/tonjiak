# 1. Create the new namespace
kubectl create ns nginxdemo

# 2. Relax security so Nginx (root) can run
# VCF 9 defaults to 'restricted' which blocks standard images
kubectl label --overwrite ns nginxdemo pod-security.kubernetes.io/enforce=privileged

# 3. Create the Nginx Deployment and LoadBalancer Service
kubectl apply -n nginxdemo -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  # This triggers NSX to grab an IP from your 10.10.10.0/24 pool
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF

# 4. Immediate status check
echo "--- Status Check ---"
kubectl get pods,svc -n nginxdemo