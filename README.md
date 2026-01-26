# Cloud Native Training

A comprehensive hands-on training repository for learning cloud native technologies, including Docker containers and Kubernetes orchestration.

## 🎯 Training Objectives

This repository provides practical demos and exercises for:

1. **Docker & Containers**
   - Container lifecycle management
   - Building Docker images with Dockerfiles
   - Multi-container orchestration with Docker Compose
   
2. **Kubernetes**
   - Pods - the basic building blocks
   - ReplicaSets - ensuring high availability
   - Deployments - managing application updates
   - Services - networking and load balancing
   - Ingress Controllers - HTTP/HTTPS routing
   - Using Minikube for local development

## 📋 Prerequisites

### Required Software

- **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
- **Docker Compose**: Usually included with Docker Desktop
- **Minikube**: [Install Minikube](https://minikube.sigs.k8s.io/docs/start/)
- **kubectl**: [Install kubectl](https://kubernetes.io/docs/tasks/tools/)

### Verify Installation

```bash
# Check Docker
docker --version
docker-compose --version

# Check Kubernetes tools
minikube version
kubectl version --client
```

## 🏗️ Application Architecture

This training uses a simple 3-tier web application:

```
┌─────────────────────────────────────────────────┐
│                  Frontend                       │
│         (HTML/JavaScript + Nginx)               │
│              Port: 80/8080                      │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│                  Backend API                    │
│            (Node.js + Express)                  │
│                Port: 3000                       │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│                  Database                       │
│              (PostgreSQL)                       │
│                Port: 5432                       │
└─────────────────────────────────────────────────┘
```

### Components

- **Frontend**: Simple HTML/JavaScript UI served by Nginx
  - Automatically detects API endpoint based on hostname
  - Can be configured via `window.API_BASE_URL` if needed
- **Backend**: RESTful API built with Node.js and Express
- **Database**: PostgreSQL database with sample data

## 🐳 Docker Training

### Quick Start with Docker Compose

```bash
# Start all services
docker-compose up -d

# Access the application
# Frontend: http://localhost:8080
# Backend: http://localhost:3000/health
# API: http://localhost:3000/api/items

# Stop all services
docker-compose down
```

### Detailed Docker Demos

See [docker/README.md](docker/README.md) for comprehensive Docker training materials:

- **Demo 1**: Container Lifecycle (build, run, stop, start, remove)
- **Demo 2**: Dockerfile Deep Dive (layers, caching, best practices)
- **Demo 3**: Docker Compose (multi-container apps)
- **Demo 4**: Container Networking
- **Demo 5**: Volumes and Persistence
- **Demo 6**: Environment Variables
- **Demo 7**: Building and Rebuilding

## ☸️ Kubernetes Training

### Quick Start with Kubernetes

```bash
# Start Minikube
minikube start

# Enable ingress
minikube addons enable ingress

# Build images in Minikube
eval $(minikube docker-env)
docker build -t training-backend:latest ./app/backend
docker build -t training-frontend:latest ./app/frontend

# Deploy the application
kubectl apply -f kubernetes/00-namespace.yaml
kubectl apply -f kubernetes/03-deployments.yaml
kubectl apply -f kubernetes/04-services.yaml

# Access the application
minikube service frontend-nodeport -n cloud-native-training
```

### Detailed Kubernetes Demos

See [kubernetes/README.md](kubernetes/README.md) for comprehensive Kubernetes training materials:

- **Demo 1**: Pods (basic building blocks)
- **Demo 2**: ReplicaSets (high availability and self-healing)
- **Demo 3**: Deployments (rolling updates and rollbacks)
- **Demo 4**: Services (ClusterIP, NodePort, LoadBalancer)
- **Demo 5**: Ingress Controller (HTTP routing)

## 📚 Training Structure

```
cloud-native-training/
├── app/
│   ├── frontend/         # Frontend application
│   │   ├── index.html
│   │   ├── Dockerfile
│   │   └── package.json
│   ├── backend/          # Backend API
│   │   ├── server.js
│   │   ├── Dockerfile
│   │   └── package.json
│   └── database/         # Database init scripts
│       └── init.sql
├── docker/
│   └── README.md         # Docker training materials
├── kubernetes/
│   ├── 00-namespace.yaml
│   ├── 01-pod.yaml
│   ├── 02-replicaset.yaml
│   ├── 03-deployments.yaml
│   ├── 04-services.yaml
│   ├── 05-ingress.yaml
│   └── README.md         # Kubernetes training materials
├── docker-compose.yml    # Multi-container orchestration
└── README.md            # This file
```

## 🚀 Getting Started

### Option 1: Docker Compose (Easiest)

Perfect for learning Docker basics:

```bash
# Clone the repository
git clone https://github.com/tasb/cloud-native-training.git
cd cloud-native-training

# Start the application
docker-compose up -d

# View logs
docker-compose logs -f

# Access the app at http://localhost:8080

# Cleanup
docker-compose down -v
```

### Option 2: Kubernetes with Minikube

Perfect for learning Kubernetes:

```bash
# Start Minikube
minikube start

# Build images
eval $(minikube docker-env)
docker build -t training-backend:latest ./app/backend
docker build -t training-frontend:latest ./app/frontend

# Deploy to Kubernetes
kubectl apply -f kubernetes/

# Access the application
minikube service frontend-nodeport -n cloud-native-training

# Cleanup
kubectl delete namespace cloud-native-training
minikube stop
```

## 🧪 Testing the Application

### Using the Web Interface

1. Open http://localhost:8080 (Docker) or use `minikube service` (Kubernetes)
2. Add items using the form
3. View the list of items
4. Delete items as needed

### Using the API

```bash
# Health check
curl http://localhost:3000/health

# Get all items
curl http://localhost:3000/api/items

# Create an item
curl -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"A test item"}'

# Delete an item
curl -X DELETE http://localhost:3000/api/items/1
```

## 📖 Learning Path

### For Docker Training

1. **Start here**: Read [docker/README.md](docker/README.md)
2. **Follow Demo 1**: Learn container lifecycle
3. **Follow Demo 2**: Understand Dockerfiles
4. **Follow Demo 3**: Master Docker Compose
5. **Explore**: Networking, volumes, environment variables

### For Kubernetes Training

1. **Prerequisites**: Complete Docker training first
2. **Start here**: Read [kubernetes/README.md](kubernetes/README.md)
3. **Follow Demo 1**: Learn about Pods
4. **Follow Demo 2**: Understand ReplicaSets
5. **Follow Demo 3**: Master Deployments
6. **Follow Demo 4**: Learn about Services
7. **Follow Demo 5**: Implement Ingress

## 🛠️ Troubleshooting

### Docker Issues

```bash
# Check Docker is running
docker ps

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Clean up everything
docker-compose down -v
docker system prune -a
```

### Kubernetes Issues

```bash
# Check cluster status
minikube status
kubectl cluster-info

# Check pods
kubectl get pods -n cloud-native-training

# View logs
kubectl logs -f deployment/backend-deployment -n cloud-native-training

# Describe resources
kubectl describe pod <pod-name> -n cloud-native-training

# Clean up
kubectl delete namespace cloud-native-training
minikube delete
```

## 🤝 Contributing

This is a training repository. Feel free to:
- Report issues
- Suggest improvements
- Add more examples
- Share your learning experience

## 📝 License

This project is open source and available under the MIT License.

## 🎓 Additional Resources

### Docker
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Kubernetes
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### Cloud Native
- [Cloud Native Computing Foundation (CNCF)](https://www.cncf.io/)
- [The Twelve-Factor App](https://12factor.net/)

## 🏆 Training Completion Checklist

- [ ] Completed Docker Demo 1: Container Lifecycle
- [ ] Completed Docker Demo 2: Dockerfile Deep Dive
- [ ] Completed Docker Demo 3: Docker Compose
- [ ] Completed Kubernetes Demo 1: Pods
- [ ] Completed Kubernetes Demo 2: ReplicaSets
- [ ] Completed Kubernetes Demo 3: Deployments
- [ ] Completed Kubernetes Demo 4: Services
- [ ] Completed Kubernetes Demo 5: Ingress Controller
- [ ] Built and deployed the full application
- [ ] Tested all components working together

---

**Happy Learning! 🚀**