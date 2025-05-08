#!/bin/bash
#
# ╔═╗ ╦  ╦ ╔═╗
# ║   ║  ║ ╠═╝
# ╚═╝ ╩═╝╩ ╩  
#
# A R A D I C A L clipboard utility
# by Arash Abolhasani (@eraxe)

VERSION="1.0.0"
NEON_PINK='\e[38;5;213m'
NEON_BLUE='\e[38;5;51m'
NEON_GREEN='\e[38;5;82m'
NEON_YELLOW='\e[38;5;226m'
RESET='\e[0m'

HISTORY_FILE="$HOME/.config/clip/history"
CONFIG_DIR="$HOME/.config/clip"
SCRIPT_DIR="$HOME/.local/bin"
SCRIPT_PATH="$SCRIPT_DIR/clip"
GITHUB_REPO="https://github.com/eraxe/clip"

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$SCRIPT_DIR"
touch "$HISTORY_FILE"

# Print banner
print_banner() {
    echo -e "${NEON_BLUE}"
    echo -e "╔═╗╦  ╦╔═╗    ╦ ╦╔╦╗╦╦  ╦╔╦╗╦ ╦"
    echo -e "║  ║  ║╠═╝    ║ ║ ║ ║║  ║ ║ ╚╦╝"
    echo -e "╚═╝╩═╝╩╩      ╚═╝ ╩ ╩╩═╝╩ ╩  ╩ "
    echo -e "${NEON_PINK}v${VERSION} - Radical Clipboard Utility${RESET}"
    echo
}

# Check for dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v gum &> /dev/null; then
        missing_deps+=("gum")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v wl-copy &> /dev/null && ! command -v xclip &> /dev/null; then
        if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
            missing_deps+=("wl-clipboard")
        else
            missing_deps+=("xclip")
        fi
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${NEON_YELLOW}⚡ SYSTEM INCOMPATIBILITY DETECTED ⚡${RESET}"
        echo -e "Missing dependencies: ${missing_deps[*]}"
        
        if command -v pacman &> /dev/null; then
            echo -e "${NEON_GREEN}Detected Arch-based system.${RESET}"
            if gum confirm "Install missing components?"; then
                sudo pacman -S "${missing_deps[@]}"
            else
                echo -e "${NEON_YELLOW}Installation aborted. System remains unconfigured.${RESET}"
                exit 1
            fi
        elif command -v apt &> /dev/null; then
            echo -e "${NEON_GREEN}Detected Debian/Ubuntu-based system.${RESET}"
            if gum confirm "Install missing components?"; then
                sudo apt update && sudo apt install -y "${missing_deps[@]}"
            else
                echo -e "${NEON_YELLOW}Installation aborted. System remains unconfigured.${RESET}"
                exit 1
            fi
        else
            echo -e "${NEON_YELLOW}Please install the dependencies manually.${RESET}"
            exit 1
        fi
    fi
}

# Function to copy file content to clipboard silently
copy_to_clipboard() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${NEON_YELLOW}ERROR: File '$file' not found in the system.${RESET}"
        return 1
    fi
    
    # Get file size and notify
    local size=$(du -h "$file" | cut -f1)
    
    # Copy to clipboard based on environment
    if command -v wl-copy &> /dev/null; then
        # For Wayland
        wl-copy < "$file" 2>/dev/null
    elif command -v xclip &> /dev/null; then
        # For X11
        xclip -selection clipboard < "$file" 2>/dev/null
    else
        echo -e "${NEON_YELLOW}ERROR: No clipboard utility detected.${RESET}"
        return 1
    fi
    
    # Update history - add to beginning, maintain uniqueness
    local tmp_file=$(mktemp)
    echo "$file" > "$tmp_file"
    grep -v "^$file$" "$HISTORY_FILE" | head -n 9 >> "$tmp_file"
    mv "$tmp_file" "$HISTORY_FILE"
    
    # Display cool-looking success message
    echo -e "${NEON_GREEN}█▓▒░ TRANSFER COMPLETE ░▒▓█${RESET}"
    echo -e "${NEON_BLUE}File:${RESET} $(basename "$file")"
    echo -e "${NEON_BLUE}Size:${RESET} $size"
    echo -e "${NEON_BLUE}Path:${RESET} $file"
    echo -e "${NEON_GREEN}Copied to memory buffer!${RESET}"
    return 0
}

# Copy text directly to clipboard
copy_text_to_clipboard() {
    local text="$1"
    
    if command -v wl-copy &> /dev/null; then
        echo -n "$text" | wl-copy
    elif command -v xclip &> /dev/null; then
        echo -n "$text" | xclip -selection clipboard
    else
        echo -e "${NEON_YELLOW}ERROR: No clipboard utility detected.${RESET}"
        return 1
    fi
    
    echo -e "${NEON_GREEN}Text loaded into memory buffer!${RESET}"
}

