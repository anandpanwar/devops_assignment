#!/bin/bash
set -e
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/postgres.yaml
echo "Deployed app and postgres to local cluster"
