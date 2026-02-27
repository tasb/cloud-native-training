'use strict';

// IMPORTANT: This file must be required FIRST in server.js before any other imports.
// It initializes the OpenTelemetry SDK, which instruments Node.js libraries automatically.

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');
const { Resource } = require('@opentelemetry/resources');
const { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

// ── Prometheus metrics exporter ───────────────────────────────────────────────
// Starts an HTTP server on port 9464 that serves /metrics in Prometheus text format.
// The backend's Express app proxies this endpoint at GET /metrics on port 3000
// so Prometheus only needs to scrape a single port.
const prometheusExporter = new PrometheusExporter(
  { port: 9464, startServer: true },
  () => console.log('[otel] Prometheus metrics server listening on :9464/metrics')
);

// ── OTLP trace exporter ───────────────────────────────────────────────────────
// Sends spans to the OTLP gRPC endpoint defined by OTEL_EXPORTER_OTLP_ENDPOINT
// (e.g. Jaeger all-in-one collector).  Falls back to localhost:4317 for local dev.
const traceExporter = new OTLPTraceExporter();

// ── SDK bootstrap ─────────────────────────────────────────────────────────────
const sdk = new NodeSDK({
  resource: new Resource({
    [SEMRESATTRS_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'backend-api',
    [SEMRESATTRS_SERVICE_VERSION]: process.env.npm_package_version || '2.0.0',
  }),
  traceExporter,
  metricReader: prometheusExporter,
  instrumentations: [
    getNodeAutoInstrumentations({
      // Instrument HTTP, Express and pg automatically.
      // Disable fs instrumentation to reduce noise.
      '@opentelemetry/instrumentation-fs': { enabled: false },
    }),
  ],
});

sdk.start();
console.log('[otel] OpenTelemetry SDK started (traces → OTLP, metrics → Prometheus)');

// Flush and shutdown gracefully on process exit.
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('[otel] SDK shut down cleanly'))
    .catch((err) => console.error('[otel] Error during shutdown', err))
    .finally(() => process.exit(0));
});
