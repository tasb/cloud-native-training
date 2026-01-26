# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is this repository for?
**A:** This is a hands-on training repository for learning cloud native technologies, specifically Docker containers and Kubernetes orchestration. It includes a complete 3-tier web application with comprehensive demos and documentation.

### Q: Who is this training for?
**A:** This training is designed for:
- Developers new to containers and Kubernetes
- DevOps engineers learning cloud native technologies
- System administrators transitioning to containerized environments
- Anyone wanting hands-on experience with Docker and Kubernetes

### Q: Do I need prior experience?
**A:** Basic knowledge of:
- Command line/terminal usage
- Basic understanding of web applications
- Familiarity with YAML format (helpful but not required)

### Q: What will I learn?
**A:** You'll learn:
- Container concepts and lifecycle
- Building Docker images
- Multi-container orchestration with Docker Compose
- Kubernetes pods, deployments, and services
- Kubernetes networking and ingress
- Best practices for cloud native applications

## Setup Questions

### Q: What software do I need?
**A:** Required:
- Docker Desktop (includes Docker and Docker Compose)
- Minikube (for Kubernetes)
- kubectl (Kubernetes CLI)

Optional:
- Git (to clone the repository)
- A code editor (VS Code, Sublime, etc.)

### Q: Can I use Windows?
**A:** Yes! Docker Desktop works on Windows 10/11 with WSL2. Minikube also supports Windows. All commands should work in PowerShell or WSL2.

### Q: Can I use a Mac?
**A:** Yes! Docker Desktop and Minikube both support macOS (Intel and Apple Silicon).

### Q: Can I use Linux?
**A:** Yes! Install Docker Engine, Docker Compose, and Minikube. All commands work natively.

### Q: Do I need a cloud account?
**A:** No! Everything runs locally on your machine using Minikube. No cloud provider needed.

## Docker Questions

### Q: Why use Docker?
**A:** Docker provides:
- Consistent environments (dev, test, production)
- Easy dependency management
- Isolation between applications
- Portable applications
- Efficient resource usage

### Q: What's the difference between an image and a container?
**A:** 
- **Image**: A read-only template with application code, dependencies, and configuration
- **Container**: A running instance of an image

Think of an image as a class and a container as an object.

### Q: What is Docker Compose?
**A:** Docker Compose is a tool for defining and running multi-container applications. It uses a YAML file to configure all services, networks, and volumes.

### Q: How do I stop all containers?
**A:** 
```bash
# With Docker Compose
docker compose down

# All containers
docker stop $(docker ps -aq)
```

### Q: How do I clean up everything?
**A:**
```bash
# Stop and remove containers, networks, volumes
docker compose down -v

# Remove all unused containers, networks, images
docker system prune -a
```

### Q: Why can't I connect to the application?
**A:** Check:
1. Are containers running? `docker compose ps`
2. Are ports exposed? Check docker-compose.yml
3. Is another service using the port? `lsof -i :8080`
4. Check container logs: `docker compose logs`

## Kubernetes Questions

### Q: What is Kubernetes?
**A:** Kubernetes (K8s) is a container orchestration platform that automates deployment, scaling, and management of containerized applications.

### Q: Why use Kubernetes?
**A:** Kubernetes provides:
- Automatic scaling
- Self-healing (restarts failed containers)
- Load balancing
- Rolling updates and rollbacks
- Service discovery
- Configuration management

### Q: What is Minikube?
**A:** Minikube runs a single-node Kubernetes cluster on your local machine for learning and development.

### Q: What's the difference between a Pod and a Container?
**A:**
- **Container**: A single running instance
- **Pod**: The smallest Kubernetes unit, can contain one or more containers that share network and storage

### Q: What's the difference between ReplicaSet and Deployment?
**A:**
- **ReplicaSet**: Maintains a specified number of pod replicas
- **Deployment**: Higher-level concept that manages ReplicaSets and provides declarative updates

Always use Deployments in practice.

### Q: What are the different Service types?
**A:**
- **ClusterIP**: Internal only (default)
- **NodePort**: Exposes service on each node's IP at a static port
- **LoadBalancer**: Creates an external load balancer (requires cloud provider)
- **ExternalName**: Maps to an external DNS name

### Q: How do I access my application in Minikube?
**A:**
```bash
# Via NodePort service
minikube service frontend-nodeport -n cloud-native-training

# Via Ingress (after setting up /etc/hosts)
# Visit http://training.local
```

### Q: Why do I get ImagePullBackOff error?
**A:** The most common reason is that Kubernetes can't find the image. In Minikube:

1. Build images in Minikube's Docker environment:
```bash
eval $(minikube docker-env)
docker build -t training-backend:latest ./app/backend
docker build -t training-frontend:latest ./app/frontend
```

2. Ensure `imagePullPolicy: Never` in your manifests

### Q: How do I update my application?
**A:**
1. Make code changes
2. Rebuild the image
3. Update the deployment:
```bash
kubectl rollout restart deployment backend-deployment -n cloud-native-training
```

### Q: How do I scale my application?
**A:**
```bash
kubectl scale deployment backend-deployment --replicas=5 -n cloud-native-training
```

