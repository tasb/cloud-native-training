# Docker Demos

This directory contains demos for learning Docker concepts including containers, lifecycle, Dockerfiles, and Docker Compose.

## Prerequisites

- Docker installed on your machine
- Docker Compose installed

## Demo 1: Container Lifecycle

### Build and Run a Single Container

```bash
# Build the backend image
cd app/backend
docker build -t training-backend:latest .

# Run the container
docker run -d --name backend-demo -p 3000:3000 training-backend:latest

# Check running containers
docker ps

# View container logs
docker logs backend-demo

# Stop the container
docker stop backend-demo

# Start the container again
docker start backend-demo

# Remove the container
docker rm -f backend-demo
```

### Container Inspection

```bash
# Inspect container details
docker inspect backend-demo

# View container resource usage
docker stats backend-demo

# Execute commands inside the container
docker exec -it backend-demo sh

# View container processes
docker top backend-demo
```

## Demo 2: Dockerfile Deep Dive

### Backend Dockerfile Analysis

The backend Dockerfile demonstrates:
- Multi-stage builds concept (using node:18-alpine base image)
- WORKDIR instruction
- COPY instruction for dependencies first (caching optimization)
- RUN instruction for installing dependencies
- COPY instruction for application code
- EXPOSE instruction for documentation
- ENV instruction for environment variables
- CMD instruction for starting the application

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY server.js .
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
```

### Frontend Dockerfile Analysis

The frontend Dockerfile demonstrates:
- Using official nginx image
- COPY instruction for static files
- EXPOSE instruction
- CMD instruction with nginx configuration

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Building Images

```bash
# Build backend image
docker build -t training-backend:latest ./app/backend

# Build frontend image
docker build -t training-frontend:latest ./app/frontend

# List images
docker images

# Inspect image
docker image inspect training-backend:latest

# View image history
docker history training-backend:latest

# Remove image
docker rmi training-backend:latest
```

## Demo 3: Docker Compose - Multi-Container Application

### Understanding docker-compose.yml

The compose file defines a complete 3-tier application:
- **Database**: PostgreSQL with persistent volume
- **Backend**: Node.js API connected to database
- **Frontend**: Nginx serving static HTML

Key concepts demonstrated:
- Service definition
- Environment variables
- Port mapping
- Volume mounting
- Service dependencies
- Health checks
- Network creation (automatic)

### Running with Docker Compose

```bash
# Start all services
docker-compose up -d

# View running services
docker-compose ps

# View logs
docker-compose logs -f

# View logs for specific service
docker-compose logs -f backend

# Scale a service (if applicable)
docker-compose up -d --scale backend=3

# Stop all services
docker-compose stop

# Start all services
docker-compose start

# Restart a specific service
docker-compose restart backend

# Stop and remove all containers
docker-compose down

# Stop and remove containers, networks, and volumes
docker-compose down -v
```

### Testing the Application

1. Start the services:
   ```bash
   docker-compose up -d
   ```

2. Wait for all services to be healthy:
   ```bash
   docker-compose ps
   ```

3. Access the application:
   - Frontend: http://localhost:8080
   - Backend API: http://localhost:3000/health
   - Database: localhost:5432

4. Test the API:
   ```bash
   # Check health
   curl http://localhost:3000/health
   
   # Get items
   curl http://localhost:3000/api/items
   
   # Add item
   curl -X POST http://localhost:3000/api/items \
     -H "Content-Type: application/json" \
     -d '{"name":"Test","description":"Test item"}'
   ```

## Demo 4: Container Networking

```bash
# Start services
docker-compose up -d

# List networks
docker network ls

# Inspect the network created by compose
docker network inspect cloud-native-training_default

# Connect to backend container and test connectivity
docker exec -it training-backend sh
# Inside container:
# ping database
# curl http://database:5432
```

## Demo 5: Volumes and Persistence

```bash
# List volumes
docker volume ls

# Inspect the postgres volume
docker volume inspect cloud-native-training_postgres-data

# Add data through the application
# Then remove containers but keep volumes
docker-compose down

# Start again - data persists
docker-compose up -d

# Remove everything including volumes
docker-compose down -v
```

## Demo 6: Environment Variables

```bash
# Override environment variables
docker-compose up -d -e DB_PASSWORD=newsecret

# Or create a .env file
echo "DB_PASSWORD=newsecret" > .env
docker-compose up -d
```

## Demo 7: Building and Rebuilding

```bash
# Build images without starting
docker-compose build

# Force rebuild and start
docker-compose up -d --build

# Build specific service
docker-compose build backend

# No cache build
docker-compose build --no-cache
```

## Troubleshooting

### Check container health
```bash
docker-compose ps
docker inspect --format='{{json .State.Health}}' training-backend
```

### View detailed logs
```bash
docker-compose logs --tail=100 -f backend
```

### Enter container for debugging
```bash
docker exec -it training-backend sh
```

### Clean everything
```bash
# Stop and remove containers, networks, volumes, and images
docker-compose down -v --rmi all

# Remove all unused containers, networks, images
docker system prune -a
```

## Key Learning Points

1. **Container Lifecycle**: Create, start, stop, restart, remove
2. **Dockerfile**: Instructions for building images
3. **Image Layers**: Understanding caching and optimization
4. **Docker Compose**: Multi-container orchestration
5. **Networking**: Inter-container communication
6. **Volumes**: Data persistence
7. **Environment Variables**: Configuration management
8. **Health Checks**: Monitoring container health
9. **Dependencies**: Service startup order
