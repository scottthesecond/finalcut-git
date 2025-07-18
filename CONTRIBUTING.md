# Contributing to Finalcut-git

This guide explains the codebase structure and how to contribute to the Finalcut-git project. It's designed for both maintainers and contributors.

## Codebase Overview

Finalcut-git is built as a collection of bash scripts that are compiled into macOS applications using Platypus. The architecture follows a modular design with clear separation of concerns.

### Project Structure

```
finalcut-git/
├── user/                           # Client application
│   ├── functions/                  # Core bash script modules
│   │   ├── shared/                # Common utilities and setup
│   │   ├── git/                   # Git operations and UI
│   │   └── offload/               # Media offload functionality
│   ├── app/                       # Platypus configuration files
│   ├── compile.sh                 # Build script that concatenates modules
│   └── build/                     # Compiled output (generated)
├── server/                        # Git server implementation
│   ├── docker-compose.yml         # Docker configuration
│   ├── Dockerfile                 # Server container definition
│   ├── scripts/                   # Server management scripts
│   └── gitignore-template         # Template for repository .gitignore
└── README.md                      # Main documentation
```

## Core Architecture

### Script Compilation System

The application uses a custom build system where individual bash script modules are concatenated into a single executable script:

1. **Module Organization**: Each functionality is split into logical modules
2. **Compilation**: `compile.sh` concatenates modules in dependency order
3. **Platypus Integration**: The compiled script is packaged into macOS applications

### Key Components

#### 1. Shared Modules (`user/functions/shared/`)

**Core Files:**
- `vars.sh`: Global variables and path definitions
- `logs.sh`: Logging and error handling functions
- `config.sh`: Configuration file management
- `setup.sh`: Initial setup and SSH key generation
- `setup_ui.sh`: User interface for configuration
- `dialogs.sh`: AppleScript dialog functions
- `fcp.sh`: Final Cut Pro integration utilities
- `select_repo.sh`: Repository selection interface
- `_main.sh`: Main application loop and argument parsing

**Key Functions:**
- `log_message()`: Write to log file with timestamp
- `handle_error()`: Display error dialogs and copy logs to Desktop
- `display_notification()`: Show macOS notifications
- `show_progress()`: Update progress bar interface

#### 2. Git Operations (`user/functions/git/`)

**Core Operations:**
- `checkout.sh`: Download and lock projects
- `checkin.sh`: Upload changes and release locks
- `checkpoint.sh`: Create quick saves without checking in
- `checkpoint_all.sh`: Save all checked-out projects

**Supporting Modules:**
- `operations/`: Core Git operation logic
- `filesystem/`: File system utilities
- `git_ui.sh`: Git-specific user interface
- `cleanup_ui.sh`: Repository cleanup interface

**Key Functions:**
- `checkout()`: Main checkout workflow
- `checkin()`: Main check-in workflow
- `handle_repo_operation()`: Generic repository operations
- `handle_git_conflict()`: Conflict resolution

#### 3. Offload System (`user/functions/offload/`)

**Core Files:**
- `offload.sh`: Main offload functionality
- `offload_ui.sh`: Offload user interface
- `offload_utils.sh`: Utility functions
- `offload_queue.sh`: Queue management
- `offload_file_utils.sh`: File operation utilities
- `verify.sh`: Offload verification

**Key Functions:**
- `scan_input_directory()`: Scan SD cards for media files
- `copy_files()`: Copy and rename media files
- `queue_offload()`: Add offload to processing queue
- `verify_offload()`: Verify copied files

#### 4. Server Components (`server/`)

**Docker Setup:**
- `docker-compose.yml`: Container orchestration
- `Dockerfile`: Ubuntu-based Git server image
- `setup-docker.sh`: Automated server setup

**Management Scripts:**
- `create-repo.sh`: Create new repositories with .gitignore
- `add-user.sh`: Add SSH keys for new users
- `inspect-repos.sh`: Repository inspection and cleanup
- `update-gitignore.sh`: Update .gitignore in all repositories

## Development Workflow

### Setting Up Development Environment

1. **Clone and setup**
   ```bash
   git clone <repository-url>
   cd finalcut-git
   ```

2. **Install dependencies**
   ```bash
   # Install Platypus (for building macOS apps)
   brew install platypus
   
   # Install Docker (for server development)
   brew install docker docker-compose
   ```

3. **Compile for testing**
   ```bash
   cd user
   ./compile.sh --no-build
   ```

4. **Test the script**
   ```bash
   ./build/fcp-git-user.sh --debug
   ```

### Making Changes

#### 1. Modifying Core Logic

**Adding New Functions:**
1. Create or modify the appropriate module in `user/functions/`
2. Add the function to the module
3. Update `compile.sh` if adding new files
4. Test with `--debug` flag

**Example - Adding a new Git operation:**
```bash
# In user/functions/git/operations/new_operation.sh
new_operation() {
    log_message "Starting new operation"
    # Your logic here
    log_message "Operation completed"
}
```

#### 2. Modifying User Interface

**Dialog Changes:**
- Use `dialogs.sh` functions for consistent UI
- Test on different macOS versions
- Consider accessibility (screen readers, etc.)

**Progress Interface:**
- Use `show_progress()` and `show_details()` for feedback
- Update progress incrementally for long operations
- Provide meaningful status messages

#### 3. Adding New Features

**Feature Development Process:**
1. **Plan**: Define the feature and its requirements
2. **Implement**: Create/modify appropriate modules
3. **Test**: Use `--debug` flag for development testing
4. **Build**: Test the compiled application
5. **Document**: Update relevant documentation