### Q: What if a pod keeps crashing?
**A:** Debug with:
```bash
# Describe the pod to see events
kubectl describe pod <pod-name> -n cloud-native-training

# Check logs
kubectl logs <pod-name> -n cloud-native-training

# Check previous logs if it crashed
kubectl logs <pod-name> -n cloud-native-training --previous
```

## Application Questions

### Q: What is the application architecture?
**A:** 3-tier architecture:
- **Frontend**: HTML/JavaScript served by Nginx
- **Backend**: Node.js REST API with Express
- **Database**: PostgreSQL with sample data

### Q: How do the services communicate?
**A:**
- Frontend calls Backend API via HTTP
- Backend connects to Database via PostgreSQL protocol
- In Docker: via service names (e.g., `http://backend:3000`)
- In Kubernetes: via service names (e.g., `http://backend-service:3000`)

### Q: Where is the data stored?
**A:**
- **Docker**: In a named volume `postgres-data`
- **Kubernetes**: In `emptyDir` (deleted with pod) - for demo purposes

### Q: How do I add persistent storage in Kubernetes?
**A:** Replace `emptyDir` with a `PersistentVolumeClaim`:
```yaml
volumes:
- name: postgres-storage
  persistentVolumeClaim:
    claimName: postgres-pvc
```

### Q: Can I use a different database?
**A:** Yes! You can replace PostgreSQL with MySQL, MongoDB, or any other database. Update:
1. docker-compose.yml
2. Kubernetes manifests
3. Backend code to use appropriate driver

## Troubleshooting Questions

### Q: I get "permission denied" errors
**A:**
- **Linux**: Add your user to docker group: `sudo usermod -aG docker $USER`
- **Scripts**: Make sure scripts are executable: `chmod +x script.sh`
- **Minikube**: Try `minikube start --driver=docker` as root or with sudo

### Q: Services won't start
**A:** Check:
1. Docker is running: `docker info`
2. No port conflicts: `lsof -i :8080` (or relevant port)
3. Check logs: `docker compose logs` or `kubectl logs`
4. Resource availability: Docker Desktop settings → Resources

### Q: I can't access the application
**A:** For Docker:
```bash
# Check containers are running
docker compose ps

# Check ports are mapped
docker compose ps | grep "0.0.0.0"

# Test backend directly
curl http://localhost:3000/health
```

For Kubernetes:
```bash
# Check pods are ready
kubectl get pods -n cloud-native-training

# Check services have endpoints
kubectl get endpoints -n cloud-native-training

# Use minikube service
minikube service list -n cloud-native-training
```

### Q: Database connection fails
**A:** 
1. Ensure database is healthy:
```bash
# Docker
docker compose logs database

# Kubernetes
kubectl logs deployment/postgres-deployment -n cloud-native-training
```

2. Check environment variables in backend
3. Verify network connectivity

### Q: Changes to code don't appear
**A:**
1. Rebuild the image:
```bash
docker compose up -d --build
```

2. For Kubernetes:
```bash
# Rebuild image
eval $(minikube docker-env)
docker build -t training-backend:latest ./app/backend

# Restart deployment
kubectl rollout restart deployment backend-deployment -n cloud-native-training
```

## Best Practices Questions

### Q: Should I use Docker Compose or Kubernetes for production?
**A:** 
- **Docker Compose**: Good for development and small single-server deployments
- **Kubernetes**: Better for production, especially for:
  - Multiple servers/nodes
  - Auto-scaling requirements
  - High availability needs
  - Complex deployments

### Q: How do I secure my containers?
**A:**
- Don't run as root
- Use official base images
- Scan images for vulnerabilities
- Keep images updated
- Use secrets for sensitive data
- Implement network policies

### Q: What are container best practices?
**A:**
- One process per container
- Make containers ephemeral (stateless)
- Use .dockerignore to exclude files
- Minimize image layers
- Use multi-stage builds
- Tag images properly

## Learning Path Questions

### Q: What order should I follow?
**A:**
1. Start with Docker demos (docker/README.md)
2. Master Docker Compose
3. Move to Kubernetes basics (kubernetes/README.md)
4. Practice with the complete application
5. Experiment with scaling, updates, and troubleshooting

### Q: How long will this take?
**A:**
- Docker basics: 2-4 hours
- Kubernetes basics: 4-6 hours
- Complete training: 1-2 days of focused learning
- Mastery: Weeks of practice!

### Q: What's next after this training?
**A:** Advanced topics to explore:
- Helm (Kubernetes package manager)
- StatefulSets and DaemonSets
- Persistent storage
- Monitoring (Prometheus, Grafana)
- Service meshes (Istio, Linkerd)
- CI/CD pipelines
- Production deployments

### Q: Where can I learn more?
**A:**
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CNCF Training](https://www.cncf.io/certification/training/)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

## Contributing Questions

### Q: Can I contribute to this repository?
**A:** Yes! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Q: I found a bug. What should I do?
**A:** Please open an issue on GitHub with:
- Description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Your environment details

### Q: Can I use this for teaching?
**A:** Absolutely! This repository is open source under MIT License. Feel free to use it for workshops, classes, or self-study.

## Still Have Questions?

- Check the main [README.md](README.md)
- Review [TESTING.md](TESTING.md) for testing procedures
- Search existing GitHub issues
- Open a new issue with the "question" label

Happy Learning! 🚀
