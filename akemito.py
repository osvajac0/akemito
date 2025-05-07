#!/usr/bin/env python3
"""
Akemito - Cursor Position Saver

This application tracks the mouse cursor position and saves it after the cursor
remains still for 1 seconds, but only locks in the position once the cursor moves again.
Press Alt+Z to restore the cursor to the saved position.

Requirements:
    - python-xlib
    - pynput

Install with:
    pip install python-xlib pynput
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
    print("Please install it with: pip install python-xlib")
    sys.exit(1)

try:
    from pynput import mouse, keyboard
except ImportError:
    print("Error: Missing 'pynput' package.")
    print("Please install it with: pip install pynput")
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
