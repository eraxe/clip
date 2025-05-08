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
NEON_PURPLE='\e[38;5;171m'
NEON_ORANGE='\e[38;5;214m'
RESET='\e[0m'

# Default configuration
CONFIG_DIR="$HOME/.config/clip"
HISTORY_FILE="$CONFIG_DIR/history"
CONFIG_FILE="$CONFIG_DIR/config.ini"
SCRIPT_DIR="$HOME/.local/bin"
SCRIPT_PATH="$SCRIPT_DIR/clip"
GITHUB_REPO="https://github.com/eraxe/clip"
DEFAULT_HISTORY_SIZE=50
DEFAULT_DISPLAY_COUNT=5
DEFAULT_THEME="synthwave"
DEFAULT_CLIPBOARD_BUFFER=0
TMP_DIR="/tmp/clip-tmp"

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$TMP_DIR"
touch "$HISTORY_FILE"

# Create default config if doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOL
# CLIP Configuration File
history_size=$DEFAULT_HISTORY_SIZE
display_count=$DEFAULT_DISPLAY_COUNT
theme=$DEFAULT_THEME
auto_clear=false
notification=true
compression=false
encryption=false
default_buffer=$DEFAULT_CLIPBOARD_BUFFER
EOL
fi

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Read config values
        HISTORY_SIZE=$(grep "^history_size=" "$CONFIG_FILE" | cut -d= -f2)
        DISPLAY_COUNT=$(grep "^display_count=" "$CONFIG_FILE" | cut -d= -f2)
        THEME=$(grep "^theme=" "$CONFIG_FILE" | cut -d= -f2)
        AUTO_CLEAR=$(grep "^auto_clear=" "$CONFIG_FILE" | cut -d= -f2)
        NOTIFICATION=$(grep "^notification=" "$CONFIG_FILE" | cut -d= -f2)
        COMPRESSION=$(grep "^compression=" "$CONFIG_FILE" | cut -d= -f2)
        ENCRYPTION=$(grep "^encryption=" "$CONFIG_FILE" | cut -d= -f2)
        DEFAULT_BUFFER=$(grep "^default_buffer=" "$CONFIG_FILE" | cut -d= -f2)
    else
        # Use defaults
        HISTORY_SIZE=$DEFAULT_HISTORY_SIZE
        DISPLAY_COUNT=$DEFAULT_DISPLAY_COUNT
        THEME=$DEFAULT_THEME
        AUTO_CLEAR="false"
        NOTIFICATION="true"
        COMPRESSION="false"
        ENCRYPTION="false"
        DEFAULT_BUFFER=$DEFAULT_CLIPBOARD_BUFFER
    fi
}

# Load config
load_config

# Apply theme
apply_theme() {
    case "$THEME" in
        "matrix")
            NEON_PINK='\e[38;5;40m'
            NEON_BLUE='\e[38;5;34m'
            NEON_GREEN='\e[38;5;46m'
            NEON_YELLOW='\e[38;5;40m'
            NEON_PURPLE='\e[38;5;34m'
            NEON_ORANGE='\e[38;5;46m'
            ;;
        "cyberpunk")
            NEON_PINK='\e[38;5;201m'
            NEON_BLUE='\e[38;5;45m'
            NEON_GREEN='\e[38;5;226m'
            NEON_YELLOW='\e[38;5;214m'
            NEON_PURPLE='\e[38;5;201m'
            NEON_ORANGE='\e[38;5;208m'
            ;;
        "midnight")
            NEON_PINK='\e[38;5;61m'
            NEON_BLUE='\e[38;5;63m'
            NEON_GREEN='\e[38;5;37m'
            NEON_YELLOW='\e[38;5;109m'
            NEON_PURPLE='\e[38;5;61m'
            NEON_ORANGE='\e[38;5;67m'
            ;;
        *)
            # Default synthwave theme colors are already set
            ;;
    esac
}

apply_theme

# Print banner
print_banner() {
    echo -e "${NEON_BLUE}"
    echo -e "╔═╗╦  ╦╔═╗    ╦ ╦╔╦╗╦╦  ╦╔╦╗╦ ╦"
    echo -e "║  ║  ║╠═╝    ║ ║ ║ ║║  ║ ║ ╚╦╝"
    echo -e "╚═╝╩═╝╩╩      ╚═╝ ╩ ╩╩═╝╩ ╩  ╩ "
    echo -e "${NEON_PINK}v${VERSION} - Radical Clipboard Utility${RESET}"
    echo
}