**Example - Adding a new offload type:**
```bash
# 1. Modify offload_utils.sh to add new type
get_type_prefix() {
    case "$1" in
        # ... existing types ...
        "newtype"|"nt")
            echo "NT"
            ;;
    esac
}

# 2. Update offload.sh to handle new type
should_skip_file() {
    # ... existing logic ...
    if [[ "$type" =~ ^(newtype|nt)$ ]]; then
        # New type skip logic
    fi
}
```

### Testing Your Changes

#### 1. Script Testing
```bash
# Test individual modules
bash user/functions/shared/logs.sh

# Test compiled script
./user/build/fcp-git-user.sh --debug

# Test specific operations
./user/build/fcp-git-user.sh --debug checkout
```

#### 2. Application Testing
```bash
# Build applications
cd user
./compile.sh --build

# Test different interfaces
# Status bar: UNFlab.app
# Progress bar: UNFlab Progress.app  
# Droplet: UNFlab Offload.app
```

#### 3. Server Testing
```bash
# Test Docker server
cd server
docker-compose up -d
docker exec finalcut-git-server /home/git/scripts/create-repo.sh test-repo
```

## Common Development Tasks

### Adding New Git Operations

1. **Create operation module** in `user/functions/git/operations/`
2. **Add UI integration** in appropriate UI files
3. **Update main loop** in `_main.sh` to handle new commands
4. **Add to compile.sh** if creating new files

### Modifying the Build Process

**Adding New Modules:**
1. Add the file path to the `scripts` array in `compile.sh`
2. Ensure proper dependency order (shared modules first)
3. Test compilation: `./compile.sh --no-build`

**Changing Platypus Configuration:**
- Modify `user/app/fcp-git.platypus` for main app settings
- Update `compile.sh` for progress bar and droplet apps

### Updating Server Configuration

**Docker Changes:**
- Modify `server/docker-compose.yml` for container settings
- Update `server/Dockerfile` for base image changes
- Test with `docker-compose build --no-cache`

**Repository Management:**
- Update `server/gitignore-template` for new ignore patterns
- Modify server scripts in `server/scripts/`
- Test with `docker exec` commands

### Debugging Issues

#### 1. Log Analysis
```bash
# View current day's logs
tail -f ~/fcp-git/logs/fcpgit-$(date +%Y-%m-%d).log

# Search for specific errors
grep "ERROR" ~/fcp-git/logs/fcpgit-*.log
```

#### 2. Debug Mode
```bash
# Run with debug output
./user/build/fcp-git-user.sh --debug

# Test specific operations
./user/build/fcp-git-user.sh --debug --silent checkout
```

#### 3. SSH Testing
```bash
# Test server connectivity
ssh -p 2222 git@your-server

# Test repository access
ssh -p 2222 git@your-server ls ~/repositories
```

## Code Style and Standards

### Bash Scripting Standards

**Function Definitions:**
```bash
# Use descriptive function names
function_name() {
    local param1="$1"
    local param2="$2"
    
    log_message "Starting function_name with $param1"
    
    # Function logic here
    
    log_message "Completed function_name"
    return $RC_SUCCESS
}
```

**Error Handling:**
```bash
# Always use handle_error for fatal errors
if [ ! -f "$file" ]; then
    handle_error "Required file not found: $file"
fi

# Use return codes for non-fatal errors
if [ $? -ne 0 ]; then
    log_message "Warning: Operation failed"
    return $RC_ERROR
fi
```

**Variable Naming:**
- Use UPPER_CASE for global variables
- Use lower_case for local variables
- Use descriptive names
- Quote all variable expansions

### Documentation Standards

**Function Documentation:**
```bash
# Function to do something
# Parameters:
#   $1: param1 - Description of first parameter
#   $2: param2 - Description of second parameter
# Returns:
#   0: Success
#   1: Error
#   2: User canceled
function_name() {
    # Implementation
}
```

**File Headers:**
```bash
#!/bin/bash
# File: filename.sh
# Purpose: Brief description of what this file does
# Dependencies: List of other files this depends on
```

## Release Process

### Version Management

1. **Update version** in `user/compile.sh`
2. **Update changelog** or release notes
3. **Test thoroughly** with the new version
4. **Build applications** with `./compile.sh --build`
5. **Create release** on GitHub with compiled apps

### Pre-release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] Version numbers updated
- [ ] Applications build successfully
- [ ] Server scripts tested
- [ ] Logs reviewed for any issues

## Getting Help

### For Contributors

1. **Read the code**: Start with `_main.sh` to understand the flow
2. **Check existing issues**: Look for similar problems
3. **Use debug mode**: Always test with `--debug` flag
4. **Check logs**: Review log files for error details

### For Maintainers

1. **Review pull requests**: Check for proper error handling
2. **Test thoroughly**: Test on different macOS versions
3. **Update documentation**: Keep docs in sync with changes
4. **Monitor issues**: Track common problems and solutions

## Contributing Guidelines

### Pull Request Process

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/new-feature`
3. **Make your changes**: Follow the coding standards above
4. **Test thoroughly**: Use debug mode and test all affected functionality
5. **Update documentation**: Add or update relevant docs
6. **Submit pull request**: Include description of changes and testing done

### Issue Reporting

When reporting issues, please include:
- macOS version
- Finalcut-git version
- Steps to reproduce
- Relevant log entries
- Expected vs actual behavior

### Code Review Checklist

- [ ] Functions are properly documented
- [ ] Error handling is implemented
- [ ] Logging is appropriate
- [ ] UI changes are user-friendly
- [ ] No hardcoded paths or values
- [ ] Code follows bash best practices
- [ ] Tests have been performed

---

This guide should help you understand the codebase and contribute effectively. If you have questions, please open an issue or reach out to the maintainers. 