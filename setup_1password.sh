#!/bin/bash
# 1Password Setup and Validation Script for Vagrant

set -euo pipefail

# 1Password item IDs (update these to match your items)
CREDS_ID="cu36afxxckm4mgnnkiltkne44u"
SSH_KEY_ID="kp7dx7dk3qq7h565ivc2fjslle"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_1password_cli() {
    print_status "Checking 1Password CLI installation..."
    
    if ! command -v op &> /dev/null; then
        print_error "1Password CLI is not installed"
        echo ""
        echo "Please install 1Password CLI:"
        echo "  macOS: brew install --cask 1password-cli"
        echo "  Linux: https://developer.1password.com/docs/cli/get-started/#install"
        echo "  Windows: https://developer.1password.com/docs/cli/get-started/#install"
        return 1
    fi
    
    print_status "1Password CLI is installed: $(op --version)"
    return 0
}

check_1password_auth() {
    print_status "Checking 1Password CLI authentication..."
    
    if ! op whoami &> /dev/null; then
        print_error "Not authenticated with 1Password CLI"
        echo ""
        echo "Please sign in to 1Password:"
        echo "  op signin"
        echo ""
        echo "Or if you're using 1Password app integration:"
        echo "  Make sure 1Password app is running and CLI integration is enabled"
        return 1
    fi
    
    print_status "Authenticated as: $(op whoami)"
    return 0
}

validate_credentials_item() {
    print_status "Validating credentials item..."
    
    local username=$(op item get "$CREDS_ID" --fields username 2>/dev/null || echo "")
    local password_check=$(op item get "$CREDS_ID" --fields password 2>/dev/null || echo "")
    
    if [ -z "$username" ]; then
        print_error "Could not retrieve username from item $CREDS_ID"
        return 1
    fi
    
    if [ -z "$password_check" ]; then
        print_error "Could not retrieve password field from item $CREDS_ID"
        return 1
    fi
    
    print_status "Credentials item valid - Username: $username"
    return 0
}

validate_ssh_key_item() {
    print_status "Validating SSH key item..."
    
    local public_key=$(op item get "$SSH_KEY_ID" --fields "public key" 2>/dev/null || echo "")
    local key_type=$(op item get "$SSH_KEY_ID" --fields "key type" 2>/dev/null || echo "")
    
    if [ -z "$public_key" ]; then
        print_error "Could not retrieve public key from item $SSH_KEY_ID"
        return 1
    fi
    
    if [ -z "$key_type" ]; then
        print_warning "Could not retrieve key type from item $SSH_KEY_ID"
    else
        print_status "SSH key type: $key_type"
    fi
    
    # Validate the public key format
    if [[ $public_key =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
        print_status "SSH public key format is valid"
        print_status "Key fingerprint: $(echo "$public_key" | ssh-keygen -lf - 2>/dev/null || echo 'Unable to compute fingerprint')"
    else
        print_error "SSH public key format appears invalid"
        return 1
    fi
    
    return 0
}

show_item_info() {
    print_status "1Password Item Information:"
    echo ""
    echo "Credentials Item:"
    op item get "$CREDS_ID" --format json | jq -r '.title, .id, .vault.name' | sed 's/^/  /'
    echo ""
    echo "SSH Key Item:"
    op item get "$SSH_KEY_ID" --format json | jq -r '.title, .id, .vault.name' | sed 's/^/  /'
}

test_vagrant_integration() {
    print_status "Testing Vagrant integration..."
    
    # Create a temporary test script to simulate what Vagrant does
    local test_script=$(cat << 'EOF'
#!/bin/bash
CREDS_ID="cu36afxxckm4mgnnkiltkne44u"
SSH_KEY_ID="kp7dx7dk3qq7h565ivc2fjslle"

ANSIBLE_USERNAME=$(op item get "$CREDS_ID" --fields username 2>/dev/null)
ANSIBLE_PASSWORD=$(op item get "$CREDS_ID" --reveal --fields password 2>/dev/null)
SSH_PUBLIC_KEY=$(op item get "$SSH_KEY_ID" --fields 'public key' 2>/dev/null)

if [ -n "$ANSIBLE_USERNAME" ] && [ -n "$ANSIBLE_PASSWORD" ] && [ -n "$SSH_PUBLIC_KEY" ]; then
    echo "SUCCESS: All items retrieved successfully"
    echo "Username: $ANSIBLE_USERNAME"
    echo "Password: [REDACTED]"
    echo "SSH Key: ${SSH_PUBLIC_KEY:0:50}..."
    exit 0
else
    echo "ERROR: Failed to retrieve one or more items"
    exit 1
fi
EOF
)
    
    if bash -c "$test_script"; then
        print_status "Vagrant integration test PASSED"
        return 0
    else
        print_error "Vagrant integration test FAILED"
        return 1
    fi
}

main() {
    echo "=== 1Password Setup Validation for Vagrant ==="
    echo ""
    
    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Some features will be limited."
        print_warning "Install jq for better JSON parsing: brew install jq (macOS) or apt install jq (Ubuntu)"
    fi
    
    local errors=0
    
    check_1password_cli || ((errors++))
    check_1password_auth || ((errors++))
    validate_credentials_item || ((errors++))
    validate_ssh_key_item || ((errors++))
    
    if [ $errors -eq 0 ]; then
        echo ""
        print_status "All checks passed! Your 1Password setup is ready for Vagrant."
        echo ""
        
        if command -v jq &> /dev/null; then
            show_item_info
            echo ""
        fi
        
        test_vagrant_integration
        
        echo ""
        print_status "You can now run: vagrant up"
    else
        echo ""
        print_error "Setup validation failed with $errors error(s)"
        print_error "Please fix the issues above before running Vagrant"
        exit 1
    fi
}

# Show help if requested
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "1Password Setup Validation Script"
    echo ""
    echo "This script validates your 1Password CLI setup for use with Vagrant."
    echo "It checks:"
    echo "  - 1Password CLI installation"
    echo "  - Authentication status"
    echo "  - Access to credential items"
    echo "  - SSH key item validity"
    echo ""
    echo "Usage: $0"
    echo "       $0 --help"
    exit 0
fi

main "$@"