# Function to show file preview
preview_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${NEON_YELLOW}ERROR: File not found.${RESET}"
        return 1
    fi
    
    local lines=$(wc -l < "$file")
    local size=$(du -h "$file" | cut -f1)
    local type=$(file -b "$file")
    
    echo -e "${NEON_BLUE}█▓▒░ FILE ANALYSIS ░▒▓█${RESET}"
    echo -e "${NEON_GREEN}Filename:${RESET} $(basename "$file")"
    echo -e "${NEON_GREEN}Size:${RESET} $size"
    echo -e "${NEON_GREEN}Lines:${RESET} $lines"
    echo -e "${NEON_GREEN}Type:${RESET} $type"
    echo
    
    if [[ "$type" == *"text"* ]]; then
        echo -e "${NEON_BLUE}█▓▒░ FILE PREVIEW ░▒▓█${RESET}"
        head -n 10 "$file" | gum style --border normal --margin "1" --padding "1"
        
        if [ "$lines" -gt 10 ]; then
            echo -e "${NEON_YELLOW}... ($(($lines - 10)) more lines)${RESET}"
        fi
    else
        echo -e "${NEON_YELLOW}Binary file - preview unavailable${RESET}"
    fi
}

# Interactive file selection with gum
select_from_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${NEON_YELLOW}No files in memory banks.${RESET}"
        exit 1
    fi
    
    # Get unique history entries
    local history_entries=()
    mapfile -t history_entries < "$HISTORY_FILE"
    
    # Use gum to create rad interactive selection
    echo -e "${NEON_BLUE}█▓▒░ SELECT FILE TO UPLOAD ░▒▓█${RESET}"
    local selected_file
    selected_file=$(gum choose --height=10 "${history_entries[@]:0:3}")
    
    if [ -n "$selected_file" ]; then
        copy_to_clipboard "$selected_file"
    else
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
        exit 1
    fi
}

# Installer function
install_clip() {
    echo -e "${NEON_BLUE}█▓▒░ INSTALLING SYSTEM ░▒▓█${RESET}"
    
    # Copy script to bin directory
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    # Add to PATH if needed
    if [[ ":$PATH:" != *":$SCRIPT_DIR:"* ]]; then
        # Detect shell and update appropriate config file
        local shell_config
        if [ -n "$ZSH_VERSION" ]; then
            shell_config="$HOME/.zshrc"
        elif [ -n "$BASH_VERSION" ]; then
            shell_config="$HOME/.bashrc"
        else
            shell_config="$HOME/.profile"
        fi
        
        echo "export PATH=\"\$PATH:$SCRIPT_DIR\"" >> "$shell_config"
        echo -e "${NEON_GREEN}PATH updated in $shell_config${RESET}"
        echo -e "${NEON_YELLOW}TIP: Run 'source $shell_config' to activate${RESET}"
    fi
    
    echo -e "${NEON_GREEN}█▓▒░ INSTALLATION COMPLETE ░▒▓█${RESET}"
    exit 0
}

# Uninstaller function
uninstall_clip() {
    echo -e "${NEON_BLUE}█▓▒░ SYSTEM REMOVAL UTILITY ░▒▓█${RESET}"
    
    if gum confirm "Delete CLIP from your system?"; then
        rm -f "$SCRIPT_PATH"
        if gum confirm "Delete configuration and history too?"; then
            rm -rf "$CONFIG_DIR"
        fi
        echo -e "${NEON_GREEN}CLIP system purged successfully.${RESET}"
        echo -e "${NEON_YELLOW}Note: PATH modifications remain intact.${RESET}"
    else
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
    fi
    exit 0
}

# Update function that pulls the latest version from GitHub
update_clip() {
    echo -e "${NEON_BLUE}█▓▒░ SYSTEM UPGRADE INITIATED ░▒▓█${RESET}"
    
    # Create temporary directory for update
    local temp_dir=$(mktemp -d)
    
    # Clone the repository
    if git clone --depth 1 "$GITHUB_REPO" "$temp_dir"; then
        if [ -f "$temp_dir/clip.sh" ]; then
            # Make backup of current script
            cp "$SCRIPT_PATH" "$SCRIPT_PATH.backup"
            
            # Replace with new version
            cp "$temp_dir/clip.sh" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            
            # Clean up
            rm -rf "$temp_dir"
            
            echo -e "${NEON_GREEN}█▓▒░ UPGRADE COMPLETE ░▒▓█${RESET}"
            echo -e "${NEON_YELLOW}Backup saved to:${RESET} $SCRIPT_PATH.backup"
        else
            echo -e "${NEON_YELLOW}ERROR: clip.sh not found in repository.${RESET}"
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        echo -e "${NEON_YELLOW}ERROR: Failed to access the repository.${RESET}"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    exit 0
}

