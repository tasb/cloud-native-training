# Helm + Observability Demo

This demo packages the 3-tier cloud-native app into a Helm chart with a full
observability stack: **OpenTelemetry** → **Prometheus** metrics → **Grafana** dashboards → **Jaeger** traces.

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

## Setup

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
```

You should see `charts/` populated with `prometheus-*.tgz` and `grafana-*.tgz`.

### 3 — Install the chart

```bash
helm upgrade training . \
  --namespace cloud-native-metrics \
  --create-namespace \
  --install \
  --wait \
  --timeout 5m
```

### 4 — Verify all pods are running

```bash
kubectl get pods -n cloud-native-metrics
```

Expected output: `frontend`, `backend`, `postgres`, `jaeger`, `training-prometheus-server`, and `training-grafana` pods all in `Running` state.

---

## Access the App

Start the Minikube tunnel (keep it running in a dedicated terminal):

```bash
minikube tunnel
```

Open the app in your browser: **http://training.metrics.local**

---

## Observability UIs

Open each in a separate terminal and leave them running during the demo.

### Grafana

```bash
kubectl port-forward svc/training-grafana 3000:80 -n cloud-native-metrics
```

- URL: **http://localhost:3000**
- Username: `admin` / Password: `admin123`
- Navigate to **Dashboards → Cloud Native Training → Backend API**

> **NodePort alternative:** `minikube service training-grafana --namespace cloud-native-metrics` (port 32500)

### Prometheus

```bash
kubectl port-forward svc/training-prometheus-server 9090:80 -n cloud-native-metrics
```

- URL: **http://localhost:9090**

### Jaeger

```bash
kubectl port-forward svc/jaeger 16686:16686 -n cloud-native-metrics
```

- URL: **http://localhost:16686**

---

## Demo Walkthrough

### Step 1 — Generate traffic

Run this loop in a dedicated terminal to produce a steady stream of requests:

```bash
while true; do
  curl -s http://training.metrics.local/api/items > /dev/null
  curl -s -X POST http://training.metrics.local/api/items \
    -H 'Content-Type: application/json' \
    -d '{"name":"Load test item","description":"generated"}' > /dev/null
  curl -s -X DELETE http://training.metrics.local/api/items/1 > /dev/null
  sleep 5
done
```

### Step 2 — Prometheus: query raw metrics

Open **http://localhost:9090** and try these queries:

| Query | Shows |
|-------|-------|
| `api_requests_total` | Total request count by method / route / status |
| `rate(api_requests_total[1m])` | Requests per second over the last minute |
| `histogram_quantile(0.99, rate(api_request_duration_seconds_bucket[5m]))` | P99 latency |
| `db_items_total` | Current number of items in the database |

### Step 3 — Grafana: live dashboard

Open **http://localhost:3000** → **Dashboards → Cloud Native Training → Backend API**.

Walk through each panel:

- **Request Rate** — rises with the load generator
- **Error Rate** — stays near 0 % for a healthy system
- **P99 Latency** — typically < 50 ms with a local database
- **Items in Database** — grows as POST requests land
- **Request Rate by Endpoint** — GET vs POST breakdown
- **Latency Percentiles** — p50 / p90 / p99 over time
- **HTTP Status Code Distribution** — 2xx dominates

### Step 4 — Jaeger: distributed traces

Open **http://localhost:16686**.

1. In the **Service** dropdown, select `backend-api`.
2. Click **Find Traces** — you'll see one trace per API request.
3. Open any trace to see the full span timeline:
   - The root span carries the `traceparent` injected by the browser (W3C Trace Context).
   - Child spans (`db.items.list`, `db.items.create`, `db.items.delete`) show the PostgreSQL query time.
4. Click a DB span and inspect the tags:
   - `db.system = postgresql`
   - `db.operation = SELECT / INSERT / DELETE`
   - `db.sql.table = items`
   - `net.peer.name` — the database host

### Step 5 — Scale up and observe

```bash
helm upgrade training . \
  --namespace cloud-native-metrics \
  --set backend.replicaCount=3
```

Watch new pods start:

```bash
kubectl get pods -n cloud-native-metrics -w
```

In Grafana the **Backend Pod Count** panel (kube-state-metrics) rises to 3. The request rate
distributes across pods through the ClusterIP load balancer.

Scale back down when done:

```bash
helm upgrade training . \
  --namespace cloud-native-metrics \
  --set backend.replicaCount=1
```

### Step 6 — Helm rollback

Show Helm release history and roll back to the previous revision:

```bash
# View release history
helm history training -n cloud-native-metrics

# Roll back one revision
helm rollback training -n cloud-native-metrics

# Confirm rollout status
kubectl rollout status deployment/backend-deployment -n cloud-native-metrics
```

---

## Cleanup

```bash
helm uninstall training -n cloud-native-metrics
kubectl delete namespace cloud-native-metrics
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `helm lint .` | Validate chart syntax |
| `helm template . --debug` | Render manifests locally |
| `helm dependency update` | Download sub-charts |
| `helm upgrade training . -n cloud-native-metrics --install` | Install or upgrade |
| `helm history training -n cloud-native-metrics` | Show release history |
| `helm rollback training -n cloud-native-metrics` | Roll back to previous revision |
| `helm uninstall training -n cloud-native-metrics` | Remove all resources |
| `helm get values training -n cloud-native-metrics` | Show active values |
| `helm get manifest training -n cloud-native-metrics` | Show deployed manifests |
