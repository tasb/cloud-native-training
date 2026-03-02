# Helm + Observability Demo

This demo packages the 3-tier cloud-native app into a Helm chart and adds a full
observability stack: **OpenTelemetry** instrumentation → **Prometheus** metrics →
**Grafana** dashboards + **Jaeger** distributed tracing.

---

## Architecture

```
Browser  ──►  Ingress (training.metrics.local)
                ├── /      → Frontend (Nginx)
                └── /api   → Backend (Node.js + OTel SDK)
                                ├── PostgreSQL
                                ├── GET /metrics ──► Prometheus ──► Grafana
                                └── OTLP/gRPC   ──► Jaeger     ──► Grafana
```

---

## Prerequisites

| Tool | Min version | Install |
|------|-------------|---------|
| Minikube | 1.32 | `brew install minikube` |
| Helm | 3.14 | `brew install helm` |
| kubectl | 1.28 | `brew install kubectl` |

Start Minikube with enough resources for the full stack:

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

> **Note:** Jaeger is deployed via our own template (`templates/jaeger/`) using
> the `jaegertracing/all-in-one` image. The jaegertracing/jaeger Helm chart v4+
> no longer supports in-memory storage, so no Jaeger sub-chart is needed.

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

Expected pods: `frontend`, `backend` (×1), `postgres`, `jaeger`, `prometheus-server`, `grafana`, `kube-state-metrics`.

### 4 — Access the application

```bash
# Add the ingress hostname to /etc/hosts
echo "$(minikube ip) training.metrics.local" | sudo tee -a /etc/hosts

# Or use minikube tunnel (in a separate terminal)
minikube tunnel
```

Open http://training.metrics.local in your browser.

---

## Accessing the Observability UIs

### Grafana (NodePort 32500)

```bash
minikube service training-grafana --namespace cloud-native-metrics
# or
kubectl port-forward svc/training-grafana 3000:80 -n cloud-native-metrics
```

- URL: http://localhost:3000
- Username: `admin`  Password: `admin123`
- Navigate to **Dashboards → Cloud Native Training → Backend API**

### Jaeger

```bash
kubectl port-forward svc/jaeger 16686:16686 -n cloud-native-metrics
```

- URL: http://localhost:16686
- Select service **backend-api** → click **Find Traces**

### Prometheus

```bash
kubectl port-forward svc/training-prometheus-server 9090:80 -n cloud-native-metrics
```

- URL: http://localhost:9090
- Example queries: `api_requests_total`, `api_request_duration_seconds_bucket`, `db_items_total`

---

## Demo Flow (step-by-step)

### Step 1 — Show the Helm chart structure

```
helm/cloud-native-app/
├── Chart.yaml          ← metadata + Prometheus and Grafana sub-chart dependencies
├── values.yaml         ← all configurable defaults (images, replicas, OTel, Jaeger…)
├── dashboards/         ← pre-built Grafana dashboard JSON
└── templates/
    ├── _helpers.tpl    ← reusable named templates (labels, selectors, jaegerEndpoint)
    ├── namespace.yaml
    ├── backend/        ← deployment (with OTel env vars), service, configmap
    ├── frontend/       ← deployment, service
    ├── database/       ← deployment, service, configmap, secret
    ├── jaeger/         ← all-in-one deployment + service (our own template, not sub-chart)
    ├── ingress.yaml
    └── grafana-dashboard-cm.yaml
```

