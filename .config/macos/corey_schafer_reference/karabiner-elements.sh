#!/bin/bash

################################################################################
# Windows-macOS Keyboard Shortcuts Synchronization Script
# 
# This script configures Karabiner-Elements to make macOS shortcuts match
# Windows shortcuts when using an external Dell keyboard through a dock.
# The mappings are ONLY active when the Dell keyboard is detected.
#
# Target keyboard: Dell QuietKey (vendor_id: 0x413c, product_id: 0x2106)
# Target layout: French AZERTY
#
# The script is idempotent - you can run it multiple times safely.
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration paths
KARABINER_DIR="$HOME/.config/karabiner"
KARABINER_ASSETS_DIR="$KARABINER_DIR/assets/complex_modifications"
KARABINER_CONFIG="$KARABINER_DIR/karabiner.json"
CUSTOM_RULES_FILE="$KARABINER_ASSETS_DIR/windows_to_mac_mappings.json"

# Dell QuietKey keyboard identifiers
DELL_VENDOR_ID="0x413c"
DELL_PRODUCT_ID="0x2106"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS only."
        exit 1
    fi
    print_success "Running on macOS"
}

check_homebrew() {
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ -d "/opt/homebrew/bin" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        print_success "Homebrew is installed"
    fi
}

install_karabiner() {
    if ! brew list karabiner-elements &> /dev/null; then
        print_info "Installing Karabiner-Elements..."
        brew install --cask karabiner-elements
        print_success "Karabiner-Elements installed"
        
        # Wait for Karabiner to initialize
        print_info "Waiting for Karabiner-Elements to initialize..."
        sleep 5
    else
        print_success "Karabiner-Elements is already installed"
    fi
}

create_directories() {
    mkdir -p "$KARABINER_ASSETS_DIR"
    print_success "Created Karabiner directories"
}

disable_macos_conflicting_shortcuts() {
    print_info "Disabling conflicting macOS shortcuts..."
    
    # Disable Mission Control Ctrl+Arrow shortcuts to avoid conflicts
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 79 "<dict><key>enabled</key><false/></dict>"  # Ctrl+Left
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 81 "<dict><key>enabled</key><false/></dict>"  # Ctrl+Right
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 80 "<dict><key>enabled</key><false/></dict>"  # Ctrl+Up
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 82 "<dict><key>enabled</key><false/></dict>"  # Ctrl+Down
    
    # Restart affected services
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    
    print_success "Disabled conflicting macOS shortcuts"
}

