#!/usr/bin/env python3
"""
ClipBard - A RADICAL clipboard utility
Python Edition

by Arash Abolhasani (@eraxe)
"""

import os
import sys
import re
import json
import hashlib
import shutil
import subprocess
import tempfile
import configparser
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Union, Any
import signal
from datetime import datetime
import mimetypes
import time # For clipboard auto-clear

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import (
    Button, Static, Input, Label, Header, Footer,
    DataTable, DirectoryTree, ListView, ListItem, Select,
    Markdown, Log, Switch
)
# Using Log instead of TextLog for compatibility with Textual 3.2.0
from textual.reactive import reactive
from textual.binding import Binding
from textual import events, work
from textual.worker import Worker, get_current_worker
from textual.screen import Screen
from textual.coordinate import Coordinate

# For handling keypress without Enter
try:
    import readchar
except ImportError:
    # Fallback implementation if readchar is not available
    import termios
    import tty
    import sys


    def getch():
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch
else:
    getch = readchar.readchar

# Constants
VERSION = "1.0.0"
CONFIG_DIR = os.path.expanduser("~/.config/clipbard")
HISTORY_FILE = os.path.join(CONFIG_DIR, "history")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.ini")
SCRIPT_DIR = os.path.expanduser("~/.local/bin")
SCRIPT_PATH = os.path.join(SCRIPT_DIR, "clipbard")
GITHUB_REPO = "https://github.com/eraxe/clipbard"
TMP_DIR = "/tmp/clipbard-tmp"

# Default configuration
DEFAULT_HISTORY_SIZE = 50
DEFAULT_DISPLAY_COUNT = 5
DEFAULT_THEME = "synthwave"
DEFAULT_CLIPBOARD_BUFFER = 0
DEFAULT_MAX_FILE_SIZE = 10  # In MB
DEFAULT_PREFERRED_HISTORY = "auto"
DEFAULT_VERBOSE_LOGGING = False

# List of recognizable file extensions (simplified from bash version)
FILE_EXTENSIONS = [
    # Programming
    "py", "js", "html", "css", "php", "java", "cpp", "c", "h", "hpp", "cs",
    "go", "rb", "pl", "swift", "kt", "rs", "ts", "sh", "bash", "zsh", "sql",
    # Data formats
    "json", "xml", "yaml", "yml", "toml", "ini", "csv", "tsv", "md", "markdown",
    # Documents
    "txt", "doc", "docx", "pdf", "xls", "xlsx",
    # Config
    "conf", "config", "cfg", "gitignore", "env",
]

# Create necessary directories
os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(TMP_DIR, exist_ok=True)
if not os.path.exists(HISTORY_FILE):
    with open(HISTORY_FILE, 'w') as f: # Ensure file is closed
        f.close()


# Theme colors - No changes needed
class Theme:
    def __init__(self, name: str = DEFAULT_THEME):
        # Default colors (synthwave theme)
        self.neon_pink = "#ff71ce"
        self.neon_blue = "#01cdfe"
        self.neon_green = "#05ffa1"
        self.neon_yellow = "#fffb96"
        self.neon_purple = "#b967ff"
        self.neon_orange = "#ff9e64"
        self.neon_cyan = "#01cdfe"
        self.neon_white = "#ffffff"

        # Apply theme
        self.apply_theme(name)

    def apply_theme(self, name: str):
        if name == "matrix":
            self.neon_pink = "#00ff00"
            self.neon_blue = "#00cc00"
            self.neon_green = "#00ff00"
            self.neon_yellow = "#00dd00"
            self.neon_purple = "#00cc00"
            self.neon_orange = "#00ff00"
            self.neon_cyan = "#00ffaa"
            self.neon_white = "#ffffff"
        elif name == "cyberpunk":
            self.neon_pink = "#ff00ff"
            self.neon_blue = "#00ffff"
            self.neon_green = "#ffff00"
            self.neon_yellow = "#ffa500"
            self.neon_purple = "#ff00ff"
            self.neon_orange = "#ff6600"
            self.neon_cyan = "#00ffff"
            self.neon_white = "#ffffff"
        elif name == "midnight":
            self.neon_pink = "#9370db"
            self.neon_blue = "#6a5acd"
            # ... (rest of midnight theme)
        # Fallback to default synthwave if theme name not recognized, or set explicitly
        elif name == "synthwave":
            self.neon_pink = "#ff71ce"
            self.neon_blue = "#01cdfe"
            self.neon_green = "#05ffa1"
            self.neon_yellow = "#fffb96"
            self.neon_purple = "#b967ff"
            self.neon_orange = "#ff9e64"
            self.neon_cyan = "#01cdfe"
            self.neon_white = "#ffffff"
        # Default "synthwave" theme colors are already set


# Configuration manager - No changes needed
class Config:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self._create_default_config()
        self.load_config()
        self.theme = Theme(self.get("general", "theme", DEFAULT_THEME)) # Ensure fallback for theme

    def _create_default_config(self):
        """Create default configuration if it doesn't exist"""
        if not os.path.exists(CONFIG_FILE):
            self.config["general"] = {
                "history_size": str(DEFAULT_HISTORY_SIZE),
                "display_count": str(DEFAULT_DISPLAY_COUNT),
                "theme": DEFAULT_THEME,
                "verbose_logging": str(DEFAULT_VERBOSE_LOGGING).lower()
            }
            self.config["clipboard"] = {
                "auto_clear": "false",
                "default_buffer": str(DEFAULT_CLIPBOARD_BUFFER),
                "max_file_size": str(DEFAULT_MAX_FILE_SIZE)
            }
            self.config["security"] = {
                "notification": "true",
                "compression": "false",
                "encryption": "false"
            }
            self.config["history"] = {
                "shell_history_scan": "true",
                "prefer_local_history": "true",
                "preferred_history": DEFAULT_PREFERRED_HISTORY
            }

            # Make sure directory exists
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)

            with open(CONFIG_FILE, 'w') as configfile:
                self.config.write(configfile)

    def load_config(self):
        """Load configuration from file"""
        if os.path.exists(CONFIG_FILE):
            try:
                self.config.read(CONFIG_FILE)
                # Ensure all sections and keys have defaults if missing after read
                self._ensure_defaults_after_load()
            except configparser.Error as e: # Catch more specific errors
                print(f"Error reading config file {CONFIG_FILE}: {e}. Recreating with defaults.")
                self._backup_and_recreate_config()
        else: # If somehow still doesn't exist (e.g. deleted after _create_default_config)
            self._create_default_config()
            self.config.read(CONFIG_FILE)


    def _ensure_defaults_after_load(self):
        """Ensure default sections and keys exist after loading config."""
        default_sections = {
            "general": {
                "history_size": str(DEFAULT_HISTORY_SIZE), "display_count": str(DEFAULT_DISPLAY_COUNT),
                "theme": DEFAULT_THEME, "verbose_logging": str(DEFAULT_VERBOSE_LOGGING).lower()
            },
            "clipboard": {
                "auto_clear": "false", "default_buffer": str(DEFAULT_CLIPBOARD_BUFFER),
                "max_file_size": str(DEFAULT_MAX_FILE_SIZE)
            },
            "security": {
                "notification": "true", "compression": "false", "encryption": "false"
            },
            "history": {
                "shell_history_scan": "true", "prefer_local_history": "true",
                "preferred_history": DEFAULT_PREFERRED_HISTORY
            }
        }
        changed = False
        for section, keys in default_sections.items():
            if not self.config.has_section(section):
                self.config.add_section(section)
                changed = True
            for key, default_value in keys.items():
                if not self.config.has_option(section, key):
                    self.config.set(section, key, default_value)
                    changed = True
        if changed:
            self.save_config()


    def _backup_and_recreate_config(self):
        """Backup the existing config and create a new one"""
        try:
            # Create backup
            backup_file = f"{CONFIG_FILE}.backup"
            if os.path.exists(CONFIG_FILE):
                shutil.copy(CONFIG_FILE, backup_file)
                print(f"Created backup of old config: {backup_file}")

            # Read old config values if possible
            old_values = {}
            try:
                with open(CONFIG_FILE, 'r') as f:
                    for line in f:
                        if '=' in line:
                            key, value = line.strip().split('=', 1)
                            old_values[key] = value
            except:
                pass

            # Create new config with sections
            self._create_default_config()

            # Try to update with old values
            if old_values:
                for section in self.config.sections():
                    for key in self.config[section]:
                        if key in old_values:
                            self.config[section][key] = old_values[key]

                # Save updated config
                with open(CONFIG_FILE, 'w') as configfile:
                    self.config.write(configfile)
        except Exception as e:
            print(f"Error recreating config: {e}")
            self._create_default_config()

    def save_config(self):
        """Save configuration to file"""
        with open(CONFIG_FILE, 'w') as configfile:
            self.config.write(configfile)

    def get(self, section: str, key: str, fallback=None) -> str:
        """Get configuration value"""
        try:
            return self.config[section][key]
        except (KeyError, ValueError):
            if fallback is not None:
                return fallback

            # Set defaults based on section and key
            if section == "general":
                if key == "history_size": return str(DEFAULT_HISTORY_SIZE)
                if key == "display_count": return str(DEFAULT_DISPLAY_COUNT)
                if key == "theme": return DEFAULT_THEME
                if key == "verbose_logging": return str(DEFAULT_VERBOSE_LOGGING).lower()
            elif section == "clipboard":
                if key == "auto_clear": return "false"
                if key == "default_buffer": return str(DEFAULT_CLIPBOARD_BUFFER)
                if key == "max_file_size": return str(DEFAULT_MAX_FILE_SIZE)
            elif section == "security":
                if key == "notification": return "true"
                if key == "compression": return "false"
                if key == "encryption": return "false"
            elif section == "history":
                if key == "shell_history_scan": return "true"
                if key == "prefer_local_history": return "true"
                if key == "preferred_history": return DEFAULT_PREFERRED_HISTORY
            return ""

    def set(self, section: str, key: str, value: str):
        """Set configuration value"""
        if section not in self.config:
            self.config[section] = {}
        self.config[section][key] = value
        self.save_config()

        # If theme is updated, apply it
        if section == "general" and key == "theme":
            self.theme.apply_theme(value)

    def get_bool(self, section: str, key: str, fallback=None) -> bool:
        """Get boolean configuration value"""
        try:
            value = self.get(section, key, fallback)
            return value.lower() == "true"
        except:
            return False

    def get_int(self, section: str, key: str, fallback=None) -> int:
        """Get integer configuration value"""
        try:
            value = self.get(section, key, fallback)
            return int(value)
        except:
            if fallback is not None and isinstance(fallback, int):
                return fallback
            return 0


