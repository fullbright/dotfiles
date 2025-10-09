I've reviewed your comprehensive cleanup system and scripts. This is a well-thought-out approach to organizing your Mac and GitHub repositories. Let me help you improve and streamline this process with production-ready code.

## Key Observations & Improvements Needed

### Current Strengths:
- Good separation of concerns across scripts
- Interactive confirmation for destructive actions
- Handles multiple repository states (forked, owned, local-only)
- Sensitive file detection and encryption

### Areas for Improvement:
1. **Error handling** - Need robust error checking and rollback capabilities
2. **Logging** - Add comprehensive logging for audit trail
3. **State management** - Track processed folders to enable resume/retry
4. **Dotfiles versioning** - Need to implement the home directory versioning feature you requested
5. **Code quality** - Consolidate duplicated logic, improve modularity
6. **Performance** - Add parallel processing for batch operations
7. **Safety** - More safeguards before destructive operations

## Implementation Plan

I'll create an improved, production-ready version that includes:

1. **Enhanced core library** (`lib/core.sh`) - Robust utility functions with error handling
2. **State management** (`lib/state.sh`) - Track progress and enable resume
3. **Main orchestrator** (`cleanup_manager.sh`) - Centralized workflow controller
4. **Dotfiles versioning** (`version_dotfiles.sh`) - New feature for home directory versioning
5. **Configuration** (`.cleanup.config`) - Centralized configuration management
6. **Logging system** - Comprehensive audit trail

Let me create these improved scripts for you:Now let me create the core library with robust utility functions:Now let me create the state management library and the remaining essential files. Would you like me to continue with:

1. `lib/state.sh` - State management for resume capability
2. `lib/github.sh` - GitHub operations (fork, create repo, etc.)
3. `version_dotfiles.sh` - The new feature for versioning home directory folders
4. `.cleanup.config` - Configuration file template
5.