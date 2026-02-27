# Backend Dockerfile
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code (including OTel tracing setup)
COPY server.js tracing.js ./

# Expose app port and Prometheus metrics port
EXPOSE 3000 9464

# Set environment variables
ENV PORT=3000 \
    OTEL_SERVICE_NAME=backend-api \
    OTEL_TRACES_SAMPLER=parentbased_always_on

# Start the application
CMD ["node", "server.js"]
