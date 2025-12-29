#!/usr/bin/env bash
#
# Setup script for dotfiles security hooks
# This script auto-installs git hooks to prevent committing sensitive data
#
# Run after cloning: ./setup-hooks.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up dotfiles security hooks...${NC}"
echo ""

# Detect available hook managers
setup_hooks() {
    # Option 1: Lefthook (preferred - cross-platform, fast)
    if command -v lefthook &> /dev/null; then
        echo -e "${GREEN}Found lefthook. Installing hooks...${NC}"
        lefthook install
        return 0
    fi

    # Option 2: pre-commit framework
    if command -v pre-commit &> /dev/null; then
        echo -e "${GREEN}Found pre-commit. Installing hooks...${NC}"
        pre-commit install
        return 0
    fi

    # Option 3: Manual git hooks
    echo -e "${YELLOW}No hook manager found. Setting up manual git hooks...${NC}"
    setup_manual_hooks
}

setup_manual_hooks() {
    local hooks_dir=".git/hooks"
    
    # Create pre-commit hook
    cat > "$hooks_dir/pre-commit" << 'HOOK'
#!/usr/bin/env bash
# Pre-commit hook to detect sensitive data

# Patterns to block (from .gitsecrets)
PATTERNS="@essilor\.com|@luxottica\.com|@essilorluxottica\.com|helpdesk\.luxottica\.com|luxotticagroup\.sharepoint\.com|AFANOUS|Sergio.*Essilor|PRIVATE KEY"

# Get staged files (excluding encrypted files)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -v '\.gpg$' || true)

if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

# Check for sensitive patterns
FOUND_SECRETS=0
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        if grep -qE "$PATTERNS" "$file" 2>/dev/null; then
            echo "ERROR: Sensitive pattern found in: $file"
            FOUND_SECRETS=1
        fi
    fi
done

if [ $FOUND_SECRETS -eq 1 ]; then
    echo ""
    echo "Commit blocked! Sensitive data detected."
    echo "Please encrypt files with: gpg --symmetric --cipher-algo AES256 <file>"
    echo "Or add patterns to .gitignore"
    exit 1
fi

exit 0
HOOK
    
    chmod +x "$hooks_dir/pre-commit"
    echo -e "${GREEN}Manual pre-commit hook installed.${NC}"
}

install_tools() {
    echo ""
    echo "Recommended tools for enhanced security:"
    echo ""
    
    if ! command -v lefthook &> /dev/null; then
        echo "  lefthook (cross-platform hook manager):"
        echo "    brew install lefthook        # macOS"
        echo "    apt install lefthook         # Debian/Ubuntu"
        echo "    winget install evilmartians.lefthook  # Windows"
        echo ""
    fi
    
    if ! command -v detect-secrets &> /dev/null; then
        echo "  detect-secrets (Yelp's secret scanner):"
        echo "    pip install detect-secrets"
        echo ""
    fi
    
    if ! command -v gitleaks &> /dev/null; then
        echo "  gitleaks (fast secret scanner):"
        echo "    brew install gitleaks        # macOS"
        echo "    https://github.com/gitleaks/gitleaks/releases  # Other"
        echo ""
    fi
}

generate_baseline() {
    if command -v detect-secrets &> /dev/null; then
        echo -e "${GREEN}Generating secrets baseline...${NC}"
        detect-secrets scan --baseline .secrets.baseline 2>/dev/null || true
        echo "Baseline created at .secrets.baseline"
    fi
}

# Main
setup_hooks
install_tools
generate_baseline

echo ""
echo -e "${GREEN}✓ Security hooks installed!${NC}"
echo ""
echo "The following protections are now active:"
echo "  • Pre-commit hook blocks sensitive patterns"
echo "  • Company emails/URLs detected and blocked"
echo "  • Private keys detection"
echo ""
echo "To test: try committing a file with '@essilor.com' in it"
