# 1. Pull the official image from Docker Hub
docker pull nginx:alpine

# 2. Export the image to a tarball file
# Use -o (output) to specify the filename
docker save -o nginx-demo.tar nginx:alpine


1. Export	Local PC	docker save -o nginx-demo.tar nginx:alpine
2. Transfer	Local PC	scp nginx-demo.tar vmware-system-user@<NODE_IP>:/tmp/
3. Import	Worker Node	sudo ctr -n k8s.io images import /tmp/nginx-demo.tar
4. Deploy	Jumpbox	kubectl apply -f demo-app.yaml



apiVersion: v1
kind: Namespace
metadata:
  name: demo-space
  labels:
    # Adding the label you requested
    vcf-usage: demo-apps
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airgapped-demo
  namespace: demo-space
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      # Use the hostname from 'kubectl get nodes'
      nodeSelector:
        kubernetes.io/hostname: "WORKER_NODE_NAME_TEMP"
      containers:
      - name: nginx
        image: docker.io/library/nginx:alpine
        # Crucial for offline nodes
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: demo-service
  namespace: demo-space
spec:
  # This requests an External IP from the VCF Load Balancer
  type: LoadBalancer
  selector:
    app: web-server
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