# Show notification (if enabled)
show_notification() {
    local title="$1"
    local message="$2"
    
    if [ "$NOTIFICATION" = "true" ] && command -v notify-send &> /dev/null; then
        notify-send -a "CLIP" "$title" "$message"
    fi
}

# Encrypt content
encrypt_content() {
    local content="$1"
    local passphrase
    
    if [ "$ENCRYPTION" = "true" ]; then
        if command -v openssl &> /dev/null; then
            echo -e "${NEON_YELLOW}Enter encryption passphrase:${RESET}"
            passphrase=$(gum input --password)
            
            if [ -n "$passphrase" ]; then
                local encrypted=$(echo "$content" | openssl enc -aes-256-cbc -a -salt -pass pass:"$passphrase" 2>/dev/null)
                echo "$encrypted"
                return 0
            fi
        else
            echo -e "${NEON_YELLOW}OpenSSL not found, encryption disabled.${RESET}"
        fi
    fi
    
    # Return original content if encryption is disabled or failed
    echo "$content"
}

# Decrypt content
decrypt_content() {
    local content="$1"
    local passphrase
    
    if [ "$ENCRYPTION" = "true" ] && [[ "$content" == "Salted__"* || "$content" == "U2FsdGVk"* ]]; then
        if command -v openssl &> /dev/null; then
            echo -e "${NEON_YELLOW}Enter decryption passphrase:${RESET}"
            passphrase=$(gum input --password)
            
            if [ -n "$passphrase" ]; then
                local decrypted=$(echo "$content" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$passphrase" 2>/dev/null)
                echo "$decrypted"
                return 0
            fi
        fi
    fi
    
    # Return original content if decryption is disabled or failed
    echo "$content"
}

# Compress content (for large files)
compress_content() {
    local file="$1"
    local output="$TMP_DIR/$(basename "$file").gz"
    
    if [ "$COMPRESSION" = "true" ] && [ -f "$file" ]; then
        if command -v gzip &> /dev/null; then
            local filesize=$(du -k "$file" | cut -f1)
            
            # Only compress if file is larger than 100KB
            if [ "$filesize" -gt 100 ]; then
                gzip -c "$file" > "$output"
                echo -e "${NEON_GREEN}File compressed for clipboard.${RESET}"
                echo "$output"
                return 0
            fi
        fi
    fi
    
    # Return original file path if compression is disabled or not needed
    echo "$file"
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
    
    if [ "$ENCRYPTION" = "true" ] && ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
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

# Function to get current clipboard content
get_clipboard_content() {
    local buffer="${1:-$DEFAULT_BUFFER}"
    local content=""
    
    if command -v wl-paste &> /dev/null; then
        # For Wayland
        content=$(wl-paste 2>/dev/null)
    elif command -v xclip &> /dev/null; then
        # For X11
        content=$(xclip -selection clipboard -o 2>/dev/null)
    fi
    
    echo "$content"
}

# Function to copy file content to clipboard
copy_to_clipboard() {
    local file="$1"
    local buffer="${2:-$DEFAULT_BUFFER}"
    
    if [ ! -f "$file" ]; then
        echo -e "${NEON_YELLOW}ERROR: File '$file' not found in the system.${RESET}"
        return 1
    fi
    
    # Get file size and notify
    local size=$(du -h "$file" | cut -f1)
    local fileName=$(basename "$file")
    local fileExt="${fileName##*.}"
    
    # Handle compression if enabled
    local compressed_file=$(compress_content "$file")
    
    # Copy to clipboard based on environment
    if command -v wl-copy &> /dev/null; then
        # For Wayland
        wl-copy < "$compressed_file" 2>/dev/null
    elif command -v xclip &> /dev/null; then
        # For X11
        xclip -selection clipboard < "$compressed_file" 2>/dev/null
    else
        echo -e "${NEON_YELLOW}ERROR: No clipboard utility detected.${RESET}"
        return 1
    fi
    
    # Auto-clear previous clipboard if enabled
    if [ "$AUTO_CLEAR" = "true" ]; then
        echo "Auto-clearing previous clipboard in 60 seconds..."
        (sleep 60 && echo -n "" | clipboard_copy) &
    fi
    
    # Update history - add to beginning, maintain uniqueness
    local tmp_file=$(mktemp)
    echo "$file" > "$tmp_file"
    grep -v "^$file$" "$HISTORY_FILE" | head -n $(($HISTORY_SIZE-1)) >> "$tmp_file"
    mv "$tmp_file" "$HISTORY_FILE"
    
    # Display cool-looking success message
    echo -e "${NEON_GREEN}█▓▒░ TRANSFER COMPLETE ░▒▓█${RESET}"
    echo -e "${NEON_BLUE}File:${RESET} $(basename "$file")"
    echo -e "${NEON_BLUE}Size:${RESET} $size"
    echo -e "${NEON_BLUE}Path:${RESET} $file"
    echo -e "${NEON_BLUE}Type:${RESET} $(file -b "$file" | cut -d, -f1)"
    echo -e "${NEON_GREEN}Copied to memory buffer ${buffer}!${RESET}"
    
    # Send notification
    show_notification "CLIP" "Copied: $(basename "$file")"
    
    # Cleanup compressed file if needed
    if [ "$compressed_file" != "$file" ]; then
        rm -f "$compressed_file"
    fi
    
    return 0
}

# Copy text directly to clipboard
copy_text_to_clipboard() {
    local text="$1"
    local buffer="${2:-$DEFAULT_BUFFER}"
    
    # Handle encryption if enabled
    local encrypted_text=$(encrypt_content "$text")
    
    if command -v wl-copy &> /dev/null; then
        echo -n "$encrypted_text" | wl-copy
    elif command -v xclip &> /dev/null; then
        echo -n "$encrypted_text" | xclip -selection clipboard
    else
        echo -e "${NEON_YELLOW}ERROR: No clipboard utility detected.${RESET}"
        return 1
    fi
    
    # Auto-clear if enabled
    if [ "$AUTO_CLEAR" = "true" ]; then
        echo "Auto-clearing clipboard in 60 seconds..."
        (sleep 60 && echo -n "" | clipboard_copy) &
    fi
    
    show_notification "CLIP" "Text copied to clipboard"
    echo -e "${NEON_GREEN}Text loaded into memory buffer ${buffer}!${RESET}"
}

# Function to show file preview
preview_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${NEON_YELLOW}ERROR: File not found.${RESET}"
        return 1
    fi
    
    local lines=$(wc -l < "$file" 2>/dev/null || echo "N/A")
    local size=$(du -h "$file" | cut -f1)
    local type=$(file -b "$file")
    local modified=$(stat -c '%y' "$file" 2>/dev/null || echo "N/A")
    
    echo -e "${NEON_BLUE}█▓▒░ FILE ANALYSIS ░▒▓█${RESET}"
    echo -e "${NEON_GREEN}Filename:${RESET} $(basename "$file")"
    echo -e "${NEON_GREEN}Size:${RESET} $size"
    echo -e "${NEON_GREEN}Lines:${RESET} $lines"
    echo -e "${NEON_GREEN}Type:${RESET} $type"
    echo -e "${NEON_GREEN}Modified:${RESET} $modified"
    echo
    
    if [[ "$type" == *"text"* ]]; then
        echo -e "${NEON_BLUE}█▓▒░ FILE PREVIEW ░▒▓█${RESET}"
        head -n 10 "$file" | gum style --border normal --margin "1" --padding "1"
        
        if [ "$lines" != "N/A" ] && [ "$lines" -gt 10 ]; then
            echo -e "${NEON_YELLOW}... ($(($lines - 10)) more lines)${RESET}"
        fi
    elif [[ "$type" == *"image"* ]]; then
        echo -e "${NEON_PURPLE}[Image File]${RESET}"
        
        # Try to use image preview if available
        if command -v chafa &> /dev/null; then
            chafa --size=40x20 "$file"
        else
            echo -e "${NEON_YELLOW}Install 'chafa' for terminal image previews${RESET}"
        fi
    else
        echo -e "${NEON_YELLOW}Binary file - preview unavailable${RESET}"
        hexdump -C "$file" | head -n 5 | gum style --border normal
    fi
}

# Interactive search through history
search_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${NEON_YELLOW}No files in memory banks.${RESET}"
        exit 1
    fi
    
    echo -e "${NEON_BLUE}█▓▒░ SEARCH MEMORY BANKS ░▒▓█${RESET}"
    
    # Let user input search term
    local search_term
    search_term=$(gum input --placeholder "Enter search term")
    
    if [ -z "$search_term" ]; then
        echo -e "${NEON_YELLOW}Search cancelled.${RESET}"
        exit 1
    fi
    
    # Search in history file
    local results=()
    local count=0
    
    while IFS= read -r line; do
        if [[ "$line" == *"$search_term"* ]]; then
            results+=("$line")
            ((count++))
            
            # Limit results to the display count
            if [ "$count" -ge "$DISPLAY_COUNT" ]; then
                break
            fi
        fi
    done < "$HISTORY_FILE"
    
    # Display results
    if [ ${#results[@]} -eq 0 ]; then
        echo -e "${NEON_YELLOW}No matching files found.${RESET}"
        exit 1
    fi
    
    echo -e "${NEON_GREEN}Found ${#results[@]} matches:${RESET}"
    local selected_file
    selected_file=$(gum choose --height=10 "${results[@]}")
    
    if [ -n "$selected_file" ]; then
        copy_to_clipboard "$selected_file"
    else
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
        exit 1
    fi
}

# Search within file contents
search_file_contents() {
    echo -e "${NEON_BLUE}█▓▒░ DEEP CONTENT SCAN ░▒▓█${RESET}"
    
    # Let user input search term
    local search_term
    search_term=$(gum input --placeholder "Enter search term")
    
    if [ -z "$search_term" ]; then
        echo -e "${NEON_YELLOW}Search cancelled.${RESET}"
        exit 1
    fi
    
    # Let user specify search directory
    local search_dir
    search_dir=$(gum input --placeholder "Search directory (default: $HOME)" --value "$HOME")
    
    if [ -z "$search_dir" ]; then
        search_dir="$HOME"
    fi
    
    if [ ! -d "$search_dir" ]; then
        echo -e "${NEON_YELLOW}Directory not found.${RESET}"
        exit 1
    fi
    
    echo -e "${NEON_GREEN}Scanning files for content match...${RESET}"
    
    # Use ripgrep if available for faster search
    if command -v rg &> /dev/null; then
        local results=$(rg --max-count=1 --files-with-matches "$search_term" "$search_dir" 2>/dev/null | head -n "$DISPLAY_COUNT")
    else
        local results=$(grep -l -r "$search_term" "$search_dir" 2>/dev/null | head -n "$DISPLAY_COUNT")
    fi
    
    if [ -z "$results" ]; then
        echo -e "${NEON_YELLOW}No matching content found.${RESET}"
        exit 1
    fi
    
    # Convert results to array
    local result_array=()
    while IFS= read -r line; do
        result_array+=("$line")
    done <<< "$results"
    
    echo -e "${NEON_GREEN}Found ${#result_array[@]} files with matching content:${RESET}"
    local selected_file
    selected_file=$(gum choose --height=10 "${result_array[@]}")
    
    if [ -n "$selected_file" ]; then
        copy_to_clipboard "$selected_file"
    else
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
        exit 1
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
    
    # Check display count
    local max_display=$DISPLAY_COUNT
    if [ ${#history_entries[@]} -lt $max_display ]; then
        max_display=${#history_entries[@]}
    fi
    
    # Use gum to create rad interactive selection
    echo -e "${NEON_BLUE}█▓▒░ SELECT FILE TO UPLOAD ░▒▓█${RESET}"
    local selected_file
    selected_file=$(gum choose --height=10 "${history_entries[@]:0:$max_display}")
    
    if [ -n "$selected_file" ]; then
        copy_to_clipboard "$selected_file"
    else
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
        exit 1
    fi
}

# Directory browser mode
browse_directory() {
    local dir="${1:-$PWD}"
    
    if [ ! -d "$dir" ]; then
        echo -e "${NEON_YELLOW}Directory not found.${RESET}"
        exit 1
    fi
    
    echo -e "${NEON_BLUE}█▓▒░ DIRECTORY EXPLORER ░▒▓█${RESET}"
    echo -e "${NEON_GREEN}Current location:${RESET} $dir"
    
    # List files and directories
    local entries=(".." $(ls -1 "$dir"))
    local selected_entry
    selected_entry=$(gum choose --height=20 "${entries[@]}")
    
    if [ -z "$selected_entry" ]; then
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
        exit 1
    fi
    
    # Handle selection
    local selected_path="$dir/$selected_entry"
    selected_path=$(realpath "$selected_path")
    
    if [ -d "$selected_path" ]; then
        # If directory, browse into it
        browse_directory "$selected_path"
    elif [ -f "$selected_path" ]; then
        # If file, copy it
        copy_to_clipboard "$selected_path"
    else
        echo -e "${NEON_YELLOW}Invalid selection.${RESET}"
        exit 1
    fi
}

# Format converter
convert_format() {
    local file="$1"
    local target_format="$2"
    
    if [ ! -f "$file" ]; then
        echo -e "${NEON_YELLOW}ERROR: File not found.${RESET}"
        return 1
    fi
    
    echo -e "${NEON_BLUE}█▓▒░ FORMAT CONVERSION ░▒▓█${RESET}"
    
    # Get current format
    local current_format="${file##*.}"
    
    if [ -z "$target_format" ]; then
        echo -e "${NEON_GREEN}Available target formats:${RESET}"
        echo -e "- txt (plain text)"
        echo -e "- md (markdown)"
        echo -e "- html (HTML)"
        echo -e "- json (JSON)"
        echo -e "- csv (CSV)"
        
        target_format=$(gum choose "txt" "md" "html" "json" "csv")
    fi
    
    if [ -z "$target_format" ]; then
        echo -e "${NEON_YELLOW}Conversion cancelled.${RESET}"
        return 1
    fi
    
    # Create temp output file
    local output_file="$TMP_DIR/$(basename "$file" ".$current_format").$target_format"
    
    case "$current_format:$target_format" in
        "md:html")
            if command -v pandoc &> /dev/null; then
                pandoc -f markdown -t html "$file" -o "$output_file"
            else
                echo -e "${NEON_YELLOW}Pandoc required for this conversion.${RESET}"
                return 1
            fi
            ;;
        "html:md")
            if command -v pandoc &> /dev/null; then
                pandoc -f html -t markdown "$file" -o "$output_file"
            else
                echo -e "${NEON_YELLOW}Pandoc required for this conversion.${RESET}"
                return 1
            fi
            ;;
        "json:csv")
            if command -v jq &> /dev/null; then
                # Basic JSON to CSV conversion
                jq -r '.[] | [.] | @csv' "$file" > "$output_file"
            else
                echo -e "${NEON_YELLOW}jq required for this conversion.${RESET}"
                return 1
            fi
            ;;
        "csv:json")
            if command -v python3 &> /dev/null; then
                python3 -c "import csv, json, sys; data = list(csv.DictReader(open('$file'))); print(json.dumps(data, indent=2))" > "$output_file"
            else
                echo -e "${NEON_YELLOW}Python3 required for this conversion.${RESET}"
                return 1
            fi
            ;;
        *)
            # Basic text conversion
            cat "$file" > "$output_file"
            ;;
    esac
    
    if [ -f "$output_file" ]; then
        echo -e "${NEON_GREEN}Converted from .$current_format to .$target_format${RESET}"
        echo -e "${NEON_GREEN}Saved to:${RESET} $output_file"
        
        if gum confirm "Copy converted file to clipboard?"; then
            copy_to_clipboard "$output_file"
        fi
    else
        echo -e "${NEON_YELLOW}Conversion failed.${RESET}"
        return 1
    fi
}

