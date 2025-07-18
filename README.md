# Finalcut-git (UNFlab)

**Finalcut-git** (also known as **UNFlab** by the team at Unnamed Films) is an open-source solution for synchronizing Final Cut Pro libraries between remote editors. It provides a user-friendly interface for Git-based version control specifically designed for video editing workflows.

## What It Does

Finalcut-git solves the common problem of collaborating on Final Cut Pro projects across multiple editors and locations. It provides:

- **Project Check-in/Check-out System**: Prevents conflicts by allowing only one editor to work on a project at a time
- **Automatic File Syncing**: Keeps project files synchronized across all team members
- **Smart Media Handling**: Prevents relinking issues by excluding media files from sync
- **Offload Management**: Built-in tools for managing footage offloads from SD cards
- **Conflict Resolution**: Handles Git conflicts with user-friendly interfaces

## Why It Was Created

In September 2024, our team was in the middle of a busy wedding season when our existing sync tool (PostLab) completely broke down. We couldn't check projects in, were getting constant conflicts, and had about half a dozen projects corrupted. After poor support experiences and discovering that PostLab 2 doesn't even sync projects anymore (the main reason we used it), we decided to build our own solution.

This tool was created during a four-hour plane ride and has been successfully used in production ever since.

## How It Works

### Core Architecture

Finalcut-git consists of two main components:

1. **Client Application** (`user/` directory): A macOS application built with Platypus that provides the user interface
2. **Git Server** (`server/` directory): A Docker-based Git server for storing and managing project repositories

### Workflow

1. **Setup**: Users configure the application with server details and generate SSH keys
2. **Checkout**: Editors "check out" a project, which downloads it locally and locks it for exclusive editing
3. **Editing**: Users work on the project normally in Final Cut Pro
4. **Check-in**: When done, users "check in" the project with a commit message, uploading changes and releasing the lock
5. **Sync**: Other team members can then check out the updated project

### Smart File Handling

The system uses a carefully crafted `.gitignore` file that:
- Excludes media files (`Original Media`, `Proxy Media`, `Transcoded Media`, etc.)
- Excludes render files and analysis files
- Excludes Final Cut Pro cache and temporary files
- Only syncs the actual project files and settings

This prevents massive repository sizes while ensuring project integrity.

## Features

### Git Operations
- **Checkout**: Download and lock a project for editing
- **Check-in**: Upload changes and release the lock
- **Quick Save**: Create checkpoints without checking in
- **Conflict Resolution**: Handle merge conflicts with guided resolution
- **Repository Management**: Clean up cached repositories

### Offload Management
- **SD Card Offload**: Automatically organize footage from SD cards
- **File Renaming**: Consistent naming conventions for media files
- **Progress Tracking**: Visual feedback during large file operations
- **Queue Management**: Handle multiple offload operations

### User Interface
- **Status Bar App**: Quick access to checked out projects
- **Progress Bar Interface**: Visual feedback for long operations
- **Droplet App**: Drag-and-drop offload functionality

## Installation & Setup

### Prerequisites

- **macOS**: The client application runs on macOS
- **Git**: Xcode Command Line Tools (includes Git)
- **Docker**: For the server component (optional - you can use any Git server)
- **Platypus**: For building the macOS application (included in build process)

### Server Setup

#### Option 1: Docker Server (Recommended)

1. **Install Docker and Docker Compose**
   ```bash
   # Install via Homebrew
   brew install docker docker-compose
   ```

2. **Set up the server**
   ```bash
   cd server
   ./setup-docker.sh
   ```

3. **Add SSH keys**
   ```bash
   # Copy your public key to the authorized_keys file
   cat ~/.ssh/id_rsa.pub >> ssh_keys/authorized_keys
   ```

4. **Start the server**
   ```bash
   docker-compose up -d
   ```

5. **Create repositories**
   ```bash
   # Create a new repository
   docker exec finalcut-git-server /home/git/scripts/create-repo.sh PROJECT_NAME
   ```

#### Option 2: Custom Git Server

You can use any Git server (GitHub, GitLab, self-hosted, etc.) by:
1. Creating bare repositories
2. Adding the `.gitignore` template to each repository
3. Configuring SSH access

### Client Setup

