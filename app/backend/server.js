// ── OpenTelemetry MUST be initialized before any other require ────────────────
require('./tracing');

const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const { register, Counter, Histogram, Gauge } = require('prom-client');
const { trace, SpanStatusCode, SpanKind } = require('@opentelemetry/api');

const app = express();
const port = process.env.PORT || 3000;
const tracer = trace.getTracer('backend-api');

// ── Custom Prometheus metrics ─────────────────────────────────────────────────
const httpRequestsTotal = new Counter({
  name: 'api_requests_total',
  help: 'Total number of API requests',
  labelNames: ['method', 'route', 'status_code'],
});

const httpRequestDuration = new Histogram({
  name: 'api_request_duration_seconds',
  help: 'API request duration in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
});

const dbItemsGauge = new Gauge({
  name: 'db_items_total',
  help: 'Total number of items currently in the database',
});

// ── Middleware to record request metrics ──────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const route = req.route ? req.route.path : req.path;
    httpRequestsTotal.inc({ method: req.method, route, status_code: res.statusCode });
    httpRequestDuration.observe({ method: req.method, route }, (Date.now() - start) / 1000);
  });
  next();
});

// ── Rate limiting ─────────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests from this IP, please try again later.',
});
app.use('/api/', limiter);

// ── General middleware ────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Database connection ───────────────────────────────────────────────────────
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'cloudnative',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

// ── Shared semantic attributes ────────────────────────────────────────────────
// Returns standard OTel database semantic convention attributes.
function dbAttributes(operation) {
  return {
    'db.system': 'postgresql',
    'db.operation': operation,
    'db.sql.table': 'items',
    'net.peer.name': process.env.DB_HOST || 'localhost',
    'net.peer.port': Number(process.env.DB_PORT) || 5432,
  };
}

// ── Routes ────────────────────────────────────────────────────────────────────

// Health check — no custom span (auto-instrumented by OTel HTTP middleware)
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'backend-api' });
});

// Expose Prometheus metrics (OTel Prometheus exporter + prom-client)
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Get all items
app.get('/api/items', async (req, res) => {
  const span = tracer.startSpan('db.items.list', {
    kind: SpanKind.CLIENT,
    attributes: {
      'http.method': req.method,
      'http.route': '/api/items',
      ...dbAttributes('SELECT'),
    },
  });
  try {
    const result = await pool.query('SELECT * FROM items ORDER BY id DESC');
    span.setAttribute('db.rows_returned', result.rowCount);
    dbItemsGauge.set(result.rowCount);
    span.setStatus({ code: SpanStatusCode.OK });
    res.json(result.rows);
  } catch (err) {
    span.recordException(err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    console.error('Error fetching items:', err);
    res.status(500).json({ error: 'Failed to fetch items' });
  } finally {
    span.end();
  }
});

// Create new item
app.post('/api/items', async (req, res) => {
  const { name, description } = req.body;
  const span = tracer.startSpan('db.items.create', {
    kind: SpanKind.CLIENT,
    attributes: {
      'http.method': req.method,
      'http.route': '/api/items',
      'item.name': name || '',
      ...dbAttributes('INSERT'),
    },
  });
  try {
    const result = await pool.query(
      'INSERT INTO items (name, description) VALUES ($1, $2) RETURNING *',
      [name, description]
    );
    const created = result.rows[0];
    span.setAttribute('item.id', String(created.id));
    span.setStatus({ code: SpanStatusCode.OK });
    res.status(201).json(created);
  } catch (err) {
    span.recordException(err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    console.error('Error creating item:', err);
    res.status(500).json({ error: 'Failed to create item' });
  } finally {
    span.end();
  }
});

// Delete item
app.delete('/api/items/:id', async (req, res) => {
  const { id } = req.params;
  const span = tracer.startSpan('db.items.delete', {
    kind: SpanKind.CLIENT,
    attributes: {
      'http.method': req.method,
      'http.route': '/api/items/:id',
      'item.id': id,
      ...dbAttributes('DELETE'),
    },
  });
  try {
    await pool.query('DELETE FROM items WHERE id = $1', [id]);
    span.setStatus({ code: SpanStatusCode.OK });
    res.json({ message: 'Item deleted successfully' });
  } catch (err) {
    span.recordException(err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    console.error('Error deleting item:', err);
    res.status(500).json({ error: 'Failed to delete item' });
  } finally {
    span.end();
  }
});

// ── Start server ──────────────────────────────────────────────────────────────
app.listen(port, () => {
  console.log(`Backend API listening on port ${port}`);
});
