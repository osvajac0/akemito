#!/bin/bash
#
# Akemito Installation Script
# This script installs the Akemito cursor saver to your system
#

set -e  # Exit on error

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"  # More appropriate than /bin for user-installed software
SCRIPT_NAME="akemito"
TEMP_DIR=$(mktemp -d)
DESKTOP_FILE_DIR="/usr/share/applications"
ICON_DIR="/usr/share/icons/hicolor"
ICON_NAME="akemito"

echo -e "${BLUE}=== Akemito Cursor Saver Installation ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root${NC}"
  echo -e "Please run: ${YELLOW}sudo $0${NC}"
  exit 1
fi

# Create the Python script
echo -e "${BLUE}Creating Akemito script...${NC}"
cat > "${TEMP_DIR}/${SCRIPT_NAME}" << 'EOL'
#!/usr/bin/env python3
"""
Akemito - Cursor Position Saver

This application tracks the mouse cursor position and saves it after the cursor
remains still for 1 seconds, but only locks in the position once the cursor moves again.
Press Alt+Z to restore the cursor to the saved position.
"""

import os
import sys
import time
import threading
import signal

# Check for required dependencies
try:
    from Xlib import display
except ImportError:
    print("Error: Missing 'python-xlib' package.")
    print("Please run: sudo pip3 install python-xlib")
    sys.exit(1)

try:
    from pynput import mouse, keyboard
except ImportError:
    print("Error: Missing 'pynput' package.")
    print("Please run: sudo pip3 install pynput")
    sys.exit(1)

class CursorPositionSaver:
    def __init__(self):
        # Initialize X display
        try:
            self.display = display.Display()
        except Exception as e:
            print(f"Error connecting to X display: {e}")
            print("Make sure you're running this in a graphical environment.")
            sys.exit(1)
        
        # Saved cursor position
        self.saved_position = None
        
        # Position tracking variables
        self.last_position = None
        self.still_since = None
        self.still_position = None
        self.position_locked = False
        
        # Settings
        self.still_threshold = 1.0  # seconds
        self.restore_hotkey = keyboard.Key.alt_l, keyboard.KeyCode.from_char('z')
        self.current_keys = set()
        
        # Create controllers
        self.mouse_controller = mouse.Controller()
        
        # Create listeners
        self.mouse_listener = mouse.Listener(on_move=self.on_move)
        self.keyboard_listener = keyboard.Listener(
            on_press=self.on_press,
            on_release=self.on_release
        )
        
        # Flag to indicate running status
        self.running = True
        
        # Set up signal handling for clean exit
        signal.signal(signal.SIGINT, self.handle_exit)
        signal.signal(signal.SIGTERM, self.handle_exit)
    
    def handle_exit(self, signum, frame):
        """Handle exit signal gracefully"""
        print("\nExiting Akemito cursor saver...")
        self.running = False
        self.mouse_listener.stop()
        self.keyboard_listener.stop()
        sys.exit(0)
    
    def on_move(self, x, y):
        """Handle mouse movement event"""
        current_position = (x, y)
        current_time = time.time()
        
        # If this is the first movement, initialize positions
        if self.last_position is None:
            self.last_position = current_position
            return
        
        # Check if the mouse has moved
        if current_position != self.last_position:
            # If we've been still and now we're moving, lock in the still position
            if self.still_since is not None and not self.position_locked:
                elapsed = current_time - self.still_since
                if elapsed >= self.still_threshold:
                    self.saved_position = self.still_position
                    print(f"Position saved: {self.saved_position}")
                    self.position_locked = True
            
            # Reset stillness timer
            self.still_since = None
            self.position_locked = False
        else:
            # If the cursor hasn't moved and we haven't started timing stillness
            if self.still_since is None:
                self.still_since = current_time
                self.still_position = current_position
        
        # Update last known position
        self.last_position = current_position
    
    def on_press(self, key):
        """Handle key press event"""
        self.current_keys.add(key)
        
        # Check if hotkey combination is pressed
        if all(k in self.current_keys for k in self.restore_hotkey):
            self.restore_cursor_position()
    
    def on_release(self, key):
        """Handle key release event"""
        try:
            self.current_keys.remove(key)
        except KeyError:
            pass
    
    def restore_cursor_position(self):
        """Restore the cursor to saved position"""
        if self.saved_position:
            print(f"Restoring cursor to: {self.saved_position}")
            self.mouse_controller.position = self.saved_position
        else:
            print("No position saved yet")
    
    def start(self):
        """Start the application"""
        print("Starting Akemito cursor saver...")
        print("Press Alt+Z to restore the cursor position")
        print("Press Ctrl+C to exit")
        
        # Start listeners
        self.mouse_listener.start()
        self.keyboard_listener.start()
        
        try:
            # Keep the main thread alive
            while self.running:
                time.sleep(0.1)
        except KeyboardInterrupt:
            self.handle_exit(None, None)