1. **Build the application**
    Ensure that you have Platypus Command Line Toolks installed.  Then: 
   ```bash
   cd user
   ./compile.sh --build
   ```

2. **Install the application**
   - The build process will create applications in `/Applications/`
   - Main app: `UNFlab.app`
   - Progress app: `UNFlab Progress.app`
   - Offload app: `UNFlab Offload.app`

3. **First-time setup**
   - Launch `UNFlab.app`
   - Enter your Git server details (address, port, path)
   - The app will generate an SSH key for you
   - Copy the SSH key and add it to your server's authorized_keys

4. **Configure project folders**
   - Set your checked-out projects folder (default: `~/fcp-git/checkedout`)
   - Set your checked-in projects folder (default: `~/fcp-git/.checkedin`)

## Usage

### Basic Workflow

1. **Check out a project**
   - Open UNFlab from the status bar
   - Select "Checkout" from the menu
   - Choose a repository from the list
   - Enter a reason for checking out
   - The project will download and open in Final Cut Pro

2. **Work on the project**
   - Edit normally in Final Cut Pro
   - Use "Quick Save" to create checkpoints without checking in

3. **Check in the project**
   - Select "Check In" from the UNFlab menu
   - Choose the project to check in
   - Enter a commit message describing your changes
   - The project will upload and release the lock

### Offload Management

1. **Drag and drop offload**
   - Drag an SD card folder onto the UNFlab Offload app
   - Enter project details and source name
   - Choose offload type (video, audio, maintain structure)
   - The app will organize and rename your footage

2. **Queue management**
   - Multiple offloads can be queued
   - Progress is shown for each operation
   - Files are automatically organized by type and date

### Advanced Features

- **Auto-checkpoint**: Automatically save checkpoints during editing
- **Conflict resolution**: Guided interface for resolving Git conflicts
- **Repository cleanup**: Remove cached repositories to free space
- **Connectivity checking**: Verify server connection before operations

## Configuration

### Client Configuration

The client stores configuration in `~/fcp-git/.config`:
- `SERVER_ADDRESS`: Your Git server address
- `SERVER_PORT`: SSH port (usually 22)
- `SERVER_PATH`: Path to repositories on server (usually `~/repositories`)

### Server Configuration

The Docker server configuration is in `server/docker-compose.yml`:
- SSH port mapping (default: 2222)
- Volume mounts for repositories and SSH keys
- Container resource limits

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify your SSH key is in the server's authorized_keys
   - Check server address and port
   - Test SSH connection manually: `ssh -p 2222 git@your-server`

2. **Repository Not Found**
   - Ensure the repository exists on the server
   - Check the SERVER_PATH configuration
   - Verify repository permissions

3. **Check-in/Check-out Fails**
   - Check if files are open in Final Cut Pro
   - Verify Git connectivity
   - Check for conflicts in the repository

4. **Offload Issues**
   - Ensure sufficient disk space
   - Check file permissions on destination
   - Verify SD card is properly mounted

### Logs and Debugging

- **Log location**: `~/fcp-git/logs/fcpgit-YYYY-MM-DD.log`
- **Debug mode**: Run with `--debug` flag for console output
- **Log copying**: Error dialogs automatically copy logs to Desktop

## Development

### Building from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-repo/finalcut-git.git
   cd finalcut-git
   ```

2. **Compile scripts**
   ```bash
   cd user
   ./compile.sh --no-build
   ```

3. **Test the script**
   ```bash
   ./build/fcp-git-user.sh --debug
   ```

4. **Build applications**
   ```bash
   ./compile.sh --build
   ```

### Project Structure

```
finalcut-git/
├── user/                    # Client application
│   ├── functions/          # Bash script modules
│   ├── app/               # Platypus configuration
│   ├── compile.sh         # Build script
│   └── build/             # Compiled output
├── server/                 # Git server
│   ├── docker-compose.yml # Docker configuration
│   ├── Dockerfile         # Server image
│   └── scripts/           # Server management scripts
└── README.md              # This file
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines and contribution information.

## License

Just, like, have fun

## Support

For issues and questions:
- Check the troubleshooting section above
- Review the logs in `~/fcp-git/logs/`
- Open an issue on the GitHub repository

---

**Note**: This tool is designed for professional video editing workflows. Always backup your projects before using any version control system.