# Multiple clipboard buffers
use_buffer() {
    local buffer="$1"
    
    if [ -z "$buffer" ]; then
        echo -e "${NEON_BLUE}█▓▒░ CLIPBOARD BUFFERS ░▒▓█${RESET}"
        echo -e "${NEON_GREEN}Current buffer:${RESET} $DEFAULT_BUFFER"
        
        buffer=$(gum input --placeholder "Enter buffer number (0-9)")
    fi
    
    if [[ ! "$buffer" =~ ^[0-9]$ ]]; then
        echo -e "${NEON_YELLOW}Invalid buffer number. Use 0-9.${RESET}"
        return 1
    fi
    
    # Update config
    sed -i "s/^default_buffer=.*/default_buffer=$buffer/" "$CONFIG_FILE"
    DEFAULT_BUFFER=$buffer
    
    echo -e "${NEON_GREEN}Switched to buffer ${DEFAULT_BUFFER}.${RESET}"
    
    # Show current buffer content
    local content=$(get_clipboard_content "$buffer")
    local preview="${content:0:100}"
    
    if [ -n "$content" ]; then
        echo -e "${NEON_BLUE}Current content (preview):${RESET}"
        echo "$preview" | gum style --padding "1"
        if [ ${#content} -gt 100 ]; then
            echo -e "${NEON_YELLOW}... ($(( ${#content} - 100 )) more characters)${RESET}"
        fi
    else
        echo -e "${NEON_YELLOW}Buffer is empty.${RESET}"
    fi
}

# Installer function
install_clip() {
    echo -e "${NEON_BLUE}█▓▒░ INSTALLING SYSTEM ░▒▓█${RESET}"
    
    # Copy script to bin directory
    mkdir -p "$SCRIPT_DIR"
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
    
    # Setup shell completion
    local completion_dir
    if [ -n "$ZSH_VERSION" ]; then
        completion_dir="$HOME/.zsh/completion"
        mkdir -p "$completion_dir"
        
        cat > "$completion_dir/_clip" << 'EOL'
#compdef clip
_clip() {
  local -a commands
  commands=(
    '--help:Show help'
    '--install:Install clip'
    '--uninstall:Uninstall clip'
    '--update:Update clip'
    '--version:Show version'
    '--config:Configure clip'
    '--history:View copy history'
    '--browse:Browse files'
    '--search:Search history'
    '--find:Search in file contents'
    '--buffer:Switch clipboard buffer'
    '--view:View clipboard content'
    '--paste:Paste clipboard content'
    '--convert:Convert file format'
    '-t:Copy text to clipboard'
    '-p:Preview file before copying'
    '-ps:Select line ranges'
  )
  
  _describe -t commands 'clip commands' commands
  _files
}

_clip
EOL
        
        echo "fpath=($completion_dir \$fpath)" >> "$HOME/.zshrc"
        echo "autoload -U compinit && compinit" >> "$HOME/.zshrc"
        echo -e "${NEON_GREEN}Added ZSH completion${RESET}"
    elif [ -n "$BASH_VERSION" ]; then
        completion_dir="$HOME/.bash_completion.d"
        mkdir -p "$completion_dir"
        
        cat > "$completion_dir/clip" << 'EOL'
_clip() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--help --install --uninstall --update --version --config --history --browse --search --find --buffer --view --paste --convert -t -p -ps"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    COMPREPLY=( $(compgen -f ${cur}) )
}
complete -F _clip clip
EOL
        
        echo "[ -d $completion_dir ] && for f in $completion_dir/*; do source \$f; done" >> "$HOME/.bashrc"
        echo -e "${NEON_GREEN}Added Bash completion${RESET}"
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
        
        # Remove completions
        local zsh_completion="$HOME/.zsh/completion/_clip"
        local bash_completion="$HOME/.bash_completion.d/clip"
        
        [ -f "$zsh_completion" ] && rm -f "$zsh_completion"
        [ -f "$bash_completion" ] && rm -f "$bash_completion"
        
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

# Copy line range from file
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

# View current clipboard content
view_clipboard() {
    local buffer="${1:-$DEFAULT_BUFFER}"
    
    echo -e "${NEON_BLUE}█▓▒░ CLIPBOARD VIEWER ░▒▓█${RESET}"
    
    local content=$(get_clipboard_content "$buffer")
    local decrypted_content=$(decrypt_content "$content")
    
    if [ -z "$decrypted_content" ]; then
        echo -e "${NEON_YELLOW}Clipboard is empty.${RESET}"
        return 1
    fi
    
    local lines=$(echo -n "$decrypted_content" | wc -l)
    local chars=$(echo -n "$decrypted_content" | wc -m)
    
    echo -e "${NEON_GREEN}Buffer:${RESET} $buffer"
    echo -e "${NEON_GREEN}Characters:${RESET} $chars"
    echo -e "${NEON_GREEN}Lines:${RESET} $lines"
    echo
    echo -e "${NEON_BLUE}Content:${RESET}"
    
    echo "$decrypted_content" | gum style --border normal --margin "1" --padding "1"
    
    # Offer to save to file
    if gum confirm "Save to file?"; then
        local filename
        echo -e "${NEON_GREEN}Enter filename:${RESET}"
        filename=$(gum input --placeholder "output.txt")
        
        if [ -n "$filename" ]; then
            echo "$decrypted_content" > "$filename"
            echo -e "${NEON_GREEN}Saved to:${RESET} $filename"
        else
            echo -e "${NEON_YELLOW}Save cancelled.${RESET}"
        fi
    fi
}

# Paste clipboard content to file
paste_clipboard() {
    local file="$1"
    local buffer="${2:-$DEFAULT_BUFFER}"
    
    if [ -z "$file" ]; then
        echo -e "${NEON_GREEN}Enter filename:${RESET}"
        file=$(gum input --placeholder "output.txt")
        
        if [ -z "$file" ]; then
            echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
            return 1
        fi
    fi
    
    # Check if file exists
    if [ -f "$file" ]; then
        if ! gum confirm "File exists. Overwrite?"; then
            if gum confirm "Append instead?"; then
                local mode="append"
            else
                echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
                return 1
            fi
        else
            local mode="overwrite"
        fi
    else
        local mode="create"
    fi
    
    # Get clipboard content
    local content=$(get_clipboard_content "$buffer")
    local decrypted_content=$(decrypt_content "$content")
    
    if [ -z "$decrypted_content" ]; then
        echo -e "${NEON_YELLOW}Clipboard is empty.${RESET}"
        return 1
    fi
    
    # Write to file
    if [ "$mode" = "append" ]; then
        echo "$decrypted_content" >> "$file"
    else
        echo "$decrypted_content" > "$file"
    fi
    
    echo -e "${NEON_GREEN}Clipboard content ${mode}d to:${RESET} $file"
}

# Configure settings
configure() {
    echo -e "${NEON_BLUE}█▓▒░ SYSTEM CONFIGURATION ░▒▓█${RESET}"
    
    local setting
    setting=$(gum choose "history_size" "display_count" "theme" "auto_clear" "notification" "compression" "encryption")
    
    if [ -z "$setting" ]; then
        echo -e "${NEON_YELLOW}Configuration cancelled.${RESET}"
        return 1
    fi
    
    local current_value
    current_value=$(grep "^$setting=" "$CONFIG_FILE" | cut -d= -f2)
    
    echo -e "${NEON_GREEN}Current value:${RESET} $current_value"
    
    case "$setting" in
        "history_size")
            local new_value
            new_value=$(gum input --placeholder "Enter new history size (1-999)" --value "$current_value")
            
            if [[ ! "$new_value" =~ ^[1-9][0-9]{0,2}$ ]]; then
                echo -e "${NEON_YELLOW}Invalid value. Must be 1-999.${RESET}"
                return 1
            fi
            ;;
        "display_count")
            local new_value
            new_value=$(gum input --placeholder "Enter new display count (1-99)" --value "$current_value")
            
            if [[ ! "$new_value" =~ ^[1-9][0-9]?$ ]]; then
                echo -e "${NEON_YELLOW}Invalid value. Must be 1-99.${RESET}"
                return 1
            fi
            ;;
        "theme")
            local new_value
            new_value=$(gum choose "synthwave" "matrix" "cyberpunk" "midnight")
            
            if [ -z "$new_value" ]; then
                echo -e "${NEON_YELLOW}Theme selection cancelled.${RESET}"
                return 1
            fi
            ;;
        "auto_clear"|"notification"|"compression"|"encryption")
            if [ "$current_value" = "true" ]; then
                new_value="false"
            else
                new_value="true"
            fi
            ;;
        *)
            echo -e "${NEON_YELLOW}Unknown setting.${RESET}"
            return 1
            ;;
    esac
    
    # Update config file
    sed -i "s/^$setting=.*/$setting=$new_value/" "$CONFIG_FILE"
    
    echo -e "${NEON_GREEN}Setting updated:${RESET} $setting = $new_value"
    echo -e "${NEON_YELLOW}Restart clip for changes to take effect.${RESET}"
}

