# Finalcut-git Docker Server

This Docker setup provides a containerized Git server for Finalcut-git, making it easy to deploy and manage your Final Cut Pro project repositories.

## Features

- **Ubuntu 22.04** base with Git and SSH pre-installed
- **Dedicated git user** with proper permissions
- **SSH key authentication** (password authentication disabled)
- **Persistent storage** using Docker volumes
- **Easy backup and restore** of repositories
- **Network share ready** - repositories can be easily mapped to external storage

## Quick Start

1. **Prerequisites**
   - Docker and Docker Compose installed
   - SSH public keys ready for authentication

2. **Setup**
   ```bash
   cd server
   ./setup-docker.sh
   ```

3. **Add SSH Keys**
   ```bash
   # Copy your public key to the authorized_keys file
   cat ~/.ssh/id_rsa.pub >> ssh_keys/authorized_keys
   ```

4. **Test Connection**
   ```bash
   ssh -p 2222 git@localhost
   ```

## Usage

### Creating Repositories

```bash
# Create a new repository
docker exec finalcut-git-server /home/git/scripts/create-repo.sh PROJECT_NAME

# Or interactively
docker exec -it finalcut-git-server /home/git/scripts/create-repo.sh
```

### Managing Users

```bash
# Add a new user (SSH key)
docker exec -it finalcut-git-server /home/git/scripts/add-user.sh
```

### Inspecting Repositories

```bash
# List all repositories with sizes
docker exec finalcut-git-server /home/git/scripts/inspect-repos.sh
```

### Updating Gitignore

```bash
# Update .gitignore in all repositories
docker exec finalcut-git-server /home/git/scripts/update-gitignore.sh
```

## Docker Commands

### Basic Operations

```bash
# Start the server
docker-compose up -d

# Stop the server
docker-compose down

# View logs
docker-compose logs -f

# Restart the server
docker-compose restart
```

### Container Access

```bash
# Access the container shell
docker exec -it finalcut-git-server bash

# Run commands as git user
docker exec -it finalcut-git-server su - git
```

## Data Management

### Repository Storage

Repositories are stored in the Docker volume `git_repositories`. This volume persists even when the container is stopped or removed.

### Backup and Restore

**Backup repositories:**
```bash
docker run --rm \
  -v finalcut-git_git_repositories:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/repositories-backup.tar.gz -C /data .
```

**Restore repositories:**
```bash
# Stop the container first
docker-compose down

# Restore from backup
docker run --rm \
  -v finalcut-git_git_repositories:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/repositories-backup.tar.gz -C /data

# Start the container
docker-compose up -d
```

### Network Share Integration

To map the repositories to a network share:

1. **Stop the container:**
   ```bash
   docker-compose down
   ```

2. **Mount your network share:**
   ```bash
   # Example: mount a network share to ./network_repos
   mount -t smbfs //server/share ./network_repos
   ```

3. **Update docker-compose.yml:**
   ```yaml
   volumes:
     - ./network_repos:/home/git/repositories
     - ./ssh_keys:/home/git/.ssh:ro
   ```

4. **Start the container:**
   ```bash
   docker-compose up -d
   ```

## Configuration

### SSH Configuration

The server is configured for SSH key authentication only:
- Password authentication: **Disabled**
- Public key authentication: **Enabled**
- Root login: **Disabled**
- SSH keys location: `ssh_keys/authorized_keys`

### Port Configuration

- **SSH Port**: 2222 (mapped from container port 22)
- **Container Port**: 22 (internal SSH port)

To change the external port, modify the `ports` section in `docker-compose.yml`:
```yaml
ports:
  - "YOUR_PORT:22"
```

## Troubleshooting

### Container Won't Start

1. **Check logs:**
   ```bash
   docker-compose logs
   ```

2. **Check port conflicts:**
   ```bash
   # Check if port 2222 is in use
   lsof -i :2222
   ```

3. **Rebuild container:**
   ```bash
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```

### SSH Connection Issues

1. **Check SSH keys:**
   ```bash
   # Verify authorized_keys file exists and has correct permissions
   ls -la ssh_keys/authorized_keys
   ```

2. **Test SSH connection:**
   ```bash
   ssh -v -p 2222 git@localhost
   ```

3. **Check container SSH service:**
   ```bash
   docker exec finalcut-git-server service ssh status
   ```

### Repository Access Issues

1. **Check repository permissions:**
   ```bash
   docker exec finalcut-git-server ls -la /home/git/repositories/
   ```

2. **Fix permissions if needed:**
   ```bash
   docker exec finalcut-git-server chown -R git:git /home/git/repositories/
   ```

## Security Considerations

- SSH keys are stored in `ssh_keys/authorized_keys` on the host
- Container runs as non-root user (git)
- Password authentication is disabled
- Root login is disabled
- SSH keys should have proper permissions (600)

## File Structure

```
server/
├── docker-compose.yml      # Docker Compose configuration
├── Dockerfile             # Docker image definition
├── setup-docker.sh        # Setup script
├── README-Docker.md       # This file
├── ssh_keys/              # SSH keys directory
│   └── authorized_keys    # Authorized SSH keys
├── create-repo.sh         # Repository creation script
├── add-user.sh           # User management script
├── inspect-repos.sh      # Repository inspection script
├── update-gitignore.sh   # Gitignore update script
└── gitignore-template    # Gitignore template
``` 