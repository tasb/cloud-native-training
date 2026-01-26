#!/bin/bash

# Quick Start Script for Cloud Native Training
# This script helps you get started with Docker demos

set -e

echo "🚀 Cloud Native Training - Quick Start"
echo "======================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker is installed"
echo "✅ Docker Compose is installed"
echo ""

# Start the application
echo "📦 Starting the application with Docker Compose..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

echo ""
echo "✅ Application is running!"
echo ""
echo "🌐 Access the application:"
echo "   Frontend: http://localhost:8080"
echo "   Backend API: http://localhost:3000/health"
echo "   API Docs: http://localhost:3000/api/items"
echo ""
echo "📊 View logs:"
echo "   docker-compose logs -f"
echo ""
echo "🛑 To stop the application:"
echo "   docker-compose down"
echo ""
echo "🧹 To stop and remove all data:"
echo "   docker-compose down -v"
echo ""

# Open browser (optional)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🌐 Opening browser..."
    open http://localhost:8080
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:8080
    fi
fi
