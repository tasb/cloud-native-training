# Backend Dockerfile
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY server.js .

# Expose port
EXPOSE 3000

# Set environment variables
ENV PORT=3000

# Start the application
CMD ["node", "server.js"]