# History manager - No changes needed
class History:
    def __init__(self, config: Config):
        self.config = config
        self.history_file = HISTORY_FILE

    def add(self, file_path: str):
        """Add file to history"""
        if not os.path.exists(file_path):
            return

        history_size = self.config.get_int("general", "history_size")

        # Read existing history
        history = []
        if os.path.exists(self.history_file):
            with open(self.history_file, 'r') as f:
                history = [line.strip() for line in f.readlines()]

        # Add new entry to the beginning
        if file_path in history:
            history.remove(file_path)
        history.insert(0, file_path)

        # Limit history size
        history = history[:history_size]

        # Write back to file
        with open(self.history_file, 'w') as f:
            f.write('\n'.join(history))

    def get(self, count: int = None) -> List[str]:
        """Get history entries"""
        if count is None:
            count = self.config.get_int("general", "display_count")

        history = []
        if os.path.exists(self.history_file):
            with open(self.history_file, 'r') as f:
                history = [line.strip() for line in f.readlines()]

        return history[:count]

    def search(self, term: str, count: int = None) -> List[str]:
        """Search in history"""
        if count is None:
            count = self.config.get_int("general", "display_count")

        history = self.get(None)  # Get all history
        matches = [entry for entry in history if term.lower() in entry.lower()]
        return matches[:count]

    def clear(self):
        """Clear history"""
        open(self.history_file, 'w').close()

    def extract_files_from_shell_history(self, count: int = None) -> List[str]:
        """Extract files from shell history"""
        if count is None:
            count = self.config.get_int("general", "display_count")

        # Determine current shell and preferred history
        preferred_history = self.config.get("history", "preferred_history")
        current_shell = preferred_history

        if preferred_history == "auto":
            # Try to detect current shell
            if "ZSH_VERSION" in os.environ:
                current_shell = "zsh"
            elif "BASH_VERSION" in os.environ:
                current_shell = "bash"
            else:
                current_shell = "bash"

        history_sources = []

        # Get history file paths based on shell
        if current_shell == "zsh":
            # ZSH history
            histfile = os.environ.get("HISTFILE", "")
            if histfile and os.path.exists(histfile):
                history_sources.append(histfile)

            # Check for per-directory-history plugin
            per_dir_hist_base = os.path.expanduser("~/.zsh_history_dirs")
            if os.path.isdir(per_dir_hist_base):
                # Generate directory hash for current directory
                current_dir_hash = hashlib.md5(os.getcwd().encode()).hexdigest()
                per_dir_hist_file = os.path.join(per_dir_hist_base, current_dir_hash)

                if os.path.exists(per_dir_hist_file):
                    if self.config.get_bool("history", "prefer_local_history"):
                        history_sources.insert(0, per_dir_hist_file)
                    else:
                        history_sources.append(per_dir_hist_file)

            # Global ZSH history as fallback
            global_zsh_history = os.path.expanduser("~/.zsh_history")
            if os.path.exists(global_zsh_history) and global_zsh_history not in history_sources:
                history_sources.append(global_zsh_history)

        elif current_shell == "bash":
            # Bash history
            histfile = os.environ.get("HISTFILE", "")
            if histfile and os.path.exists(histfile):
                history_sources.append(histfile)

            bash_history = os.path.expanduser("~/.bash_history")
            if os.path.exists(bash_history) and bash_history not in history_sources:
                history_sources.append(bash_history)

        # Collect file paths from history sources
        potential_files = set()

        for source in history_sources:
            try:
                with open(source, 'r', errors='ignore') as f:
                    content = f.read()

                # Extract paths that look like files
                # Basic pattern for file paths
                path_pattern = r'(?:^|\s)(/[a-zA-Z0-9._/-]+)'
                paths = re.findall(path_pattern, content)
                potential_files.update(paths)

                # Extract filenames with extensions
                file_pattern = r'(?:^|\s)([a-zA-Z0-9._/-]+\.[a-zA-Z0-9]+)'
                files = re.findall(file_pattern, content)

                # Convert relative paths to absolute
                for file in files:
                    if not file.startswith('/'):
                        file = os.path.join(os.getcwd(), file)
                    potential_files.add(file)

                # Extract files used with common commands
                cmd_pattern = r'(?:cat|nano|vim|vi|emacs|less|more|head|tail|grep|awk|sed)\s+([^\s]+)'
                cmd_files = re.findall(cmd_pattern, content)

                for file in cmd_files:
                    if file.startswith('-'):
                        continue  # Skip command options

                    if not file.startswith('/'):
                        file = os.path.join(os.getcwd(), file)
                    potential_files.add(file)
            except:
                pass  # Silently ignore errors reading history files

        # Fall back to history command if no files found or no history sources
        if not potential_files and not history_sources:
            try:
                history_output = subprocess.check_output("history", shell=True, text=True)

                # Extract paths that look like files
                path_pattern = r'(?:^|\s)(/[a-zA-Z0-9._/-]+)'
                paths = re.findall(path_pattern, history_output)
                potential_files.update(paths)

                # Extract filenames with extensions
                file_pattern = r'(?:^|\s)([a-zA-Z0-9._/-]+\.[a-zA-Z0-9]+)'
                files = re.findall(file_pattern, history_output)
                for file in files:
                    if not file.startswith('/'):
                        file = os.path.join(os.getcwd(), file)
                    potential_files.add(file)

                # Extract files used with common commands
                cmd_pattern = r'(?:cat|nano|vim|vi|emacs|less|more|head|tail|grep|awk|sed)\s+([^\s]+)'
                cmd_files = re.findall(cmd_pattern, history_output)
                for file in cmd_files:
                    if file.startswith('-'):
                        continue  # Skip command options

                    if not file.startswith('/'):
                        file = os.path.join(os.getcwd(), file)
                    potential_files.add(file)
            except:
                pass  # Silently ignore errors with history command

        # Filter for existing files with recognized extensions
        valid_files = []
        for file in potential_files:
            if os.path.isfile(file):
                ext = os.path.splitext(file)[1].lower().lstrip('.')

                # Check if file has recognized extension or is text file
                is_recognized = ext in FILE_EXTENSIONS

                if not is_recognized:
                    # Try to determine if it's a text file
                    try:
                        mime = mimetypes.guess_type(file)[0]
                        if mime and ('text' in mime or 'json' in mime or 'xml' in mime):
                            is_recognized = True
                    except:
                        pass

                if is_recognized and file not in valid_files:
                    valid_files.append(file)
                    if len(valid_files) >= count:
                        break

        # If no files found, check current directory
        if not valid_files:
            for file in os.listdir(os.getcwd()):
                file_path = os.path.join(os.getcwd(), file)
                if os.path.isfile(file_path):
                    ext = os.path.splitext(file_path)[1].lower().lstrip('.')
                    if ext in FILE_EXTENSIONS:
                        valid_files.append(file_path)
                        if len(valid_files) >= count:
                            break

        return valid_files


