# Helm + Observability Demo

This demo packages the 3-tier cloud-native app into a Helm chart and adds a full
observability stack: **OpenTelemetry** instrumentation → **Prometheus** metrics →
**Grafana** dashboards

---

## Prerequisites

| Tool | Min version | Install |
|------|-------------|---------|
| Minikube | 1.32 | `brew install minikube` |
| Helm | 3.14 | `brew install helm` |
| kubectl | 1.28 | `brew install kubectl` |

Start Minikube with enough resources for the observability stack:

```bash
minikube start --cpus 4 --memory 6g --driver docker
minikube addons enable ingress
```

---

## Quick Start

### 1 — Add Helm repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana             https://grafana.github.io/helm-charts
helm repo update
```

### 2 — Download sub-chart dependencies

```bash
cd helm/cloud-native-app
helm dependency update
helm template .
```

You should see `charts/` populated with `prometheus-*.tgz`, `grafana-*.tgz`

### 3 — Install the chart

```bash
helm install training . \
  --namespace cloud-native-metrics \
  --create-namespace \
  --wait \
  --timeout 5m
```

Watch all pods start:

```bash
kubectl get pods -n cloud-native-metrics -w
```

### 4 — Access the application

```bash
# Or use minikube tunnel (in a separate terminal)
minikube tunnel
```

Open http://training.metrics.local in your browser.

---

## Accessing the Observability UIs

### Grafana (port 32000)

```bash
minikube service training-grafana --namespace cloud-native-metrics
# or
kubectl port-forward svc/training-grafana 3000:80 -n cloud-native-metrics
```

- URL: http://localhost:3000  (or the minikube service URL)
- Username: `admin`  Password: `admin123`
- Navigate to **Dashboards → Cloud Native Training → Backend API**

### Prometheus

```bash
kubectl port-forward svc/training-prometheus-server 9090:80 -n cloud-native-metrics
```

- URL: http://localhost:9090
- Try: `api_requests_total`, `api_request_duration_seconds_bucket`, `db_items_total`


### Step 2 — Show OpenTelemetry instrumentation

Open [app/backend/tracing.js](../app/backend/tracing.js):

```javascript
// Key concepts:
// 1. Must be required FIRST — before express, pg, etc.
// 2. NodeSDK auto-instruments HTTP, Express, and pg via auto-instrumentations-node
// 3. PrometheusExporter serves /metrics (proxied through Express on port 3000)
// 4. OTLPTraceExporter sends spans to Jaeger via gRPC
```

Open [app/backend/server.js](../app/backend/server.js):

```javascript
// Custom metrics added:
// - api_requests_total (Counter)   — requests by method/route/status
// - api_request_duration_seconds (Histogram) — latency distribution
// - db_items_total (Gauge)         — live item count from DB
//
// Custom spans added to each route handler:
// - db.items.list / db.items.create / db.items.delete
// - span attributes: db.rows_returned, item.name, item.id
```

Verify the metrics endpoint is working:

```bash
kubectl port-forward svc/backend-service 3000:3000 -n cloud-native-training
curl http://localhost:3000/metrics
```

### Step 3 — Generate traffic

```bash
# In a separate terminal — generates continuous traffic for the Grafana demo
while true; do
  curl -s http://training.metrics.local/api/items > /dev/null
  curl -s -X POST http://training.metrics.local/api/items \
    -H 'Content-Type: application/json' \
    -d '{"name":"Load test item","description":"generated"}' > /dev/null
  sleep 0.5
done
```

### Step 4 — Show Grafana dashboard

1. Open Grafana → **Dashboards → Cloud Native Training → Backend API**
2. Walk through each panel:
   - **Request Rate** — rises with the load generator
   - **Error Rate** — should stay near 0%
   - **P99 Latency** — typical is < 50 ms for healthy DB
   - **Items in Database** — grows as POST requests land
   - **Request Rate by Endpoint** — shows GET vs POST breakdown
   - **Latency Percentiles** — p50/p90/p99 over time
   - **HTTP Status Code Distribution** — 2xx dominates

### Step 6 — Scale up and observe

```bash
# Scale backend to 5 replicas
helm upgrade training . \
  --namespace cloud-native-metrics \
  --set backend.replicaCount=5

# Watch new pods appear
kubectl get pods -n cloud-native-training -w
```

In Grafana:
- The **Backend Pod Count** panel increases to 5
- Request rate distributes across pods (load balancer)

Scale back down:

```bash
helm upgrade training . \
  --namespace cloud-native-training \
  --set backend.replicaCount=3
```

### Step 7 — Helm upgrade with value override

Show how easy it is to change configuration without touching YAML files:

```bash
# Check rollout
kubectl rollout status deployment/backend-deployment -n cloud-native-metrics
```

### Step 8 — Helm rollback

```bash
# View release history
helm history training -n cloud-native-metrics

# Roll back to the previous release
helm rollback training -n cloud-native-metrics
```

---

## Cleanup

```bash
helm uninstall training -n cloud-native-metrics
kubectl delete namespace cloud-native-metrics
```

---

## Key Commands Reference

| Command | Purpose |
|---------|---------|
| `helm lint .` | Validate chart syntax |
| `helm template . --debug` | Render manifests locally |
| `helm dependency update` | Download sub-charts |
| `helm install training . -n ...` | Install |
| `helm upgrade training . -n ...` | Upgrade (rolling update) |
| `helm rollback training -n ...` | Roll back to previous |
| `helm history training -n ...` | Show release history |
| `helm uninstall training -n ...` | Remove all resources |
| `helm get values training -n ...` | Show active values |
| `helm get manifest training -n ...` | Show deployed manifests |