def check_dependencies():
    """Check if we're running in a supported environment"""
    # Check if we're on a system with X11
    if os.name != 'posix':
        print("Warning: This script is designed for Linux/Unix systems with X11.")
        print("It may not work correctly on your system.")

if __name__ == "__main__":
    check_dependencies()
    saver = CursorPositionSaver()
    saver.start()
EOL

# Create desktop file for dmenu integration
echo -e "${BLUE}Creating desktop entry...${NC}"
mkdir -p "${DESKTOP_FILE_DIR}"
cat > "${DESKTOP_FILE_DIR}/akemito.desktop" << EOL
[Desktop Entry]
Name=Akemito
Comment=Cursor Position Saver
Exec=${INSTALL_DIR}/${SCRIPT_NAME}
Icon=${ICON_NAME}
Terminal=false
Type=Application
Categories=Utility;
Keywords=cursor;mouse;position;save;
EOL

# Create icon
echo -e "${BLUE}Creating application icon...${NC}"

# Create icon directories if they don't exist
mkdir -p "${ICON_DIR}/scalable/apps"
mkdir -p "${ICON_DIR}/256x256/apps"
mkdir -p "${ICON_DIR}/128x128/apps"
mkdir -p "${ICON_DIR}/64x64/apps"
mkdir -p "${ICON_DIR}/48x48/apps"
mkdir -p "${ICON_DIR}/32x32/apps"

# Create SVG icon
cat > "${ICON_DIR}/scalable/apps/${ICON_NAME}.svg" << 'EOL'
<?xml version="1.0" encoding="utf-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 28 28">
  <!-- Main cursor arrow -->
  <polygon fill="#FFFFFF" points="8.2,20.9 8.2,4.9 19.8,16.5 13,16.5 12.6,16.6"/>
  
  <!-- Cursor tail design -->
  <polygon fill="#FFFFFF" points="17.3,21.6 13.7,23.1 9,12 12.7,10.5"/>
  
  <!-- Cursor stem -->
  <rect x="12.5" y="13.6" transform="matrix(0.9221 -0.3871 0.3871 0.9221 -5.7605 6.5909)" width="2" height="8"/>
  
  <!-- Shadow/outline effect -->
  <polygon points="9.2,7.3 9.2,18.5 12.2,15.6 12.6,15.5 17.4,15.5"/>
</svg>
EOL

# Generate PNG icons using SVG if rsvg-convert is available
if command -v rsvg-convert &> /dev/null; then
    echo -e "${BLUE}Generating PNG icons from SVG...${NC}"
    rsvg-convert -w 256 -h 256 "${ICON_DIR}/scalable/apps/${ICON_NAME}.svg" > "${ICON_DIR}/256x256/apps/${ICON_NAME}.png"
    rsvg-convert -w 128 -h 128 "${ICON_DIR}/scalable/apps/${ICON_NAME}.svg" > "${ICON_DIR}/128x128/apps/${ICON_NAME}.png"
    rsvg-convert -w 64 -h 64 "${ICON_DIR}/scalable/apps/${ICON_NAME}.svg" > "${ICON_DIR}/64x64/apps/${ICON_NAME}.png"
    rsvg-convert -w 48 -h 48 "${ICON_DIR}/scalable/apps/${ICON_NAME}.svg" > "${ICON_DIR}/48x48/apps/${ICON_NAME}.png"
    rsvg-convert -w 32 -h 32 "${ICON_DIR}/scalable/apps/${ICON_NAME}.svg" > "${ICON_DIR}/32x32/apps/${ICON_NAME}.png"
else
    echo -e "${YELLOW}rsvg-convert not found. Only SVG icon will be installed.${NC}"
    echo -e "${YELLOW}Install librsvg2-bin package for PNG icons.${NC}"
fi

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"

# Detect distribution and install packages accordingly
if command -v pacman &> /dev/null; then
    # Arch Linux
    echo -e "${YELLOW}Detected Arch Linux...${NC}"
    
    # Install python-xlib from official repos
    echo -e "${YELLOW}Installing python-xlib from official repositories...${NC}"
    pacman -S --needed --noconfirm python-pip python-xlib
    
    # Check for AUR helpers for python-pynput
    if command -v yay &> /dev/null; then
        echo -e "${YELLOW}Using yay to install python-pynput from AUR...${NC}"
        # Using su to run yay as the original user, not as root
        if [ "$SUDO_USER" ]; then
            su -c "yay -S --needed --noconfirm python-pynput" - $SUDO_USER || {
                echo -e "${RED}Failed to install python-pynput with yay.${NC}"
                echo -e "${RED}Please install it manually: yay -S python-pynput${NC}"
            }
        else
            echo -e "${RED}Cannot determine the original user. Please install python-pynput manually:${NC}"
            echo -e "${RED}yay -S python-pynput${NC}"
        fi
    elif command -v paru &> /dev/null; then
        echo -e "${YELLOW}Using paru to install python-pynput from AUR...${NC}"
        if [ "$SUDO_USER" ]; then
            su -c "paru -S --needed --noconfirm python-pynput" - $SUDO_USER || {
                echo -e "${RED}Failed to install python-pynput with paru.${NC}"
                echo -e "${RED}Please install it manually: paru -S python-pynput${NC}"
            }
        else
            echo -e "${RED}Cannot determine the original user. Please install python-pynput manually:${NC}"
            echo -e "${RED}paru -S python-pynput${NC}"
        fi
    else
        echo -e "${RED}No AUR helper found (yay/paru).${NC}"
        echo -e "${RED}Please install python-pynput manually from AUR:${NC}"
        echo -e "${RED}yay -S python-pynput${NC}"
        echo -e "${RED}or another AUR helper of your choice.${NC}"
    fi
