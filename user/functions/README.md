# Functions Directory Organization

This directory contains all the bash functions for the FinalCut-Git application, organized into two main functional areas:

## 1. Git Repository Management (`git/`)
Core functionality for managing Final Cut projects stored in git repositories.

### Core GIT Operations
- `checkin.sh` - Check in changes to a repository
- `checkout.sh` - Check out a repository for editing
- `checkpoint.sh` - Create a quick save checkpoint
- `checkpoint_all.sh` - Create checkpoints for all repositories
- `enable_auto_checkpoint.sh` - Enable automatic checkpointing

### Git Operations (`git/operations/`)
- `checkConnectivity.sh` - Check git server connectivity
- `commitAndPush.sh` - Commit and push changes
- `conflict.sh` - Handle merge conflicts
- `checkedout.sh` - Check repository checkout status
- `lock.sh` - Repository locking mechanism
- `repo_operations.sh` - Core repository operations
- `repo_utils.sh` - Repository utility functions

### Filesystem Operations (`git/filesystem/`)
- `checkOpenFiles.sh` - Check for open Final Cut files
- `checkRecentAccess.sh` - Check recent file access
- `move.sh` - Move files between locations

## 2. Footage Offloading (`offload/`)
Functionality for offloading footage from SD cards and other media sources.

### Core Offload
- `offload.sh` - Main offload functionality
- `offload_ui.sh` - Offload user interface
- `offload_utils.sh` - Offload utility functions
- `verify.sh` - Verify offloaded files

## 3. Shared Components (`shared/`)
Common functionality used by both git management and offloading features.

### Core
- `_main.sh` - Main application entry point
- `vars.sh` - Global variables
- `logs.sh` - Logging functions
- `dialogs.sh` - Dialog and UI functions
- `config.sh` - Configuration management

### Utilities
- `setup.sh` - Application setup
- `select_repo.sh` - Repository selection
- `fcp.sh` - Final Cut Pro integration

## Migration Notes

The original flat structure has been reorganized to better separate concerns:
- Git-related files moved to `git/` directory
- Offload-related files moved to `offload/` directory  
- Shared/common files moved to `shared/` directory

This organization makes it easier to:
- Understand which features belong to which main function
- Maintain and debug specific functionality
- Add new features to the appropriate area
- Potentially split into separate applications in the future 