# Print help message with fancy styling
print_help() {
    print_banner
    echo -e "${NEON_BLUE}█▓▒░ COMMAND REFERENCE ░▒▓█${RESET}"
    echo
    echo -e "${NEON_GREEN}Basic Usage:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} [FILENAME]          Copy file to clipboard"
    echo -e "  ${NEON_PINK}clip${RESET}                   Select from recent files"
    echo -e "  ${NEON_PINK}clip${RESET} -t \"text\"          Copy text directly"
    echo
    echo -e "${NEON_GREEN}Preview Commands:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} -p [FILENAME]      Preview file before copying"
    echo -e "  ${NEON_PINK}clip${RESET} -ps [FILENAME]     Preview and select line ranges"
    echo
    echo -e "${NEON_GREEN}System Commands:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} --install          Install to system"
    echo -e "  ${NEON_PINK}clip${RESET} --uninstall        Remove from system"
    echo -e "  ${NEON_PINK}clip${RESET} --update           Upgrade to latest version"
    echo
    echo -e "${NEON_GREEN}Info Commands:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} --version          Show version info"
    echo -e "  ${NEON_PINK}clip${RESET} --help             Show this help"
    echo -e "  ${NEON_PINK}clip${RESET} --history          View copy history"
    echo
    echo -e "${NEON_BLUE}Created by Arash Abolhasani (@eraxe)${RESET}"
    exit 0
}

# View history
view_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${NEON_YELLOW}No files in memory banks.${RESET}"
        exit 1
    fi
    
    echo -e "${NEON_BLUE}█▓▒░ MEMORY BANKS ░▒▓█${RESET}"
    cat "$HISTORY_FILE" | nl | gum style --border normal --margin "1" --padding "1"
    exit 0
}

# Copy specific line ranges from file
copy_line_range() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${NEON_YELLOW}ERROR: File not found.${RESET}"
        return 1
    fi
    
    # Preview the file with line numbers
    echo -e "${NEON_BLUE}█▓▒░ FILE CONTENTS ░▒▓█${RESET}"
    nl -ba "$file" | gum style --border normal --margin "1" --padding "1"
    
    # Ask for line range
    local range
    echo -e "${NEON_GREEN}Enter line range (e.g., 5-10 or 5 for single line):${RESET}"
    range=$(gum input --placeholder "5-10")
    
    # Parse range and copy
    if [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}"
        local end="${BASH_REMATCH[2]}"
        
        if [ "$start" -gt "$end" ]; then
            echo -e "${NEON_YELLOW}Invalid range: start > end${RESET}"
            return 1
        fi
        
        local content=$(sed -n "${start},${end}p" "$file")
        copy_text_to_clipboard "$content"
        echo -e "${NEON_GREEN}Copied lines ${start}-${end} to clipboard.${RESET}"
    elif [[ "$range" =~ ^([0-9]+)$ ]]; then
        local line="${BASH_REMATCH[1]}"
        local content=$(sed -n "${line}p" "$file")
        copy_text_to_clipboard "$content"
        echo -e "${NEON_GREEN}Copied line ${line} to clipboard.${RESET}"
    else
        echo -e "${NEON_YELLOW}Invalid range format.${RESET}"
        return 1
    fi
}

# Main logic
check_dependencies

if [ "$1" = "--install" ]; then
    install_clip
elif [ "$1" = "--uninstall" ]; then
    uninstall_clip
elif [ "$1" = "--update" ]; then
    update_clip
elif [ "$1" = "--version" ]; then
    print_banner
    exit 0
elif [ "$1" = "--help" ]; then
    print_help
elif [ "$1" = "--history" ]; then
    view_history
elif [ "$1" = "-t" ] && [ -n "$2" ]; then
    # Copy text directly
    copy_text_to_clipboard "$2"
elif [ "$1" = "-p" ] && [ -n "$2" ]; then
    # Preview file then copy
    preview_file "$2"
    if gum confirm "Copy to clipboard?"; then
        copy_to_clipboard "$2"
    fi
elif [ "$1" = "-ps" ] && [ -n "$2" ]; then
    # Preview file and select line ranges to copy
    copy_line_range "$2"
elif [ $# -eq 0 ]; then
    # No arguments provided, show selection UI
    select_from_history
else
    # Use the provided file
    copy_to_clipboard "$1"
fi