elif command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    echo -e "${YELLOW}Detected Debian/Ubuntu, installing dependencies...${NC}"
    apt-get update
    apt-get install -y python3-pip
    pip3 install python-xlib pynput
elif command -v dnf &> /dev/null; then
    # Fedora/RHEL
    echo -e "${YELLOW}Detected Fedora/RHEL, installing dependencies...${NC}"
    dnf install -y python3-pip
    pip3 install python-xlib pynput
else
    echo -e "${YELLOW}Unknown distribution, attempting to install dependencies...${NC}"
    # Check for pip3
    if ! command -v pip3 &> /dev/null; then
        echo -e "${RED}Unable to find pip3. Please install python3-pip manually.${NC}"
        exit 1
    fi
    # Install Python dependencies with --break-system-packages as a fallback
    echo -e "${YELLOW}Installing Python packages...${NC}"
    echo -e "${RED}Warning: Using --break-system-packages flag as a fallback.${NC}"
    echo -e "${RED}This is not recommended but may work in some environments.${NC}"
    pip3 install --break-system-packages python-xlib pynput || {
        echo -e "${RED}Installation failed. Please install dependencies manually:${NC}"
        echo -e "python-xlib and pynput packages are required."
        exit 1
    }
fi

# Install the script
echo -e "${BLUE}Installing Akemito to ${INSTALL_DIR}...${NC}"
install -m 755 "${TEMP_DIR}/${SCRIPT_NAME}" "${INSTALL_DIR}/${SCRIPT_NAME}"

# Clean up
rm -rf "${TEMP_DIR}"

# Update icon cache if gtk-update-icon-cache is available
if command -v gtk-update-icon-cache &> /dev/null; then
    echo -e "${BLUE}Updating icon cache...${NC}"
    gtk-update-icon-cache -f -t "${ICON_DIR}"
fi

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database
fi

echo -e "${GREEN}Installation complete!${NC}"
echo -e "You can now run Akemito by:"
echo -e "1. Typing '${YELLOW}akemito${NC}' in a terminal"
echo -e "2. Finding '${YELLOW}Akemito${NC}' in your application menu"
echo -e "3. Using '${YELLOW}dmenu_run${NC}' and typing '${YELLOW}akemito${NC}'"
echo -e "\n${BLUE}Usage:${NC}"
echo -e "- Once running, wait 2 seconds without moving the cursor to save a position"
echo -e "- Press ${YELLOW}Alt+Z${NC} to restore the cursor to the saved position"
echo -e "- Press ${YELLOW}Ctrl+C${NC} to exit the program"

# Check if installation should be verified
echo -e "\n${BLUE}Verifying installation...${NC}"
# Check if the script exists in the installation directory
if [ ! -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
    echo -e "${RED}Error: ${INSTALL_DIR}/${SCRIPT_NAME} not found.${NC}"
    echo -e "${RED}Installation may have failed.${NC}"
    exit 1
fi

# Check if dependencies are available
python3 -c "import Xlib, pynput" 2>/dev/null || {
    echo -e "${RED}Warning: Python dependencies not properly installed.${NC}"
    
    if command -v pacman &> /dev/null; then
        echo -e "${YELLOW}For Arch Linux, make sure you have installed:${NC}"
        echo -e "  - python-xlib (sudo pacman -S python-xlib)"
        echo -e "  - python-pynput (yay -S python-pynput) from AUR"
    else
        echo -e "${YELLOW}Please install the required Python packages manually:${NC}"
        echo -e "  - python-xlib"
        echo -e "  - pynput"
    fi
    
    echo -e "\n${YELLOW}Alternatively, you can create a virtual environment:${NC}"
    echo -e "  python -m venv ~/.venv/akemito"
    echo -e "  source ~/.venv/akemito/bin/activate"
    echo -e "  pip install python-xlib pynput"
    
    echo -e "\n${YELLOW}Then modify ${INSTALL_DIR}/${SCRIPT_NAME} to use this environment:${NC}"
    echo -e "  Change the first line to: #!/home/$(whoami)/.venv/akemito/bin/python3"
    
    exit 1
}

echo -e "${GREEN}All dependencies verified successfully!${NC}"
