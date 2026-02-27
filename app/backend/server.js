// ── OpenTelemetry MUST be initialized before any other require ────────────────
require('./tracing');

const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const { register, Counter, Histogram } = require('prom-client');
const { trace, context, SpanStatusCode } = require('@opentelemetry/api');

const app = express();
const port = process.env.PORT || 3000;

// ── Custom Prometheus metrics ─────────────────────────────────────────────────
// These are in addition to the auto-instrumented HTTP metrics from OTel SDK.

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

const dbItemsGauge = new (require('prom-client').Gauge)({
  name: 'db_items_total',
  help: 'Total number of items currently in the database',
});

// ── Middleware to record request metrics ─────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const durationSec = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    httpRequestsTotal.inc({ method: req.method, route, status_code: res.statusCode });
    httpRequestDuration.observe({ method: req.method, route }, durationSec);
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

// ── Routes ────────────────────────────────────────────────────────────────────

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'backend-api' });
});

// Expose Prometheus metrics (collected by OTel Prometheus exporter + prom-client)
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Get all items
app.get('/api/items', async (req, res) => {
  const tracer = trace.getTracer('backend-api');
  const span = tracer.startSpan('db.items.list');
  try {
    const result = await pool.query('SELECT * FROM items ORDER BY id DESC');
    span.setAttribute('db.rows_returned', result.rowCount);
    dbItemsGauge.set(result.rowCount);
    res.json(result.rows);
    span.setStatus({ code: SpanStatusCode.OK });
  } catch (err) {
    console.error('Error fetching items:', err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    res.status(500).json({ error: 'Failed to fetch items' });
  } finally {
    span.end();
  }
});

// Create new item
app.post('/api/items', async (req, res) => {
  const tracer = trace.getTracer('backend-api');
  const span = tracer.startSpan('db.items.create');
  const { name, description } = req.body;
  span.setAttribute('item.name', name || '');
  try {
    const result = await pool.query(
      'INSERT INTO items (name, description) VALUES ($1, $2) RETURNING *',
      [name, description]
    );
    res.status(201).json(result.rows[0]);
    span.setStatus({ code: SpanStatusCode.OK });
  } catch (err) {
    console.error('Error creating item:', err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    res.status(500).json({ error: 'Failed to create item' });
  } finally {
    span.end();
  }
});

// Delete item
app.delete('/api/items/:id', async (req, res) => {
  const tracer = trace.getTracer('backend-api');
  const span = tracer.startSpan('db.items.delete');
  const { id } = req.params;
  span.setAttribute('item.id', id);
  try {
    await pool.query('DELETE FROM items WHERE id = $1', [id]);
    res.json({ message: 'Item deleted successfully' });
    span.setStatus({ code: SpanStatusCode.OK });
  } catch (err) {
    console.error('Error deleting item:', err);
    span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
    res.status(500).json({ error: 'Failed to delete item' });
  } finally {
    span.end();
  }
});

// ── Start server ──────────────────────────────────────────────────────────────
app.listen(port, () => {
  console.log(`Backend API listening on port ${port}`);
});