Key talking points:
- `helm template .` renders all manifests without installing — great for review
- `helm lint .` validates syntax
- Sub-charts (Prometheus, Grafana) are listed in `Chart.yaml` `dependencies`
- `values.yaml` controls both our templates AND sub-chart configuration
- Jaeger is a plain Deployment template because the Helm chart v4+ requires a persistent store

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
// Custom metrics:
// - api_requests_total (Counter)              — requests by method/route/status
// - api_request_duration_seconds (Histogram)  — latency distribution
// - db_items_total (Gauge)                    — live item count
//
// Custom spans per route handler:
// - db.items.list / db.items.create / db.items.delete
// - span attributes: db.rows_returned, item.name, item.id
```

Verify the `/metrics` endpoint:

```bash
kubectl port-forward svc/backend-service 3000:3000 -n cloud-native-metrics
curl http://localhost:3000/metrics
```

### Step 3 — Generate traffic

```bash
# Run in a separate terminal to feed Grafana and Jaeger with real data
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
   - **P99 Latency** — typically < 50 ms with a healthy DB
   - **Items in Database** — grows as POST requests land
   - **Request Rate by Endpoint** — GET vs POST breakdown
   - **Latency Percentiles** — p50 / p90 / p99 over time
   - **HTTP Status Code Distribution** — 2xx dominates

### Step 5 — Show distributed traces in Jaeger

1. Open Jaeger UI at http://localhost:16686
2. Select service **backend-api** → click **Find Traces**
3. Click any trace to expand the span tree:

```
HTTP GET /api/items          ← auto-instrumented by OTel HTTP middleware
  └── db.items.list          ← custom span in server.js
        └── pg.query SELECT  ← auto-instrumented by OTel pg library
```

Key teaching points:
- Each HTTP request produces a complete trace automatically (zero manual work for basic spans)
- Custom spans in `server.js` add business context (item counts, IDs)
- The `OTEL_EXPORTER_OTLP_ENDPOINT` env var in the Helm backend deployment points
  to `http://jaeger.cloud-native-metrics.svc.cluster.local:4317` — change this value
  to switch to any OTLP-compatible backend (Grafana Tempo, Honeycomb, etc.)

Filter traces by operation name or tags:

```
Service: backend-api
Operation: db.items.create
```

### Step 6 — Scale up and observe

```bash
helm upgrade training . \
  --namespace cloud-native-metrics \
  --set backend.replicaCount=5

kubectl get pods -n cloud-native-metrics -w
```

In Grafana:
- **Backend Pod Count** panel rises to 5
- Request rate distributes evenly across pods

In Jaeger:
- Traces now show different `net.host.name` values (one per pod)

Scale back down:

```bash
helm upgrade training . \
  --namespace cloud-native-metrics \
  --set backend.replicaCount=1
```

### Step 7 — Helm rollback

```bash
# View release history
helm history training -n cloud-native-metrics

# Roll back to the previous release
helm rollback training -n cloud-native-metrics

# Confirm rollback
kubectl rollout status deployment/backend-deployment -n cloud-native-metrics
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

---

## Troubleshooting

### No metrics in Prometheus

```bash
# Verify /metrics endpoint returns data
kubectl exec -n cloud-native-metrics \
  $(kubectl get pod -l app=backend -n cloud-native-metrics -o name | head -1) \
  -- curl -s http://localhost:3000/metrics | head -20

# Check Prometheus scrape targets
kubectl port-forward svc/training-prometheus-server 9090:80 -n cloud-native-metrics
# Open http://localhost:9090/targets — backend-api should be UP
```

### No traces in Jaeger

```bash
# Check backend logs for OTel errors
kubectl logs -l app=backend -n cloud-native-metrics | grep -i "otel\|otlp\|jaeger"

# Check Jaeger pod is running
kubectl get pod -l app=jaeger -n cloud-native-metrics

# Confirm OTLP endpoint env var is set correctly
kubectl exec -n cloud-native-metrics \
  $(kubectl get pod -l app=backend -n cloud-native-metrics -o name | head -1) \
  -- env | grep OTEL
```

### Grafana datasource shows "no data"

1. Open Grafana → **Configuration → Data Sources**
2. Click **Prometheus** → **Save & test** — should return "Data source is working"
3. Click **Jaeger** → **Save & test** — should return "Data source connected"
4. If the URL is wrong, it must match: `http://jaeger.cloud-native-metrics.svc.cluster.local:16686`