create_karabiner_rules() {
    print_info "Creating Karabiner-Elements custom rules..."
    
    cat > "$CUSTOM_RULES_FILE" << 'EOF'
{
  "title": "Windows to macOS Shortcuts (Dell Keyboard Only - FR AZERTY)",
  "rules": [
    {
      "description": "Swap Command and Control keys for Windows-like behavior",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "left_command",
            "modifiers": { "optional": ["any"] }
          },
          "to": [{ "key_code": "left_control" }],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "right_command",
            "modifiers": { "optional": ["any"] }
          },
          "to": [{ "key_code": "right_control" }],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "left_control",
            "modifiers": { "optional": ["any"] }
          },
          "to": [{ "key_code": "left_command" }],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "right_control",
            "modifiers": { "optional": ["any"] }
          },
          "to": [{ "key_code": "right_command" }],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Windows + Tab → Mission Control",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "tab",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [{ "key_code": "mission_control" }],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Ctrl + Win + Left/Right Arrow → Switch Virtual Desktops",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "left_arrow",
            "modifiers": { "mandatory": ["left_command", "left_control"] }
          },
          "to": [
            {
              "key_code": "left_arrow",
              "modifiers": ["left_control"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "right_arrow",
            "modifiers": { "mandatory": ["left_command", "left_control"] }
          },
          "to": [
            {
              "key_code": "right_arrow",
              "modifiers": ["left_control"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Ctrl + Shift + V → Paste without formatting",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "v",
            "modifiers": { "mandatory": ["left_command", "shift"] }
          },
          "to": [
            {
              "key_code": "v",
              "modifiers": ["left_command", "left_shift", "left_option"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Win + E → Open Finder",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "e",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [
            {
              "shell_command": "open ~"
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Win + Left/Right/Up/Down → Window Snapping",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "left_arrow",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [
            {
              "key_code": "left_arrow",
              "modifiers": ["left_control", "left_option"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "right_arrow",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [
            {
              "key_code": "right_arrow",
              "modifiers": ["left_control", "left_option"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "up_arrow",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [
            {
              "key_code": "f",
              "modifiers": ["left_control", "left_command"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Alt + Tab → Application Switcher (Command + Tab)",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "tab",
            "modifiers": { "mandatory": ["left_option"] }
          },
          "to": [
            {
              "key_code": "tab",
              "modifiers": ["left_command"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Ctrl + ` → Cycle windows of same app",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "grave_accent_and_tilde",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [
            {
              "key_code": "grave_accent_and_tilde",
              "modifiers": ["left_command"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "F2 → Rename file in Finder",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "f2"
          },
          "to": [{ "key_code": "return_or_enter" }],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            },
            {
              "type": "frontmost_application_if",
              "bundle_identifiers": ["^com\\.apple\\.finder$"]
            }
          ]
        }
      ]
    },
    {
      "description": "Home/End keys behavior",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "home"
          },
          "to": [
            {
              "key_code": "left_arrow",
              "modifiers": ["left_command"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "end"
          },
          "to": [
            {
              "key_code": "right_arrow",
              "modifiers": ["left_command"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "home",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [
            {
              "key_code": "up_arrow",
              "modifiers": ["left_command"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "end",
            "modifiers": { "mandatory": ["left_command"] }
          },
          "to": [
            {
              "key_code": "down_arrow",
              "modifiers": ["left_command"]
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Page Up/Down behavior",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "page_up"
          },
          "to": [
            {
              "key_code": "page_up"
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "page_down"
          },
          "to": [
            {
              "key_code": "page_down"
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "description": "Delete key → Forward delete",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "delete_forward"
          },
          "to": [{ "key_code": "delete_forward" }],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 1060,
                  "product_id": 8454
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
EOF

    print_success "Created custom Karabiner rules"
}

import_rules_to_karabiner() {
    print_info "Importing rules into Karabiner-Elements configuration..."
    
    # Check if karabiner.json exists
    if [[ ! -f "$KARABINER_CONFIG" ]]; then
        print_warning "karabiner.json not found. Starting Karabiner-Elements to generate it..."
        open -a "Karabiner-Elements"
        sleep 5
    fi
    
    # Use karabiner_cli to reload configuration
    if command -v /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli &> /dev/null; then
        /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --reload-config
        print_success "Karabiner configuration reloaded"
    else
        print_warning "karabiner_cli not found. Please restart Karabiner-Elements manually."
    fi
}

create_autohotkey_script() {
    print_header "Creating AutoHotkey Script (Optional - for Windows PC)"
    
    AHK_SCRIPT_PATH="$HOME/Documents/windows_shortcuts.ahk"
    
    cat > "$AHK_SCRIPT_PATH" << 'EOF'
; Windows Keyboard Shortcuts Enhancement Script
; This script improves some Windows shortcuts to be more consistent
; 
; To use: Download AutoHotkey portable (AutoHotkeyU64.exe) from https://www.autohotkey.com/download/
; Place this script in the same folder as AutoHotkeyU64.exe
; Drag this .ahk file onto AutoHotkeyU64.exe to run it
; To auto-start: Create a shortcut in shell:startup folder

#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%

; Ctrl + Win + Tab to see all apps and virtual desktops (Task View)
^#Tab::Send {LWin down}{Tab}{LWin up}

; Improve Ctrl + ` to cycle between windows of the same app
^`::
WinGetClass, CurrentClass, A
WinGet, WindowList, List, ahk_class %CurrentClass%
If (WindowList > 1)
{
    WinGet, CurrentID, ID, A
    Loop, %WindowList%
    {
        index := WindowList - A_Index + 1
        id := WindowList%index%
        If (id != CurrentID)
        {
            WinActivate, ahk_id %id%
            Break
        }
    }
}
Return

; Screenshot shortcuts (already built-in but for reference)
; Win + Shift + S → Screenshot tool (native Windows 10/11)
; Print Screen → Full screen screenshot

; Optional: Add your own custom shortcuts below
; Example:
; #n::Run notepad.exe  ; Win + N opens Notepad

ExitApp
EOF

    print_success "Created AutoHotkey script at: $AHK_SCRIPT_PATH"
    print_info ""
    print_info "To use this script on your Windows PC:"
    print_info "1. Download AutoHotkey portable from: https://www.autohotkey.com/download/"
    print_info "2. Extract AutoHotkeyU64.exe to a folder (e.g., Documents/AutoHotkey/)"
    print_info "3. Copy windows_shortcuts.ahk to the same folder"
    print_info "4. Drag windows_shortcuts.ahk onto AutoHotkeyU64.exe"
    print_info "5. To auto-start: Create shortcut in shell:startup folder"
    print_info ""
}

verify_installation() {
    print_header "Verifying Installation"
    
    local all_good=true
    
    # Check Homebrew
    if command -v brew &> /dev/null; then
        print_success "Homebrew: OK"
    else
        print_error "Homebrew: NOT FOUND"
        all_good=false
    fi
    
    # Check Karabiner-Elements
    if brew list karabiner-elements &> /dev/null 2>&1; then
        print_success "Karabiner-Elements: INSTALLED"
    else
        print_error "Karabiner-Elements: NOT INSTALLED"
        all_good=false
    fi
    
    # Check custom rules file
    if [[ -f "$CUSTOM_RULES_FILE" ]]; then
        print_success "Custom rules file: EXISTS"
    else
        print_error "Custom rules file: NOT FOUND"
        all_good=false
    fi
    
    # Check AutoHotkey script
    if [[ -f "$HOME/Documents/windows_shortcuts.ahk" ]]; then
        print_success "AutoHotkey script: CREATED"
    else
        print_warning "AutoHotkey script: NOT CREATED"
    fi
    
    echo ""
    if $all_good; then
        print_success "All checks passed!"
    else
        print_error "Some checks failed. Please review the output above."
    fi
}

show_next_steps() {
    print_header "Next Steps"
    
    echo "1. Open Karabiner-Elements:"
    echo "   - Go to System Preferences → Security & Privacy"
    echo "   - Allow Karabiner-Elements to control your computer"
    echo ""
    echo "2. Enable the custom rules:"
    echo "   - Open Karabiner-Elements"
    echo "   - Go to 'Complex Modifications' tab"
    echo "   - Click 'Add rule'"
    echo "   - Find 'Windows to macOS Shortcuts (Dell Keyboard Only - FR AZERTY)'"
    echo "   - Enable all the rules you need"
    echo ""
    echo "3. Connect your Dell dock with keyboard"
    echo "   - The shortcuts will ONLY work when the Dell keyboard is connected"
    echo "   - Your MacBook's built-in keyboard will work normally"
    echo ""
    echo "4. (Optional) For window management:"
    echo "   - Install Rectangle: brew install --cask rectangle"
    echo "   - Configure it for Win+Arrow window snapping"
    echo ""
    echo "5. (Optional) For your Windows PC:"
    echo "   - Follow the instructions above to set up AutoHotkey"
    echo "   - The script is located at: ~/Documents/windows_shortcuts.ahk"
    echo ""
    
    print_info "You can run this script again anytime to update the configuration."
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    print_header "Windows-macOS Keyboard Shortcuts Synchronization"
    
    echo "This script will:"
    echo "  • Install Karabiner-Elements (if not already installed)"
    echo "  • Configure Windows-like shortcuts for your Dell keyboard"
    echo "  • Create mappings that work ONLY when Dell keyboard is connected"
    echo "  • Create an AutoHotkey script for your Windows PC (optional)"
    echo ""
    
    read -p "Continue? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled."
        exit 0
    fi
    
    print_header "Step 1: System Checks"
    check_macos
    check_homebrew
    
    print_header "Step 2: Install Karabiner-Elements"
    install_karabiner
    
    print_header "Step 3: Configure Directories"
    create_directories
    
    print_header "Step 4: Disable Conflicting macOS Shortcuts"
    disable_macos_conflicting_shortcuts
    
    print_header "Step 5: Create Custom Karabiner Rules"
    create_karabiner_rules
    
    print_header "Step 6: Import Rules"
    import_rules_to_karabiner
    
    print_header "Step 7: Create AutoHotkey Script (Optional)"
    create_autohotkey_script
    
    verify_installation
    show_next_steps
    
    print_header "Installation Complete!"
    print_success "Your keyboard shortcuts are now configured."
    print_info "Please follow the 'Next Steps' above to complete the setup."
}

# Run main function
main "$@"