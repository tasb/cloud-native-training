#!/bin/bash

# HPA Load Test Script
# This script helps generate CPU load on backend pods to test Horizontal Pod Autoscaler

set -e

NAMESPACE="cloud-native-training"
DEPLOYMENT="backend-deployment"

echo "🔥 HPA Load Test Script"
echo "======================="
echo ""

usage() {
    echo "Usage: $0 {start|stop}"
    echo ""
    echo "Commands:"
    echo "  start  - Start CPU load on all backend pods"
    echo "  stop   - Stop CPU load on all backend pods"
    exit 1
}

start_load() {
    echo "🚀 Starting CPU load on backend pods..."

    # Get all backend pod names
    PODS=$(kubectl get pods -n $NAMESPACE -l app=backend -o jsonpath='{.items[*].metadata.name}')

    if [ -z "$PODS" ]; then
        echo "❌ No backend pods found. Make sure the deployment is running."
        exit 1
    fi

    echo "Found pods: $PODS"
    echo ""

    # Start load on each pod
    for POD in $PODS; do
        echo "Starting load on pod: $POD"
        kubectl exec -n $NAMESPACE $POD -- sh -c "dd if=/dev/zero of=/dev/null > /dev/null 2>&1 & echo \$! > /tmp/dd.pid" &
    done

    echo ""
    echo "✅ CPU load started on all backend pods"
    echo "Monitor HPA with: kubectl get hpa -n $NAMESPACE -w"
    echo "Monitor pods with: kubectl get pods -n $NAMESPACE -l app=backend -w"
}

stop_load() {
    echo "🛑 Stopping CPU load on backend pods..."

    # Get all backend pod names
    PODS=$(kubectl get pods -n $NAMESPACE -l app=backend -o jsonpath='{.items[*].metadata.name}')

    if [ -z "$PODS" ]; then
        echo "❌ No backend pods found."
        exit 1
    fi

    echo "Found pods: $PODS"
    echo ""

    # Stop load on each pod
    for POD in $PODS; do
        echo "Stopping load on pod: $POD"
        kubectl exec -n $NAMESPACE $POD -- sh -c "pkill -f dd || true"
    done

    echo ""
    echo "✅ CPU load stopped on all backend pods"
    echo "Pods should scale down automatically"
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

case $1 in
    start)
        start_load
        ;;
    stop)
        stop_load
        ;;
    *)
        usage
        ;;
esac