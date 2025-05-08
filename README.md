# CLIP - The Radical Clipboard Utility

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0.0-ff00ff?style=for-the-badge&labelColor=282c34" alt="Version"/>
  <img src="https://img.shields.io/badge/Shell-Bash-00ffff?style=for-the-badge&logo=gnubash&logoColor=white&labelColor=282c34" alt="Made with Bash"/>
  <img src="https://img.shields.io/badge/Era-Synthwave-ff00cc?style=for-the-badge&labelColor=282c34" alt="Synthwave Era"/>
</p>

```
╔═╗╦  ╦╔═╗    ╦ ╦╔╦╗╦╦  ╦╔╦╗╦ ╦
║  ║  ║╠═╝    ║ ║ ║ ║║  ║ ║ ╚╦╝
╚═╝╩═╝╩╩      ╚═╝ ╩ ╩╩═╝╩ ╩  ╩ 
```

A mind-bending clipboard manager for cyberpunk command-line aficionados. Copy files, text, and code fragments to your clipboard with neon-infused, laser-precise control.

## ⚡ FEATURES

- 🔮 Copy **any file** to clipboard with a simple command
- 🎯 Select from **customizable history** with interactive TUI
- 🌈 Preview files before uploading to memory with syntax highlighting
- 🧠 Copy specific line ranges for surgical precision
- 🔍 Search through history or deep scan file contents
- 🗺️ Explore directories in an interactive file browser
- 📋 Multiple clipboard buffers for power users
- 🔄 Convert between file formats on the fly
- 🔐 Optional encryption for sensitive clipboard data
- 🗜️ Automatic compression for large files
- 📊 Usage statistics to track your clipboard habits
- 🎨 Multiple visual themes (Synthwave, Matrix, Cyberpunk, Midnight)
- 🛠️ Self-contained installer with shell completion
- 💾 Persistent configuration with customizable settings
- 🔄 Automatic updates from GitHub
- 🌟 Retro-futuristic interface with radical colors

## ⚡ INSTALLATION

### One-command install

```bash
curl -sSL https://github.com/eraxe/clip/raw/main/clip.sh > clipbard.sh && chmod +x clipbard.sh && ./clipbard.sh --install
```

### Manual install

1. Clone the repository:
   ```bash
   git clone https://github.com/eraxe/clip.git
   ```

2. Enter the directory:
   ```bash
   cd clipbard
   ```

3. Run the installer:
   ```bash
   ./clipbard.sh --install
   ```

## ⚡ USAGE

### Basic usage

```bash
# Copy a file to clipboard
clipbard /path/to/file.txt

# Select from recent files (interactive mode)
clipbard

# Copy text directly to clipboard
clipbard -t "This is some radical text"
```

### Advanced features

```bash
# Preview file before copying
clipbard -p /path/to/file.txt

# Preview and select specific line ranges to copy
clipbard -ps /path/to/code.py

# Search through your clipboard history
clipbard --search

# Deep search for content within files
clipbard --find

# Browse files interactively
clipbard --browse ~/Projects

# Switch between clipboard buffers
clipbard --buffer 2

# View current clipboard content
clipbard --view

# Convert file between formats
clipbard --convert document.md html

# Configure settings
clipbard --config

# View usage statistics
clipbard --stats
```

## ⚡ CONFIGURATION

CLIP is highly configurable with persistent settings:

```bash
# Edit configuration
clipbard --config
```

Available settings:
- `history_size`: Number of files to remember (default: 50)
- `display_count`: Number of items to show in selection (default: 5)
- `theme`: Visual theme - synthwave, matrix, cyberpunk, midnight
- `auto_clear`: Automatically clear clipboard after 60 seconds
- `notification`: Desktop notifications for clipboard operations
- `compression`: Compress large files before copying
- `encryption`: Encrypt clipboard content for sensitive data
- `default_buffer`: Default clipboard buffer to use (0-9)

Configuration is stored in `~/.config/clip/config.ini`.

## ⚡ DEPENDENCIES

- **gum** - For totally rad TUI elements
- **git** - For system upgrades
- **xclip** (X11) or **wl-copy** (Wayland) - For clipboard integration
- **pandoc** - For format conversion (optional)
- **openssl** - For encryption (optional)
- **chafa** - For image preview (optional)

The installer will check for required dependencies and help you install them.

## ⚡ SHELL COMPLETION

CLIP automatically installs shell completion for bash and zsh during installation, giving you tab completion for all commands and options.

## ⚡ UNINSTALLATION

```bash
clipbard --uninstall
```

## ⚡ CONTRIBUTING

Contributions welcome! Feel free to enhance this radical utility with:

- New features
- Bug fixes
- Documentation improvements
- Cyberpunk aesthetics

## ⚡ LICENSE

MIT License

## ⚡ AUTHOR

Created by Arash Abolhasani ([@eraxe](https://github.com/eraxe)) in a parallel universe where synthwave never died and command lines are the ultimate interface.

---

<p align="center">
  <img src="https://img.shields.io/badge/Made_with-Neon_&_Nostalgia-ff00cc?style=for-the-badge&labelColor=282c34" alt="Made with Neon & Nostalgia"/>
</p>
