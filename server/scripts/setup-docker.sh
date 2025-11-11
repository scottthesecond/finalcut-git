#!/bin/bash

# Finalcut-git Docker Server Setup Script

echo "Setting up Finalcut-git Docker server..."

# Create ssh_keys directory if it doesn't exist
if [ ! -d "ssh_keys" ]; then
    echo "Creating ssh_keys directory..."
    mkdir -p ssh_keys
    chmod 700 ssh_keys
fi

# Create authorized_keys file if it doesn't exist
if [ ! -f "ssh_keys/authorized_keys" ]; then
    echo "Creating authorized_keys file..."
    touch ssh_keys/authorized_keys
    chmod 600 ssh_keys/authorized_keys
fi

# Build and start the container
echo "Building and starting the Docker container..."
docker-compose up -d --build

# Wait a moment for the container to start
sleep 5

# Check if container is running
if docker-compose ps | grep -q "Up"; then
    echo "✅ Docker container is running successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Add SSH public keys to ssh_keys/authorized_keys"
    echo "2. Test connection: ssh -p 2222 git@localhost"
    echo "3. Create a repository: docker exec finalcut-git-server /home/git/scripts/create-repo.sh PROJECT_NAME"
    echo ""
    echo "🔧 Useful commands:"
    echo "  - View logs: docker-compose logs -f"
    echo "  - Stop server: docker-compose down"
    echo "  - Restart server: docker-compose restart"
    echo "  - Access container: docker exec -it finalcut-git-server bash"
    echo ""
    echo "💾 Repository data is stored in Docker volume 'git_repositories'"
    echo "   To backup: docker run --rm -v finalcut-git_git_repositories:/data -v \$(pwd):/backup alpine tar czf /backup/repositories-backup.tar.gz -C /data ."
else
    echo "❌ Failed to start Docker container. Check logs with: docker-compose logs"
    exit 1
fi 