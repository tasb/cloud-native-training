#!/bin/bash

# Quick Start Script for Kubernetes Training with Minikube
# This script helps you get started with Kubernetes demos

set -e

echo "☸️  Cloud Native Training - Kubernetes Quick Start"
echo "=================================================="
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    echo "Visit: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed. Please install Minikube first."
    echo "Visit: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

echo "✅ kubectl is installed"
echo "✅ Minikube is installed"
echo ""

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "🚀 Starting Minikube..."
    minikube start --driver=docker
else
    echo "✅ Minikube is already running"
fi

echo ""
echo "🔌 Enabling Ingress addon..."
minikube addons enable ingress

echo ""
echo "🐳 Building Docker images in Minikube..."
if eval $(minikube docker-env); then
    echo "✅ Connected to Minikube Docker daemon"
else
    echo "❌ Failed to connect to Minikube Docker daemon"
    exit 1
fi

docker build -t training-backend:latest ./app/backend
docker build -t training-frontend:latest ./app/frontend

echo ""
echo "📦 Deploying to Kubernetes..."
kubectl apply -f kubernetes/00-namespace.yaml
kubectl apply -f kubernetes/03-deployments.yaml
kubectl apply -f kubernetes/04-services.yaml
kubectl apply -f kubernetes/05-ingress.yaml

echo ""
echo "⏳ Waiting for pods to be ready..."
if ! kubectl wait --for=condition=ready pod --all -n cloud-native-training --timeout=300s; then
    echo "⚠️  Warning: Some pods may not be ready yet. Check status with:"
    echo "   kubectl get pods -n cloud-native-training"
fi

echo ""
echo "✅ Application deployed to Kubernetes!"
echo ""
echo "📊 Check deployment status:"
echo "   kubectl get all -n cloud-native-training"
echo ""
echo "🌐 Access the application:"
echo "   minikube service frontend-nodeport -n cloud-native-training"
echo ""
echo "🔍 View logs:"
echo "   kubectl logs -f deployment/backend-deployment -n cloud-native-training"
echo ""
echo "🛑 To delete the application:"
echo "   kubectl delete namespace cloud-native-training"
echo ""
echo "⏹️  To stop Minikube:"
echo "   minikube stop"
echo ""

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
echo "💡 Minikube IP: $MINIKUBE_IP"
echo "   Frontend via NodePort: http://$MINIKUBE_IP:30080"
echo "   Backend via NodePort: http://$MINIKUBE_IP:30000/health"
echo ""