# Clipboard manager - No changes needed
class Clipboard:
    def __init__(self, config: Config, history: History):
        self.config = config
        self.history = history

    def copy_to_clipboard(self, file_path: str, buffer: int = None) -> bool:
        """Copy file content to clipboard"""
        if buffer is None:
            buffer = self.config.get_int("clipboard", "default_buffer")

        if not os.path.exists(file_path):
            return False

        # Check file size against max_file_size
        file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
        max_size_mb = self.config.get_int("clipboard", "max_file_size")

        if file_size_mb > max_size_mb:
            return False  # File too large

        # Handle compression if enabled
        if self.config.get_bool("security", "compression") and file_size_mb > 0.1:  # >100KB
            compressed_file = self._compress_content(file_path)
            target_file = compressed_file
        else:
            target_file = file_path

        try:
            # Read file content
            with open(target_file, 'rb') as f:
                content = f.read()

            # Handle encryption if enabled
            if self.config.get_bool("security", "encryption"):
                content = self._encrypt_content(content)

            # Copy to clipboard based on platform
            if sys.platform == 'darwin':  # macOS
                subprocess.run('pbcopy', input=content, check=True)
            elif sys.platform == 'win32':  # Windows
                try:
                    import win32clipboard
                    win32clipboard.OpenClipboard()
                    win32clipboard.EmptyClipboard()
                    win32clipboard.SetClipboardData(win32clipboard.CF_UNICODETEXT,
                                                    content.decode('utf-8', errors='replace'))
                    win32clipboard.CloseClipboard()
                except ImportError:
                    return False
            else:  # Linux/Unix
                try:
                    # Try wayland
                    process = subprocess.Popen(['wl-copy'], stdin=subprocess.PIPE)
                    process.communicate(input=content)
                except FileNotFoundError:
                    try:
                        # Try X11
                        process = subprocess.Popen(['xclip', '-selection', 'clipboard'], stdin=subprocess.PIPE)
                        process.communicate(input=content)
                    except FileNotFoundError:
                        return False  # No clipboard utility found

            # Handle auto-clear if enabled
            if self.config.get_bool("clipboard", "auto_clear"):
                # Schedule auto-clear after 60 seconds
                def clear_clipboard():
                    time.sleep(60)
                    self.clear_clipboard(buffer)

                import threading
                import time
                threading.Thread(target=clear_clipboard, daemon=True).start()

            # Update history
            self.history.add(file_path)

            # Show notification if enabled
            if self.config.get_bool("security", "notification"):
                self.show_notification("CLIPBARD", f"Copied: {os.path.basename(file_path)}")

            # Clean up temporary compressed file if created
            if target_file != file_path and os.path.exists(target_file):
                os.unlink(target_file)

            return True
        except Exception as e:
            print(f"Error copying to clipboard: {e}")
            return False

    def copy_text_to_clipboard(self, text: str, buffer: int = None) -> bool:
        """Copy text directly to clipboard"""
        if buffer is None:
            buffer = self.config.get_int("clipboard", "default_buffer")

        # Handle encryption if enabled
        if self.config.get_bool("security", "encryption"):
            encrypted_text = self._encrypt_content(text.encode('utf-8'))
            text = encrypted_text.decode('utf-8', errors='replace')

        try:
            # Copy to clipboard based on platform
            if sys.platform == 'darwin':  # macOS
                subprocess.run('pbcopy', input=text.encode('utf-8'), check=True)
            elif sys.platform == 'win32':  # Windows
                try:
                    import win32clipboard
                    win32clipboard.OpenClipboard()
                    win32clipboard.EmptyClipboard()
                    win32clipboard.SetClipboardData(win32clipboard.CF_UNICODETEXT, text)
                    win32clipboard.CloseClipboard()
                except ImportError:
                    return False
            else:  # Linux/Unix
                try:
                    # Try wayland
                    process = subprocess.Popen(['wl-copy'], stdin=subprocess.PIPE)
                    process.communicate(input=text.encode('utf-8'))
                except FileNotFoundError:
                    try:
                        # Try X11
                        process = subprocess.Popen(['xclip', '-selection', 'clipboard'], stdin=subprocess.PIPE)
                        process.communicate(input=text.encode('utf-8'))
                    except FileNotFoundError:
                        return False  # No clipboard utility found

            # Handle auto-clear if enabled
            if self.config.get_bool("clipboard", "auto_clear"):
                # Schedule auto-clear after 60 seconds
                def clear_clipboard():
                    time.sleep(60)
                    self.clear_clipboard(buffer)

                import threading
                import time
                threading.Thread(target=clear_clipboard, daemon=True).start()

            # Show notification if enabled
            if self.config.get_bool("security", "notification"):
                self.show_notification("CLIPBARD", "Text copied to clipboard")

            return True
        except Exception as e:
            print(f"Error copying text to clipboard: {e}")
            return False

    def get_clipboard_content(self, buffer: int = None) -> str:
        """Get clipboard content"""
        if buffer is None:
            buffer = self.config.get_int("clipboard", "default_buffer")

        try:
            content = ""
            if sys.platform == 'darwin':  # macOS
                content = subprocess.check_output('pbpaste', universal_newlines=True)
            elif sys.platform == 'win32':  # Windows
                try:
                    import win32clipboard
                    win32clipboard.OpenClipboard()
                    if win32clipboard.IsClipboardFormatAvailable(win32clipboard.CF_UNICODETEXT):
                        content = win32clipboard.GetClipboardData(win32clipboard.CF_UNICODETEXT)
                    win32clipboard.CloseClipboard()
                except ImportError:
                    return ""
            else:  # Linux/Unix
                try:
                    # Try wayland
                    content = subprocess.check_output(['wl-paste'], universal_newlines=True)
                except FileNotFoundError:
                    try:
                        # Try X11
                        content = subprocess.check_output(['xclip', '-selection', 'clipboard', '-o'],
                                                          universal_newlines=True)
                    except FileNotFoundError:
                        return ""  # No clipboard utility found

            # Handle decryption if needed
            if self.config.get_bool("security", "encryption") and content.startswith("ENCRYPTED:"):
                decrypted_content = self._decrypt_content(content[10:].encode('utf-8'))
                content = decrypted_content.decode('utf-8', errors='replace')

            return content
        except Exception as e:
            print(f"Error getting clipboard content: {e}")
            return ""

    def clear_clipboard(self, buffer: int = None) -> bool:
        """Clear clipboard"""
        if buffer is None:
            buffer = self.config.get_int("clipboard", "default_buffer")

        try:
            if sys.platform == 'darwin':  # macOS
                subprocess.run('pbcopy', input=b'', check=True)
            elif sys.platform == 'win32':  # Windows
                try:
                    import win32clipboard
                    win32clipboard.OpenClipboard()
                    win32clipboard.EmptyClipboard()
                    win32clipboard.CloseClipboard()
                except ImportError:
                    return False
            else:  # Linux/Unix
                try:
                    # Try wayland
                    process = subprocess.Popen(['wl-copy', '--clear'])
                    process.wait()
                except FileNotFoundError:
                    try:
                        # Try X11
                        process = subprocess.Popen(['xclip', '-selection', 'clipboard'], stdin=subprocess.PIPE)
                        process.communicate(input=b'')
                    except FileNotFoundError:
                        return False  # No clipboard utility found

            return True
        except Exception as e:
            print(f"Error clearing clipboard: {e}")
            return False

    def show_notification(self, title: str, message: str) -> bool:
        """Show notification"""
        if not self.config.get_bool("security", "notification"):
            return False

        try:
            if sys.platform == 'darwin':  # macOS
                subprocess.run([
                    'osascript', '-e',
                    f'display notification "{message}" with title "{title}"'
                ])
            elif sys.platform == 'win32':  # Windows
                try:
                    from win10toast import ToastNotifier
                    toaster = ToastNotifier()
                    toaster.show_toast(title, message, duration=3)
                except ImportError:
                    return False
            else:  # Linux/Unix
                try:
                    subprocess.run(['notify-send', '-a', 'CLIPBARD', title, message])
                except FileNotFoundError:
                    return False

            return True
        except Exception as e:
            print(f"Error showing notification: {e}")
            return False

    def _compress_content(self, file_path: str) -> str:
        """Compress file content"""
        import gzip
        output_file = os.path.join(TMP_DIR, f"{os.path.basename(file_path)}.gz")

        try:
            with open(file_path, 'rb') as f_in:
                with gzip.open(output_file, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
            return output_file
        except Exception as e:
            print(f"Error compressing file: {e}")
            return file_path

    def _encrypt_content(self, content: bytes) -> bytes:
        """Encrypt content"""
        try:
            # Simple encryption (not secure, for demo purposes)
            # In a real implementation, use proper encryption with a user password
            import base64
            return b"ENCRYPTED:" + base64.b64encode(content)
        except Exception as e:
            print(f"Error encrypting content: {e}")
            return content

    def _decrypt_content(self, content: bytes) -> bytes:
        """Decrypt content"""
        try:
            # Simple decryption (not secure, for demo purposes)
            import base64
            return base64.b64decode(content)
        except Exception as e:
            print(f"Error decrypting content: {e}")
            return content


# File utility functions - No changes needed
class FileUtils:
    @staticmethod
    def preview_file(file_path: str) -> dict:
        """Preview file and return metadata"""
        if not os.path.exists(file_path):
            return None

        result = {
            "filename": os.path.basename(file_path),
            "path": file_path,
            "size": os.path.getsize(file_path),
            "size_human": FileUtils.human_readable_size(os.path.getsize(file_path)),
            "modified": datetime.fromtimestamp(os.path.getmtime(file_path)).strftime("%Y-%m-%d %H:%M:%S"),
            "type": "unknown",
            "preview": "",
            "lines": 0
        }

        # Determine file type and generate preview
        try:
            # Check mime type
            mime = mimetypes.guess_type(file_path)[0]
            if mime:
                result["type"] = mime

            # If text file, count lines and show preview
            if mime and 'text' in mime:
                with open(file_path, 'r', errors='ignore') as f:
                    lines = f.readlines()
                    result["lines"] = len(lines)
                    result["preview"] = ''.join(lines[:10])
            elif mime and ('image' in mime or 'video' in mime or 'audio' in mime):
                result["type"] = mime
            else:
                # Try to read as binary
                with open(file_path, 'rb') as f:
                    binary_data = f.read(100)
                    result["preview"] = ' '.join(f"{b:02x}" for b in binary_data)
                    result["type"] = "binary"
        except Exception as e:
            result["preview"] = f"Error previewing file: {e}"

        return result

    @staticmethod
    def human_readable_size(size: int) -> str:
        """Convert size in bytes to human-readable format"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size < 1024:
                return f"{size:.2f} {unit}"
            size /= 1024
        return f"{size:.2f} PB"

    @staticmethod
    def copy_line_range(file_path: str, start: int, end: int = None) -> str:
        """Copy specific line range from file"""
        if not os.path.exists(file_path):
            return ""

        try:
            with open(file_path, 'r', errors='ignore') as f:
                lines = f.readlines()

            if end is None:
                end = start

            if start < 1 or end > len(lines) or start > end:
                return ""

            return ''.join(lines[start - 1:end])
        except Exception as e:
            print(f"Error copying line range: {e}")
            return ""

    @staticmethod
    def convert_format(file_path: str, target_format: str) -> str:
        """Convert file to a different format"""
        if not os.path.exists(file_path):
            return ""

        current_format = os.path.splitext(file_path)[1].lower().lstrip('.')
        output_file = os.path.join(TMP_DIR, f"{os.path.splitext(os.path.basename(file_path))[0]}.{target_format}")

        try:
            if f"{current_format}:{target_format}" == "md:html":
                # Convert Markdown to HTML
                import markdown
                with open(file_path, 'r', errors='ignore') as f:
                    md_content = f.read()
                html_content = markdown.markdown(md_content)
                with open(output_file, 'w') as f:
                    f.write(html_content)
                return output_file
            elif f"{current_format}:{target_format}" == "html:md":
                # Convert HTML to Markdown
                import html2text
                with open(file_path, 'r', errors='ignore') as f:
                    html_content = f.read()
                md_content = html2text.html2text(html_content)
                with open(output_file, 'w') as f:
                    f.write(md_content)
                return output_file
            elif f"{current_format}:{target_format}" == "json:csv":
                # Convert JSON to CSV
                import json
                import csv
                with open(file_path, 'r', errors='ignore') as f:
                    json_data = json.load(f)

                if isinstance(json_data, list) and len(json_data) > 0:
                    with open(output_file, 'w', newline='') as f:
                        if isinstance(json_data[0], dict):
                            fieldnames = json_data[0].keys()
                            writer = csv.DictWriter(f, fieldnames=fieldnames)
                            writer.writeheader()
                            writer.writerows(json_data)
                        else:
                            writer = csv.writer(f)
                            for item in json_data:
                                writer.writerow([item])
                return output_file
            elif f"{current_format}:{target_format}" == "csv:json":
                # Convert CSV to JSON
                import json
                import csv
                json_data = []
                with open(file_path, 'r', errors='ignore', newline='') as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        json_data.append(dict(row))

                with open(output_file, 'w') as f:
                    json.dump(json_data, f, indent=2)
                return output_file
            else:
                # Basic text conversion
                shutil.copy(file_path, output_file)
                return output_file
        except Exception as e:
            print(f"Error converting file: {e}")
            return ""


# Helper function to generate safe IDs - No changes needed
def generate_safe_id(text: str) -> str:
    """Generate a safe ID from any string"""
    # Use hashlib to create a hash of the input text
    # Add 'id_' prefix to ensure it never starts with a number
    # This ensures we have a valid ID that complies with Textual's requirements
    return "id_" + hashlib.md5(text.encode()).hexdigest()


# UI Classes

# Main welcome screen - No changes needed
class WelcomeScreen(Screen):
    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("escape", "app.pop_screen", "Back"),
        Binding("h", "app.push_screen('help')", "Help"),
        Binding("c", "app.push_screen('config')", "Config"),
        Binding("b", "app.push_screen('browse')", "Browse"),
        Binding("s", "app.push_screen('search')", "Search"),
        Binding("v", "app.push_screen('view')", "View Clipboard"),
    ]

    def __init__(self, config: Config, history: History, clipboard: Clipboard):
        super().__init__()
        self.config = config
        self.history = history
        self.clipboard = clipboard
        # Dictionary to store file paths by their safe IDs
        self.file_id_map = {}

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(self.get_logo(), id="logo")

        with Vertical(id="main-menu"):
            yield Button("Copy From History", variant="primary", id="history-btn")
            yield Button("Browse Files", variant="primary", id="browse-btn")
            yield Button("Search", variant="primary", id="search-btn")
            yield Button("View Clipboard", variant="primary", id="view-btn")
            yield Button("Settings", variant="primary", id="config-btn")
            yield Button("Help", variant="primary", id="help-btn")
            yield Button("Quit", variant="error", id="quit-btn")

        with Container(id="recent-history"):
            yield Static("Recent Files:", classes="heading")
            yield ListView(id="recent-files-list")

        yield Footer()

    def on_mount(self) -> None:
        """Update recent files on mount"""
        self.update_recent_files()

    def update_recent_files(self) -> None:
        """Update the list of recent files"""
        recent_files_list = self.query_one("#recent-files-list", ListView)
        recent_files_list.clear()
        self.file_id_map.clear()

        recent_files = self.history.get()
        for file_path in recent_files:
            # Generate a safe ID and store it in the map
            safe_id = generate_safe_id(file_path)
            self.file_id_map[safe_id] = file_path

            # Add list item with safe ID
            recent_files_list.append(ListItem(Label(os.path.basename(file_path)), id=safe_id))

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle list view selection"""
        # Get the file path from the map using the safe ID
        safe_id = event.item.id
        file_path = self.file_id_map.get(safe_id)

        if file_path:
            self.clipboard.copy_to_clipboard(file_path)
            self.app.push_screen(
                MessageScreen(f"Copied to clipboard: {os.path.basename(file_path)}")
            )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses"""
        button_id = event.button.id

        if button_id == "history-btn":
            self.action_shell_history()
        elif button_id == "browse-btn":
            self.app.push_screen("browse")
        elif button_id == "search-btn":
            self.app.push_screen("search")
        elif button_id == "view-btn":
            self.app.push_screen("view")
        elif button_id == "config-btn":
            self.app.push_screen("config")
        elif button_id == "help-btn":
            self.app.push_screen("help")
        elif button_id == "quit-btn":
            self.app.exit()

    def get_logo(self) -> str:
        """Get the ASCII art logo"""
        return f"""
╔═╗╦  ╦╔═╗╔╗ ╔═╗╦═╗╔╦╗
║  ║  ║╠═╝╠╩╗╠═╣╠╦╝ ║║
╚═╝╩═╝╩╩  ╚═╝╩ ╩╩╚══╩╝

A  R A D I C A L  clipboard utility
Python Edition v{VERSION}
        """

    @work
    async def action_shell_history(self) -> None:
        """Extract files from shell history"""
        # Show loading screen
        self.app.push_screen(LoadingScreen("Scanning shell history..."))

        # Extract files in background
        worker = get_current_worker()
        files = self.history.extract_files_from_shell_history()

        # Remove loading screen
        self.app.pop_screen()

        if not files:
            self.app.push_screen(
                MessageScreen("No files found in shell history.")
            )
            return

        # Show file selection screen
        self.app.push_screen(
            FileSelectionScreen("Shell History Files", files, self.clipboard)
        )


# File selection screen - No changes needed
class FileSelectionScreen(Screen):
    def __init__(self, title: str, files: List[str], clipboard: Clipboard):
        super().__init__()
        self.title = title
        self.files = files
        self.clipboard = clipboard
        # Dictionary to store file paths by their safe IDs
        self.file_id_map = {}

    def compose(self) -> ComposeResult:
        yield Header(self.title)

        with Vertical(id="file-selection"):
            for file_path in self.files:
                # Generate a safe ID and store the mapping
                safe_id = generate_safe_id(file_path)
                self.file_id_map[safe_id] = file_path

                # Create button with safe ID
                yield Button(os.path.basename(file_path), id=safe_id, classes="file-btn")

        yield Button("Cancel", variant="error", id="cancel-btn")
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "cancel-btn":
            self.app.pop_screen()
        else:
            # Get the file path from the map using the safe ID
            file_path = self.file_id_map.get(button_id)

            if file_path and os.path.exists(file_path):
                self.clipboard.copy_to_clipboard(file_path)
                self.app.pop_screen()
                self.app.push_screen(
                    MessageScreen(f"Copied to clipboard: {os.path.basename(file_path)}")
                )


# Loading screen - No changes needed
class LoadingScreen(Screen):
    def __init__(self, message: str):
        super().__init__()
        self.message = message

    def compose(self) -> ComposeResult:
        yield Static(self.message, id="loading-message")


# Message screen - No changes needed
class MessageScreen(Screen):
    def __init__(self, message: str):
        super().__init__()
        self.message = message

    def compose(self) -> ComposeResult:
        yield Static(self.message, id="message")
        yield Button("OK", variant="primary", id="ok-btn")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        self.app.pop_screen()


# Browse files screen - No changes needed
class BrowseScreen(Screen):
    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self, config: Config, history: History, clipboard: Clipboard):
        super().__init__()
        self.config = config
        self.history = history
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header("Browse Files")
        yield DirectoryTree(os.path.expanduser("~"), id="directory-tree")
        yield Footer()

    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        """Handle file selection"""
        file_path = event.path
        file_preview = FileUtils.preview_file(file_path)

        if file_preview:
            self.app.push_screen(
                FilePreviewScreen(file_preview, self.clipboard)
            )


# File preview screen - No changes needed
class FilePreviewScreen(Screen):
    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
        Binding("c", "copy", "Copy"),
        Binding("l", "copy_lines", "Copy Lines"),
    ]

    def __init__(self, file_data: dict, clipboard: Clipboard):
        super().__init__()
        self.file_data = file_data
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header(f"Preview: {self.file_data['filename']}")

        with Vertical(id="file-info"):
            yield Static(f"Path: {self.file_data['path']}")
            yield Static(f"Size: {self.file_data['size_human']}")
            yield Static(f"Type: {self.file_data['type']}")
            yield Static(f"Modified: {self.file_data['modified']}")
            if 'lines' in self.file_data and self.file_data['lines'] > 0:
                yield Static(f"Lines: {self.file_data['lines']}")

        with Vertical(id="file-preview"):
            yield Static("Preview:", classes="heading")
            yield Log(id="preview-content", highlight=True)

        with Horizontal(id="action-buttons"):
            yield Button("Copy to Clipboard", variant="primary", id="copy-btn")
            if 'lines' in self.file_data and self.file_data['lines'] > 0:
                yield Button("Copy Line Range", variant="primary", id="copy-lines-btn")
            yield Button("Back", variant="error", id="back-btn")

        yield Footer()

    def on_mount(self) -> None:
        """Update preview content on mount"""
        preview_log = self.query_one("#preview-content", Log)

        if 'preview' in self.file_data and self.file_data['preview']:
            # Add preview content
            if isinstance(self.file_data['preview'], str):
                for line in self.file_data['preview'].splitlines()[:10]:
                    preview_log.write(line)
            else:
                preview_log.write(str(self.file_data['preview']))
        else:
            preview_log.write("Preview not available for this file type.")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "copy-btn":
            self.action_copy()
        elif button_id == "copy-lines-btn":
            self.action_copy_lines()
        elif button_id == "back-btn":
            self.app.pop_screen()

    def action_copy(self) -> None:
        """Copy file to clipboard"""
        result = self.clipboard.copy_to_clipboard(self.file_data['path'])

        if result:
            self.app.pop_screen()
            self.app.push_screen(
                MessageScreen(f"Copied to clipboard: {self.file_data['filename']}")
            )
        else:
            self.app.push_screen(
                MessageScreen("Failed to copy to clipboard.")
            )

    def action_copy_lines(self) -> None:
        """Show dialog to copy line range"""
        self.app.push_screen(
            LineRangeScreen(self.file_data, self.clipboard)
        )


# Line range selection screen - No changes needed
class LineRangeScreen(Screen):
    def __init__(self, file_data: dict, clipboard: Clipboard):
        super().__init__()
        self.file_data = file_data
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header(f"Select Line Range: {self.file_data['filename']}")

        with Vertical(id="line-range-form"):
            yield Static("Enter line range (e.g., 5-10 or just 5 for single line):")
            yield Input(placeholder="5-10", id="line-range-input")

            with Horizontal(id="action-buttons"):
                yield Button("Copy", variant="primary", id="copy-btn")
                yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "copy-btn":
            line_range = self.query_one("#line-range-input", Input).value
            self.copy_line_range(line_range)
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    def copy_line_range(self, line_range: str) -> None:
        """Copy selected line range"""
        try:
            if '-' in line_range:
                start, end = map(int, line_range.split('-'))
            else:
                start = end = int(line_range)

            content = FileUtils.copy_line_range(self.file_data['path'], start, end)

            if content:
                self.clipboard.copy_text_to_clipboard(content)
                self.app.pop_screen()
                self.app.pop_screen()  # Also pop the preview screen
                self.app.push_screen(
                    MessageScreen(f"Copied lines {start}-{end} to clipboard.")
                )
            else:
                self.app.push_screen(
                    MessageScreen("Invalid line range or failed to copy.")
                )
        except ValueError:
            self.app.push_screen(
                MessageScreen("Invalid line range format. Use '5-10' or '5'.")
            )


# Search screen - No changes needed
class SearchScreen(Screen):
    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self, config: Config, history: History, clipboard: Clipboard):
        super().__init__()
        self.config = config
        self.history = history
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header("Search")

        with Vertical(id="search-options"):
            yield Button("Search App History", variant="primary", id="history-search-btn")
            yield Button("Search File Contents", variant="primary", id="content-search-btn")
            yield Button("Back", variant="error", id="back-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "history-search-btn":
            self.app.push_screen(
                HistorySearchScreen(self.history, self.clipboard)
            )
        elif button_id == "content-search-btn":
            self.app.push_screen(
                ContentSearchScreen(self.clipboard)
            )
        elif button_id == "back-btn":
            self.app.pop_screen()


# History search screen - No changes needed
class HistorySearchScreen(Screen):
    def __init__(self, history: History, clipboard: Clipboard):
        super().__init__()
        self.history = history
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header("Search App History")

        with Vertical(id="search-form"):
            yield Static("Enter search term:")
            yield Input(placeholder="Search term", id="search-input")
            yield Button("Search", variant="primary", id="search-btn")
            yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "search-btn":
            search_term = self.query_one("#search-input", Input).value
            if search_term:
                self.perform_search(search_term)
            else:
                self.app.push_screen(
                    MessageScreen("Please enter a search term.")
                )
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    def perform_search(self, search_term: str) -> None:
        """Search in app history"""
        results = self.history.search(search_term)

        if results:
            self.app.push_screen(
                FileSelectionScreen("Search Results", results, self.clipboard)
            )
        else:
            self.app.push_screen(
                MessageScreen("No matching files found.")
            )


# Content search screen - No changes needed
class ContentSearchScreen(Screen):
    def __init__(self, clipboard: Clipboard):
        super().__init__()
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header("Search File Contents")

        with Vertical(id="search-form"):
            yield Static("Enter search term:")
            yield Input(placeholder="Search term", id="search-input")

            yield Static("Search directory:")
            yield Input(placeholder="Directory path", id="dir-input", value=os.path.expanduser("~"))

            with Horizontal(id="action-buttons"):
                yield Button("Search", variant="primary", id="search-btn")
                yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "search-btn":
            search_term = self.query_one("#search-input", Input).value
            search_dir = self.query_one("#dir-input", Input).value

            if not search_term:
                self.app.push_screen(
                    MessageScreen("Please enter a search term.")
                )
                return

            if not os.path.isdir(search_dir):
                self.app.push_screen(
                    MessageScreen("Invalid directory path.")
                )
                return

            self.action_content_search(search_term, search_dir)
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    @work
    async def action_content_search(self, search_term: str, search_dir: str) -> None:
        """Search in file contents"""
        # Show loading screen
        self.app.push_screen(LoadingScreen("Searching in files..."))

        # Perform search in background
        worker = get_current_worker()
        results = []

        for root, dirs, files in os.walk(search_dir):
            for file in files:
                if worker.is_cancelled:
                    break

                file_path = os.path.join(root, file)
                # Skip large files and non-text files
                try:
                    if os.path.getsize(file_path) > 1024 * 1024:  # Skip files > 1MB
                        continue

                    mime = mimetypes.guess_type(file_path)[0]
                    if mime and not ('text' in mime or 'json' in mime or 'xml' in mime):
                        continue

                    with open(file_path, 'r', errors='ignore') as f:
                        content = f.read()
                        if search_term.lower() in content.lower():
                            results.append(file_path)
                            if len(results) >= 20:  # Limit to 20 results
                                break
                except:
                    continue

        # Remove loading screen
        self.app.pop_screen()

        if results:
            self.app.push_screen(
                FileSelectionScreen("Content Search Results", results, self.clipboard)
            )
        else:
            self.app.push_screen(
                MessageScreen("No matching content found.")
            )


# View clipboard screen - No changes needed
class ViewScreen(Screen):
    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self, config: Config, clipboard: Clipboard):
        super().__init__()
        self.config = config
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header("View Clipboard")

        with Vertical(id="clipboard-view"):
            yield Static(f"Buffer: {self.config.get_int('clipboard', 'default_buffer')}")
            yield Static("Content:", classes="heading")
            yield Log(id="clipboard-content", highlight=True)

        with Horizontal(id="action-buttons"):
            yield Button("Save to File", variant="primary", id="save-btn")
            yield Button("Clear Clipboard", variant="primary", id="clear-btn")
            yield Button("Back", variant="error", id="back-btn")

        yield Footer()

    def on_mount(self) -> None:
        """Update clipboard content on mount"""
        content_log = self.query_one("#clipboard-content", Log)
        content = self.clipboard.get_clipboard_content()

        if content:
            lines = content.splitlines()
            for line in lines:
                content_log.write(line)
        else:
            content_log.write("Clipboard is empty.")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "save-btn":
            self.app.push_screen(
                SaveClipboardScreen(self.clipboard)
            )
        elif button_id == "clear-btn":
            self.clipboard.clear_clipboard()
            self.app.pop_screen()
            self.app.push_screen(
                MessageScreen("Clipboard cleared.")
            )
        elif button_id == "back-btn":
            self.app.pop_screen()


# Save clipboard to file screen - No changes needed
class SaveClipboardScreen(Screen):
    def __init__(self, clipboard: Clipboard):
        super().__init__()
        self.clipboard = clipboard

    def compose(self) -> ComposeResult:
        yield Header("Save Clipboard to File")

        with Vertical(id="save-form"):
            yield Static("Enter filename:")
            yield Input(placeholder="output.txt", id="filename-input")

            with Horizontal(id="action-buttons"):
                yield Button("Save", variant="primary", id="save-btn")
                yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "save-btn":
            filename = self.query_one("#filename-input", Input).value
            if filename:
                self.save_to_file(filename)
            else:
                self.app.push_screen(
                    MessageScreen("Please enter a filename.")
                )
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    def save_to_file(self, filename: str) -> None:
        """Save clipboard content to file"""
        content = self.clipboard.get_clipboard_content()

        if not content:
            self.app.push_screen(
                MessageScreen("Clipboard is empty.")
            )
            return

        # Check if file exists
        if os.path.exists(filename):
            self.app.push_screen(
                FileExistsScreen(filename, content)
            )
            return

        try:
            with open(filename, 'w') as f:
                f.write(content)

            self.app.pop_screen()
            self.app.pop_screen()  # Also pop the view screen
            self.app.push_screen(
                MessageScreen(f"Saved to: {filename}")
            )
        except Exception as e:
            self.app.push_screen(
                MessageScreen(f"Error saving file: {e}")
            )


# File exists confirmation screen - No changes needed
class FileExistsScreen(Screen):
    def __init__(self, filename: str, content: str):
        super().__init__()
        self.filename = filename
        self.content = content

    def compose(self) -> ComposeResult:
        yield Header("File Exists")

        with Vertical(id="confirm-form"):
            yield Static(f"File '{self.filename}' already exists.")

            with Horizontal(id="action-buttons"):
                yield Button("Overwrite", variant="primary", id="overwrite-btn")
                yield Button("Append", variant="primary", id="append-btn")
                yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "overwrite-btn":
            try:
                with open(self.filename, 'w') as f:
                    f.write(self.content)

                self.app.pop_screen()
                self.app.pop_screen()
                self.app.pop_screen()  # Pop all the way back to view screen
                self.app.push_screen(
                    MessageScreen(f"Overwritten: {self.filename}")
                )
            except Exception as e:
                self.app.push_screen(
                    MessageScreen(f"Error saving file: {e}")
                )
        elif button_id == "append-btn":
            try:
                with open(self.filename, 'a') as f:
                    f.write(self.content)

                self.app.pop_screen()
                self.app.pop_screen()
                self.app.pop_screen()  # Pop all the way back to view screen
                self.app.push_screen(
                    MessageScreen(f"Appended to: {self.filename}")
                )
            except Exception as e:
                self.app.push_screen(
                    MessageScreen(f"Error saving file: {e}")
                )
        elif button_id == "cancel-btn":
            self.app.pop_screen()


# Configuration screen - No changes needed
class ConfigScreen(Screen):
    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self, config: Config):
        super().__init__()
        self.config = config

    def compose(self) -> ComposeResult:
        yield Header("Configuration")

        with Vertical(id="config-menu"):
            yield Button("General Settings", variant="primary", id="general-btn")
            yield Button("Clipboard Settings", variant="primary", id="clipboard-btn")
            yield Button("Security Settings", variant="primary", id="security-btn")
            yield Button("History Settings", variant="primary", id="history-btn")
            yield Button("Back", variant="error", id="back-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "general-btn":
            self.app.push_screen(
                GeneralConfigScreen(self.config)
            )
        elif button_id == "clipboard-btn":
            self.app.push_screen(
                ClipboardConfigScreen(self.config)
            )
        elif button_id == "security-btn":
            self.app.push_screen(
                SecurityConfigScreen(self.config)
            )
        elif button_id == "history-btn":
            self.app.push_screen(
                HistoryConfigScreen(self.config)
            )
        elif button_id == "back-btn":
            self.app.pop_screen()


# General configuration screen - No changes needed
class GeneralConfigScreen(Screen):
    def __init__(self, config: Config):
        super().__init__()
        self.config = config

    def compose(self) -> ComposeResult:
        yield Header("General Settings")

        with Vertical(id="general-settings"):
            yield Static("Theme:")
            yield Select(
                [(theme, theme) for theme in ["synthwave", "matrix", "cyberpunk", "midnight"]],
                value=self.config.get("general", "theme"),
                id="theme-select"
            )

            yield Static("History Size:")
            yield Input(
                value=self.config.get("general", "history_size"),
                id="history-size-input"
            )

            yield Static("Display Count:")
            yield Input(
                value=self.config.get("general", "display_count"),
                id="display-count-input"
            )

            yield Static("Verbose Logging:")
            yield Switch(
                value=self.config.get_bool("general", "verbose_logging"),
                id="verbose-logging-switch"
            )

        with Horizontal(id="action-buttons"):
            yield Button("Save", variant="primary", id="save-btn")
            yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "save-btn":
            self.save_settings()
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    def on_select_changed(self, event: Select.Changed) -> None:
        """Handle theme selection change"""
        if event.select.id == "theme-select":
            self.config.set("general", "theme", event.value)

    def save_settings(self) -> None:
        """Save settings"""
        try:
            # History size
            history_size = self.query_one("#history-size-input", Input).value
            if history_size.isdigit() and 1 <= int(history_size) <= 999:
                self.config.set("general", "history_size", history_size)

            # Display count
            display_count = self.query_one("#display-count-input", Input).value
            if display_count.isdigit() and 1 <= int(display_count) <= 99:
                self.config.set("general", "display_count", display_count)

            # Verbose logging
            verbose_logging = self.query_one("#verbose-logging-switch", Switch).value
            self.config.set("general", "verbose_logging", str(verbose_logging).lower())

            # Theme already saved in on_select_changed

            self.app.pop_screen()
            self.app.push_screen(
                MessageScreen("Settings saved.")
            )
        except Exception as e:
            self.app.push_screen(
                MessageScreen(f"Error saving settings: {e}")
            )


# Clipboard configuration screen - No changes needed
class ClipboardConfigScreen(Screen):
    def __init__(self, config: Config):
        super().__init__()
        self.config = config

    def compose(self) -> ComposeResult:
        yield Header("Clipboard Settings")

        with Vertical(id="clipboard-settings"):
            yield Static("Auto Clear:")
            yield Switch(
                value=self.config.get_bool("clipboard", "auto_clear"),
                id="auto-clear-switch"
            )

            yield Static("Default Buffer:")
            yield Input(
                value=self.config.get("clipboard", "default_buffer"),
                id="default-buffer-input"
            )

            yield Static("Max File Size (MB):")
            yield Input(
                value=self.config.get("clipboard", "max_file_size"),
                id="max-file-size-input"
            )

        with Horizontal(id="action-buttons"):
            yield Button("Save", variant="primary", id="save-btn")
            yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "save-btn":
            self.save_settings()
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    def save_settings(self) -> None:
        """Save settings"""
        try:
            # Auto clear
            auto_clear = self.query_one("#auto-clear-switch", Switch).value
            self.config.set("clipboard", "auto_clear", str(auto_clear).lower())

            # Default buffer
            default_buffer = self.query_one("#default-buffer-input", Input).value
            if default_buffer.isdigit() and 0 <= int(default_buffer) <= 9:
                self.config.set("clipboard", "default_buffer", default_buffer)

            # Max file size
            max_file_size = self.query_one("#max-file-size-input", Input).value
            if max_file_size.isdigit() and 1 <= int(max_file_size) <= 9999:
                self.config.set("clipboard", "max_file_size", max_file_size)

            self.app.pop_screen()
            self.app.push_screen(
                MessageScreen("Settings saved.")
            )
        except Exception as e:
            self.app.push_screen(
                MessageScreen(f"Error saving settings: {e}")
            )


# Security configuration screen - No changes needed
class SecurityConfigScreen(Screen):
    def __init__(self, config: Config):
        super().__init__()
        self.config = config

    def compose(self) -> ComposeResult:
        yield Header("Security Settings")

        with Vertical(id="security-settings"):
            yield Static("Notifications:")
            yield Switch(
                value=self.config.get_bool("security", "notification"),
                id="notification-switch"
            )

            yield Static("Compression:")
            yield Switch(
                value=self.config.get_bool("security", "compression"),
                id="compression-switch"
            )

            yield Static("Encryption:")
            yield Switch(
                value=self.config.get_bool("security", "encryption"),
                id="encryption-switch"
            )

        with Horizontal(id="action-buttons"):
            yield Button("Save", variant="primary", id="save-btn")
            yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "save-btn":
            self.save_settings()
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    def save_settings(self) -> None:
        """Save settings"""
        try:
            # Notification
            notification = self.query_one("#notification-switch", Switch).value
            self.config.set("security", "notification", str(notification).lower())

            # Compression
            compression = self.query_one("#compression-switch", Switch).value
            self.config.set("security", "compression", str(compression).lower())

            # Encryption
            encryption = self.query_one("#encryption-switch", Switch).value
            self.config.set("security", "encryption", str(encryption).lower())

            self.app.pop_screen()
            self.app.push_screen(
                MessageScreen("Settings saved.")
            )
        except Exception as e:
            self.app.push_screen(
                MessageScreen(f"Error saving settings: {e}")
            )


# History configuration screen - Fixed the Select widget error
class HistoryConfigScreen(Screen):
    def __init__(self, config: Config):
        super().__init__()
        self.config = config

    def compose(self) -> ComposeResult:
        yield Header("History Settings")

        with Vertical(id="history-settings"):
            yield Static("Shell History Scan:")
            yield Switch(
                value=self.config.get_bool("history", "shell_history_scan"),
                id="shell-history-scan-switch"
            )

            yield Static("Prefer Local History:")
            yield Switch(
                value=self.config.get_bool("history", "prefer_local_history"),
                id="prefer-local-history-switch"
            )

            # Create options for the select dropdown
            preferred_history = self.config.get("history", "preferred_history")
            history_options = [("Auto Detect", "auto"), ("Bash", "bash"), ("ZSH", "zsh")]

            # Find the value in the options list
            selected_value = None
            for label, val in history_options:
                if val == preferred_history:
                    selected_value = val
                    break

            # If not found, use the first option
            if selected_value is None:
                selected_value = history_options[0][1]  # Use value, not label

            yield Static("Preferred History:")
            yield Select(
                options=history_options,  # Use named parameter
                value=selected_value,
                id="preferred-history-select"
            )

        with Horizontal(id="action-buttons"):
            yield Button("Save", variant="primary", id="save-btn")
            yield Button("Cancel", variant="error", id="cancel-btn")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        button_id = event.button.id

        if button_id == "save-btn":
            self.save_settings()
        elif button_id == "cancel-btn":
            self.app.pop_screen()

    def save_settings(self) -> None:
        """Save settings"""
        try:
            # Shell history scan
            shell_history_scan = self.query_one("#shell-history-scan-switch", Switch).value
            self.config.set("history", "shell_history_scan", str(shell_history_scan).lower())

            # Prefer local history
            prefer_local_history = self.query_one("#prefer-local-history-switch", Switch).value
            self.config.set("history", "prefer_local_history", str(prefer_local_history).lower())

            # Preferred history
            preferred_history = self.query_one("#preferred-history-select", Select).value
            self.config.set("history", "preferred_history", preferred_history)

            self.app.pop_screen()
            self.app.push_screen(
                MessageScreen("Settings saved.")
            )
        except Exception as e:
            self.app.push_screen(
                MessageScreen(f"Error saving settings: {e}")
            )


# Help screen - No changes needed
class HelpScreen(Screen):
    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header("Help")

        yield Markdown("""
# ClipBard Python Edition

A radical clipboard utility for terminal users.

## Features:
- Extract files from shell history for quick copying
- Browse and search files
- Copy line ranges from text files
- Multiple clipboard buffers
- Clipboard history tracking
- Security features (encryption, compression)
- Theme customization

## Navigation:
- Use arrow keys to navigate
- Press Escape to go back
- Use Tab to navigate between fields
- Press Enter or click buttons to select options

## Keyboard Shortcuts:
- q: Quit application
- h: Show this help
- c: Configuration
- b: Browse files
- s: Search
- v: View clipboard
        """, id="help-content")

        yield Button("Back", variant="primary", id="back-btn")
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        self.app.pop_screen()


# Main application - No changes needed
class ClipbardApp(App):
    BINDINGS = [
        Binding("q", "quit", "Quit"),
    ]

    TITLE = "ClipBard Python Edition"

    # Define CSS for styling the application
    CSS = """
    #logo {
        content-align: center middle;
        color: $accent;
        margin: 1 0;
    }

    #main-menu {
        align: center middle;
        width: 100%;
        height: auto;
        margin: 1 0;
    }

    Button {
        margin: 1 0;
        min-width: 20;
    }

    .heading {
        color: $accent;
        margin: 1 0;
    }

    #recent-history {
        margin: 1 0;
    }

    .file-btn {
        width: 100%;
        margin: 0 0;
    }

    #search-form, #line-range-form, #save-form, #confirm-form {
        align: center middle;
        width: 100%;
        height: auto;
        margin: 1 0;
    }

    #action-buttons {
        margin: 1 0;
    }

    #file-info {
        margin: 1 0;
    }

    #file-preview {
        margin: 1 0;
        height: 50%;
    }

    #general-settings, #clipboard-settings, #security-settings, #history-settings {
        margin: 1 0;
        height: auto;
    }

    Log {
        background: $surface;
        color: $text;
        margin: 1 0;
        height: 50%;
        border: tall $accent;
    }

    ListView {
        height: auto;
        border: tall $accent;
    }

    DirectoryTree {
        margin: 1 0;
        height: 90%;
    }

    Input {
        width: 40;
    }

    Select {
        width: 40;
    }

    Switch {
        margin: 1 0;
    }
    """

    def __init__(self):
        super().__init__()
        self._config = Config()
        self._history = History(self._config)
        self._clipboard = Clipboard(self._config, self._history)

    def on_mount(self) -> None:
        """Initialize screens on mount"""
        self.install_screen(WelcomeScreen(self._config, self._history, self._clipboard), name="welcome")
        self.install_screen(BrowseScreen(self._config, self._history, self._clipboard), name="browse")
        self.install_screen(SearchScreen(self._config, self._history, self._clipboard), name="search")
        self.install_screen(ViewScreen(self._config, self._clipboard), name="view")
        self.install_screen(ConfigScreen(self._config), name="config")
        self.install_screen(HelpScreen(), name="help")

        self.push_screen("welcome")


# Improved quick copy mode with key capture without Enter
def quick_copy_mode(config, history, clipboard):
    """Quick copy mode that shows latest history items for selection"""
    # Get display count from config
    display_count = config.get_int("general", "display_count")

    # Get history items and recent shell files
    history_items = history.get(display_count)
    shell_files = []
    if config.get_bool("history", "shell_history_scan"):
        try:
            shell_files = history.extract_files_from_shell_history(display_count)
        except:
            pass

    # Combine and remove duplicates while preserving order
    all_files = []
    for file_path in history_items + shell_files:
        if file_path not in all_files and os.path.exists(file_path):
            all_files.append(file_path)

    if not all_files:
        print("No history items found. Use 'clipbard config' to launch the configuration interface.")
        return

    # Print compact list of available files
    print("Select a file to copy (press key):")

    # Show only first 9 options to use single-key selection
    display_files = all_files[:9]

    for i, file_path in enumerate(display_files, 1):
        print(f"{i}. {os.path.basename(file_path)} [{FileUtils.human_readable_size(os.path.getsize(file_path))}]")

    print("c. Cancel / q. Quit / t. TUI")

    # Get keypress without Enter
    choice = getch()

    if choice.lower() in ('c', 'q'):
        return
    elif choice.lower() == 't':
        ClipbardApp().run()
        return

    try:
        idx = int(choice) - 1
        if 0 <= idx < len(display_files):
            file_path = display_files[idx]
            if clipboard.copy_to_clipboard(file_path):
                print(f"Copied: {os.path.basename(file_path)}")
            else:
                print(f"Error: Failed to copy {file_path}")
        else:
            print("Invalid selection.")
    except ValueError:
        print("Invalid input.")


# Command-line interface - Updated to improve UX
def parse_args():
    """Parse command-line arguments"""
    args = sys.argv[1:]

    # Initialize core components
    config = Config()
    history = History(config)
    clipboard = Clipboard(config, history)

    # No arguments - show latest history items for quick selection
    if not args:
        quick_copy_mode(config, history, clipboard)
        return

    # Process commands
    cmd = args[0]

    if cmd == "config":
        # Launch the full TUI with config option
        ClipbardApp().run()
    elif cmd == "install" or cmd == "i":
        install_clipbard()
    elif cmd == "uninstall" or cmd == "u":
        uninstall_clipbard()
    elif cmd == "update":
        update_clipbard()
    elif cmd == "version" or cmd == "v":
        print_version()
    elif cmd == "help" or cmd == "h":
        print_help()
    elif cmd == "t":
        # Copy text directly
        if len(args) > 1:
            clipboard.copy_text_to_clipboard(args[1])
            print(f"Text copied to clipboard.")
        else:
            print("Error: No text provided.")
    elif cmd == "tui":
        # Launch full TUI interface
        ClipbardApp().run()
    elif os.path.isfile(cmd):
        # Treat as file path
        if clipboard.copy_to_clipboard(cmd):
            print(f"Copied to clipboard: {cmd}")
        else:
            print(f"Error: Failed to copy {cmd} to clipboard.")
    else:
        print(f"Error: '{cmd}' is not a valid command or file.")
        print_help()


# Helper functions for command-line mode - No changes needed
def install_clipbard():
    """Install clipbard to system"""
    print("Installing ClipBard...")

    script_dir = os.path.expanduser("~/.local/bin")
    os.makedirs(script_dir, exist_ok=True)

    # Copy script to bin directory
    script_path = os.path.join(script_dir, "clipbard")
    shutil.copy(sys.argv[0], script_path)
    os.chmod(script_path, 0o755)

    # Add to PATH if needed
    if script_dir not in os.environ["PATH"].split(":"):
        shell_config = None
        if "ZSH_VERSION" in os.environ:
            shell_config = os.path.expanduser("~/.zshrc")
        elif "BASH_VERSION" in os.environ:
            shell_config = os.path.expanduser("~/.bashrc")
        else:
            shell_config = os.path.expanduser("~/.profile")

        with open(shell_config, "a") as f:
            f.write(f'\nexport PATH="$PATH:{script_dir}"\n')

        print(f"PATH updated in {shell_config}")
        print(f"TIP: Run 'source {shell_config}' to activate")

    print("Installation complete!")


def uninstall_clipbard():
    """Uninstall clipbard from system"""
    print("Uninstalling ClipBard...")

    script_path = os.path.join(os.path.expanduser("~/.local/bin"), "clipbard")
    if os.path.exists(script_path):
        os.unlink(script_path)
        print("Removed executable.")

    if input("Delete configuration and history too? (y/n): ").lower() == "y":
        shutil.rmtree(CONFIG_DIR, ignore_errors=True)
        print("Removed configuration and history.")

    print("Uninstallation complete!")


def update_clipbard():
    """Update clipbard"""
    print("Updating ClipBard...")

    # Create temporary directory
    temp_dir = tempfile.mkdtemp()

    try:
        # Clone the repository
        subprocess.run(["git", "clone", "--depth", "1", GITHUB_REPO, temp_dir], check=True)

        # Check if the Python version exists
        py_script = os.path.join(temp_dir, "clipbard.py")
        if os.path.exists(py_script):
            # Make backup
            script_path = os.path.join(os.path.expanduser("~/.local/bin"), "clipbard")
            if os.path.exists(script_path):
                shutil.copy(script_path, f"{script_path}.backup")
                print(f"Backup saved to: {script_path}.backup")

            # Copy new version
            shutil.copy(py_script, script_path)
            os.chmod(script_path, 0o755)
            print("Update complete!")
        else:
            print("Error: Python version not found in repository.")
    except Exception as e:
        print(f"Error updating ClipBard: {e}")
    finally:
        # Clean up
        shutil.rmtree(temp_dir, ignore_errors=True)


def print_version():
    """Print version information"""
    print(f"ClipBard Python Edition v{VERSION}")
    print("A clipboard utility for terminal users")


# Updated help to be more compact
def print_help():
    """Print help information"""
    print(f"""
ClipBard Python Edition v{VERSION}
Usage:
  clipbard [COMMAND] [ARGS]

Commands:
  (No command)   Show quick clipboard selection
  config         Launch configuration TUI
  tui            Launch full interface
  t TEXT         Copy text directly to clipboard
  install, i     Install ClipBard to system
  uninstall, u   Uninstall ClipBard
  update         Update to latest version
  version, v     Show version information
  help, h        Show this help
    """)


# Main entry point - No changes needed
if __name__ == "__main__":
    try:
        parse_args()
    except KeyboardInterrupt:
        print("\nOperation cancelled by user.")
        sys.exit(1)