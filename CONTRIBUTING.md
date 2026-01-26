# Contributing to Cloud Native Training

Thank you for your interest in contributing to this training repository! This guide will help you get started.

## Ways to Contribute

### 1. Reporting Issues
- Found a bug in the code?
- Documentation unclear or incorrect?
- Demo not working as expected?

Please open an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Docker version, etc.)

### 2. Improving Documentation
- Fix typos or grammar
- Add clarifications
- Improve examples
- Add troubleshooting tips
- Translate to other languages

### 3. Adding New Demos
- New Docker concepts
- Additional Kubernetes resources
- Advanced topics
- Real-world scenarios

### 4. Enhancing the Application
- Improve UI/UX
- Add new features
- Optimize performance
- Add tests

## How to Contribute

### Step 1: Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR-USERNAME/cloud-native-training.git
cd cloud-native-training
```

### Step 2: Create a Branch

```bash
# Create a descriptive branch name
git checkout -b feature/add-new-demo
# or
git checkout -b fix/docker-compose-issue
```

### Step 3: Make Your Changes

- Follow existing code style
- Test your changes thoroughly
- Update documentation if needed
- Keep commits focused and clear

### Step 4: Test Your Changes

```bash
# Test Docker changes
docker compose up -d
# Verify functionality
docker compose down -v

# Test Kubernetes changes
minikube start
kubectl apply -f kubernetes/
# Verify functionality
kubectl delete namespace cloud-native-training
```

### Step 5: Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a clear message
git commit -m "Add demo for Kubernetes ConfigMaps"
```

### Step 6: Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/add-new-demo

# Go to GitHub and create a Pull Request
```

## Contribution Guidelines

### Code Style

**Dockerfile**
- Use official base images
- Minimize layers
- Use multi-stage builds when appropriate
- Add comments for complex steps

**Kubernetes Manifests**
- Use YAML format
- Include comments explaining resources
- Follow naming conventions
- Include resource limits

**Documentation**
- Use clear, simple language
- Include code examples
- Add troubleshooting sections
- Keep formatting consistent

### Commit Messages

Good commit messages:
- Start with a verb (Add, Fix, Update, Remove)
- Be specific and concise
- Reference issue numbers if applicable

Examples:
```
Add demo for Kubernetes Secrets
Fix docker-compose volume mount issue
Update README with troubleshooting tips
Remove deprecated API version from manifests
```

### Pull Request Guidelines

Your PR should:
- Have a clear title and description
- Reference related issues
- Include tests if adding new features
- Update documentation if needed
- Pass all checks
- Be focused on a single concern

### Testing Checklist

Before submitting, verify:
- [ ] Docker Compose works
- [ ] Kubernetes manifests are valid
- [ ] Documentation is accurate
- [ ] Examples work as described
- [ ] No broken links
- [ ] Scripts are executable
- [ ] No sensitive data included

## Types of Contributions We're Looking For

### High Priority
- Bug fixes
- Documentation improvements
- Troubleshooting guides
- Better error messages
- Performance optimizations

### Welcome Additions
- New demos for existing topics
- Additional Kubernetes resources (StatefulSets, Jobs, etc.)
- Advanced scenarios
- Integration with other tools
- Alternative implementations

### Not Currently Accepting
- Major architectural changes
- Different programming languages (unless for specific demos)
- Production-specific configurations
- Complex third-party dependencies

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Focus on what's best for the community
- Show empathy towards others
- Accept constructive criticism gracefully
- Help others learn

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information

## Questions?

- Open an issue for general questions
- Tag your issue with "question"
- Check existing issues and documentation first

## Recognition

Contributors will be:
- Listed in the repository contributors
- Mentioned in release notes for significant contributions
- Acknowledged in documentation they create

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Getting Help

If you need help:
1. Check the [README.md](README.md)
2. Read the [TESTING.md](TESTING.md) guide
3. Search existing issues
4. Open a new issue with the "question" label

Thank you for helping make cloud native technology more accessible to everyone! 🚀