# View history
view_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${NEON_YELLOW}No files in memory banks.${RESET}"
        exit 1
    fi
    
    echo -e "${NEON_BLUE}█▓▒░ MEMORY BANKS ░▒▓█${RESET}"
    cat "$HISTORY_FILE" | nl | head -n "$HISTORY_SIZE" | gum style --border normal --margin "1" --padding "1"
    
    echo -e "${NEON_GREEN}Displaying ${HISTORY_SIZE} most recent entries.${RESET}"
    
    # Offer to clear history
    if gum confirm "Clear history?"; then
        > "$HISTORY_FILE"
        echo -e "${NEON_GREEN}History cleared.${RESET}"
    fi
    
    exit 0
}

# Show statistics
show_stats() {
    echo -e "${NEON_BLUE}█▓▒░ SYSTEM STATISTICS ░▒▓█${RESET}"
    
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${NEON_YELLOW}No history data available.${RESET}"
        return 1
    fi
    
    local total_entries=$(wc -l < "$HISTORY_FILE")
    local unique_entries=$(sort "$HISTORY_FILE" | uniq | wc -l)
    
    local most_copied=$(sort "$HISTORY_FILE" | uniq -c | sort -nr | head -n 1)
    local most_copied_file=$(echo "$most_copied" | awk '{$1=""; print $0}' | xargs)
    local most_copied_count=$(echo "$most_copied" | awk '{print $1}')
    
    echo -e "${NEON_GREEN}Total copies:${RESET} $total_entries"
    echo -e "${NEON_GREEN}Unique files:${RESET} $unique_entries"
    
    if [ -n "$most_copied_file" ]; then
        echo -e "${NEON_GREEN}Most copied file:${RESET} $most_copied_file ($most_copied_count times)"
    fi
    
    # File type statistics
    echo -e "${NEON_BLUE}█▓▒░ FILE TYPE ANALYSIS ░▒▓█${RESET}"
    
    echo "Calculating..."
    local types=()
    local type_counts=()
    
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local ext="${file##*.}"
            
            if [ "$ext" = "$file" ]; then
                ext="no_extension"
            fi
            
            # Check if type already exists
            local found=false
            for i in "${!types[@]}"; do
                if [ "${types[$i]}" = "$ext" ]; then
                    type_counts[$i]=$((type_counts[$i] + 1))
                    found=true
                    break
                fi
            done
            
            # Add new type if not found
            if [ "$found" = false ]; then
                types+=("$ext")
                type_counts+=(1)
            fi
        fi
    done < "$HISTORY_FILE"
    
    # Display type statistics
    for i in "${!types[@]}"; do
        echo -e "${NEON_GREEN}${types[$i]}:${RESET} ${type_counts[$i]}"
    done
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
    echo -e "${NEON_GREEN}Search Commands:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} --search          Search through history"
    echo -e "  ${NEON_PINK}clip${RESET} --find            Search in file contents"
    echo -e "  ${NEON_PINK}clip${RESET} --browse [DIR]    Browse files in directory"
    echo
    echo -e "${NEON_GREEN}Clipboard Commands:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} --view            View clipboard content"
    echo -e "  ${NEON_PINK}clip${RESET} --paste [FILE]    Paste clipboard to file"
    echo -e "  ${NEON_PINK}clip${RESET} --buffer [NUM]    Switch clipboard buffer (0-9)"
    echo
    echo -e "${NEON_GREEN}Utility Commands:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} --convert [FILE]  Convert file format"
    echo -e "  ${NEON_PINK}clip${RESET} --history         View copy history"
    echo -e "  ${NEON_PINK}clip${RESET} --stats           Show usage statistics"
    echo -e "  ${NEON_PINK}clip${RESET} --config          Configure settings"
    echo
    echo -e "${NEON_GREEN}System Commands:${RESET}"
    echo -e "  ${NEON_PINK}clip${RESET} --install         Install to system"
    echo -e "  ${NEON_PINK}clip${RESET} --uninstall       Remove from system"
    echo -e "  ${NEON_PINK}clip${RESET} --update          Upgrade to latest version"
    echo -e "  ${NEON_PINK}clip${RESET} --version         Show version info"
    echo -e "  ${NEON_PINK}clip${RESET} --help            Show this help"
    echo
    echo -e "${NEON_BLUE}Created by Arash Abolhasani (@eraxe)${RESET}"
    exit 0
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
elif [ "$1" = "--search" ]; then
    search_history
elif [ "$1" = "--find" ]; then
    search_file_contents
elif [ "$1" = "--browse" ]; then
    browse_directory "$2"
elif [ "$1" = "--buffer" ]; then
    use_buffer "$2"
elif [ "$1" = "--view" ]; then
    view_clipboard "$2"
elif [ "$1" = "--paste" ]; then
    paste_clipboard "$2"
elif [ "$1" = "--convert" ]; then
    convert_format "$2" "$3"
elif [ "$1" = "--config" ]; then
    configure
elif [ "$1" = "--stats" ]; then
    show_stats
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
