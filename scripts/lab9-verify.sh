#!/usr/bin/env bash
set -euo pipefail

kind create cluster --name lab9 --config k8s/kind.yaml --wait 3m
trap 'kind delete cluster --name lab9' EXIT
kubectl get nodes -o wide
kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl rollout status deployment/web-app-deployment --timeout=180s
echo '=== Initial state: two replicas ==='
kubectl get deployments,pods,services

kubectl scale deployment web-app-deployment --replicas=4
kubectl rollout status deployment/web-app-deployment --timeout=180s
echo '=== Four replicas ==='
kubectl get pods -l app=web-app
curl --fail --silent --show-error --retry 8 --retry-connrefused --retry-delay 1 \
  -o /dev/null -w 'NodePort 30080: HTTP %{http_code}\n' http://127.0.0.1:30080/

kubectl set image deployment/web-app-deployment web-server=nginx:1.26-alpine
kubectl rollout status deployment/web-app-deployment --timeout=180s
kubectl rollout history deployment/web-app-deployment
kubectl get deployment web-app-deployment -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

kubectl rollout undo deployment/web-app-deployment
kubectl rollout status deployment/web-app-deployment --timeout=180s
image=$(kubectl get deployment web-app-deployment -o jsonpath='{.spec.template.spec.containers[0].image}')
test "$image" = nginx:1.25-alpine
echo "Image after rollback: $image"
kubectl get pods -l app=web-app
count=$(kubectl get deployment web-app-deployment -o jsonpath='{.status.readyReplicas}')
type=$(kubectl get service web-app-service -o jsonpath='{.spec.type}')
test "$count" = 4 && test "$type" = NodePort
printf '%s\n%s\n' "$count" "$type" > lab9_k8s_status.txt
git log -n 1 --oneline | sha256sum | awk '{print $1}' >> lab9_k8s_status.txt
echo 'Blueprint (ready Pods, Service type, Git SHA-256):'
cat lab9_k8s_status.txt
