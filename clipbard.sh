#!/bin/bash
#
# ╔═╗╦  ╦╔═╗╔╗ ╔═╗╦═╗╔╦╗
# ║  ║  ║╠═╝╠╩╗╠═╣╠╦╝ ║║
# ╚═╝╩═╝╩╩  ╚═╝╩ ╩╩╚══╩╝
#
# A  R A D I C A L  clipboard utility
# by Arash Abolhasani (@eraxe)

VERSION="1.1.0"
NEON_PINK='\e[38;5;213m'
NEON_BLUE='\e[38;5;51m'
NEON_GREEN='\e[38;5;82m'
NEON_YELLOW='\e[38;5;226m'
NEON_PURPLE='\e[38;5;171m'
NEON_ORANGE='\e[38;5;214m'
NEON_CYAN='\e[38;5;51m'
NEON_WHITE='\e[38;5;255m'
RESET='\e[0m'

# Default configuration
CONFIG_DIR="$HOME/.config/clipbard"
HISTORY_FILE="$CONFIG_DIR/history"
CONFIG_FILE="$CONFIG_DIR/config.ini"
SCRIPT_DIR="$HOME/.local/bin"
SCRIPT_PATH="$SCRIPT_DIR/clipbard"
GITHUB_REPO="https://github.com/eraxe/clipbard"
DEFAULT_HISTORY_SIZE=50
DEFAULT_DISPLAY_COUNT=5
DEFAULT_THEME="synthwave"
DEFAULT_CLIPBOARD_BUFFER=0
DEFAULT_MAX_FILE_SIZE=10 # In MB
DEFAULT_PREFERRED_HISTORY="auto" # Options: auto, bash, zsh
DEFAULT_VERBOSE_LOGGING="false"
TMP_DIR="/tmp/clipbard-tmp"

# List of recognizable file extensions
FILE_EXTENSIONS=(
    # Programming
    "py" "js" "html" "css" "php" "java" "cpp" "c" "h" "hpp" "cs" "go" "rb" "pl" "swift" "kt" "rs" "ts" "sh" "bash" "zsh" "sql" "r" "m" "scala" "lua" "groovy" "dart" "elm" "clj" "ex" "erl" "fs" "f90" "hs" "jl" "lisp" "ml" "nim" "pas" "ps1" "rkt" "sol" "tcl" "v" "vhdl" "asm" "s" "wasm"
    # Markup/Data
    "json" "xml" "yaml" "yml" "toml" "ini" "csv" "tsv" "md" "markdown" "rst" "tex" "bib" "svg" "graphql" "plist" "properties"
    # Documents
    "txt" "doc" "docx" "rtf" "odt" "pdf" "xls" "xlsx" "ods" "ppt" "pptx" "odp" "pages" "key" "numbers"
    # Web
    "htm" "xhtml" "jsp" "asp" "aspx" "cshtml" "php" "phtml" "cgi" "cfm" "erb" "hbs" "twig" "mustache" "vue" "jsx" "tsx"
    # Config/System
    "conf" "config" "cfg" "gitignore" "gitattributes" "env" "lock" "log" "pid" "service" "socket" "desktop" "automount" "mount" "target" "path" "device" "link" "netdev" "network" "slice" "swap" "timer"
    # Media (text-based)
    "srt" "vtt" "ass" "lrc" "sbv"
    # Development
    "Makefile" "dockerfile" "vagrantfile" "jenkinsfile" "gruntfile" "gulpfile" "webpack" "docker-compose" "cmake" "rakefile" "build" 
    # Specialized formats
    "proto" "avsc" "thrift" "idl" "wsdl" "raml" "openapi" "plantuml" "dot" "gv" "edn" "nix" "tf" "tfvars" "hcl"
    # Shell/ZSH related
    "zshrc" "zprofile" "zlogin" "zlogout" "zshenv" "zimrc" "zpreztorc" "bashrc" "bash_profile" "profile" "kshrc" "shrc"
)

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$TMP_DIR"
touch "$HISTORY_FILE"

# Signal handling for graceful cancellation
handle_interrupt() {
    echo -e "\n${NEON_YELLOW}Operation cancelled by user.${RESET}"
    cleanup_temp_files
    exit 1
}

# Set up interrupt handling
trap handle_interrupt INT TERM

# Cleanup any temporary files
cleanup_temp_files() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"/*
    fi
}

# Create default config if doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOL
# CLIPBARD Configuration File

# General Settings
history_size=$DEFAULT_HISTORY_SIZE
display_count=$DEFAULT_DISPLAY_COUNT
theme=$DEFAULT_THEME
verbose_logging=$DEFAULT_VERBOSE_LOGGING

# Clipboard Settings
auto_clear=false
default_buffer=$DEFAULT_CLIPBOARD_BUFFER
max_file_size=$DEFAULT_MAX_FILE_SIZE

# Security Settings
notification=true
compression=false
encryption=false

# History Settings
shell_history_scan=true
prefer_local_history=true
preferred_history=$DEFAULT_PREFERRED_HISTORY
EOL
fi

# Log function that respects verbose setting
log_info() {
    local message="$1"
    local force="${2:-false}"
    
    if [ "$VERBOSE_LOGGING" = "true" ] || [ "$force" = "true" ]; then
        echo -e "$message"
    fi
}

# Error logging function - always shows regardless of verbose setting
log_error() {
    local message="$1"
    echo -e "${NEON_YELLOW}$message${RESET}"
}

# Success logging function - always shows regardless of verbose setting
log_success() {
    local message="$1"
    echo -e "${NEON_GREEN}$message${RESET}"
}

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
        SHELL_HISTORY_SCAN=$(grep "^shell_history_scan=" "$CONFIG_FILE" | cut -d= -f2 || echo "true")
        MAX_FILE_SIZE=$(grep "^max_file_size=" "$CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_MAX_FILE_SIZE")
        PREFER_LOCAL_HISTORY=$(grep "^prefer_local_history=" "$CONFIG_FILE" | cut -d= -f2 || echo "true")
        PREFERRED_HISTORY=$(grep "^preferred_history=" "$CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_PREFERRED_HISTORY")
        VERBOSE_LOGGING=$(grep "^verbose_logging=" "$CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_VERBOSE_LOGGING")
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
        SHELL_HISTORY_SCAN="true"
        MAX_FILE_SIZE=$DEFAULT_MAX_FILE_SIZE
        PREFER_LOCAL_HISTORY="true"
        PREFERRED_HISTORY=$DEFAULT_PREFERRED_HISTORY
        VERBOSE_LOGGING=$DEFAULT_VERBOSE_LOGGING
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
            NEON_CYAN='\e[38;5;51m'
            NEON_WHITE='\e[38;5;255m'
            ;;
        "cyberpunk")
            NEON_PINK='\e[38;5;201m'
            NEON_BLUE='\e[38;5;45m'
            NEON_GREEN='\e[38;5;226m'
            NEON_YELLOW='\e[38;5;214m'
            NEON_PURPLE='\e[38;5;201m'
            NEON_ORANGE='\e[38;5;208m'
            NEON_CYAN='\e[38;5;51m'
            NEON_WHITE='\e[38;5;255m'
            ;;
        "midnight")
            NEON_PINK='\e[38;5;61m'
            NEON_BLUE='\e[38;5;63m'
            NEON_GREEN='\e[38;5;37m'
            NEON_YELLOW='\e[38;5;109m'
            NEON_PURPLE='\e[38;5;61m'
            NEON_ORANGE='\e[38;5;67m'
            NEON_CYAN='\e[38;5;51m'
            NEON_WHITE='\e[38;5;255m'
            ;;
        *)
            # Default synthwave theme colors are already set
            ;;
    esac
}

apply_theme

print_synthwave_art(){
  local mode="${1:-install}"
  # ANSI palettes using $'…'
  local RESET=$'\033[0m'
  # neon
  local NEON_GREEN=$'\033[38;5;118m'
  local NEON_YELLOW=$'\033[38;5;226m'
  local NEON_BLUE=$'\033[38;5;33m'
  local NEON_MAGENTA=$'\033[38;5;201m'
  local NEON_PURPLE=$'\033[38;5;141m'
  local NEON_CYAN=$'\033[38;5;51m'
  local NEON_WHITE=$'\033[38;5;255m'
  # sunset
  local SUN_ORANGE=$'\033[38;5;208m'
  local SUN_PINK=$'\033[38;5;205m'
  local SUN_MAGENTA=$'\033[38;5;199m'
  local SUN_PURPLE=$'\033[38;5;135m'
  local SUN_DEEP_PURP=$'\033[38;5;093m'
  local SUN_BLUE=$'\033[38;5;039m'
  # mode header + action color
  local HEADER ACTION
  case "$mode" in
    install)
      HEADER="${NEON_GREEN}▓▒░ INSTALLING SYSTEM ░▒▓${RESET}"
      ACTION="$NEON_GREEN";;
    uninstall)
      HEADER="${NEON_BLUE}▓▒░ REMOVAL UTILITY ░▒▓${RESET}"
      ACTION="$NEON_YELLOW";;
    update)
      HEADER="${NEON_BLUE}▓▒░ SYSTEM UPGRADE ░▒▓${RESET}"
      ACTION="$NEON_PURPLE";;
    *)
      HEADER="${NEON_MAGENTA}▓▒░ SYNTHWAVE ░▒▓${RESET}"
      ACTION="$NEON_MAGENTA";;
  esac
  echo
  printf '%b\n\n' "$HEADER"

  # Define color function to create synthwave gradient effect
  logo_line() {
    local line=$1
    echo -e "${SUN_PINK}${line:0:10}${SUN_MAGENTA}${line:10:10}${SUN_PURPLE}${line:20:10}${SUN_DEEP_PURP}${line:30:10}${SUN_BLUE}${line:40:10}${NEON_BLUE}${line:50:10}${NEON_PURPLE}${line:60:10}${NEON_MAGENTA}${line:70}${RESET}"
  }
  
  # ClipBard Synthwave Logo
  logo_line "  ██████╗██╗     ██╗██████╗ ██████╗  █████╗ ██████╗ ██████╗  "
  logo_line " ██╔════╝██║     ██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗ "
  logo_line " ██║     ██║     ██║██████╔╝██████╔╝███████║██████╔╝██║  ██║ "
  logo_line " ██║     ██║     ██║██╔═══╝ ██╔══██╗██╔══██║██╔══██╗██║  ██║ "
  logo_line " ╚██████╗███████╗██║██║     ██████╔╝██║  ██║██║  ██║██████╔╝ "
  logo_line "  ╚═════╝╚══════╝╚═╝╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  "
  # Grid lines bottom (perspective)
  echo -e "${NEON_BLUE}           /________|_______\\           ${RESET}"
  echo -e "${NEON_BLUE}          /________|________\\          ${RESET}"
  echo -e "${NEON_BLUE}         /_________|_________\\         ${RESET}"
  echo -e "${NEON_BLUE}        /__________|__________\\        ${RESET}"
  echo -e "${NEON_BLUE}       /___________|___________\\       ${RESET}"
  echo -e "${NEON_BLUE}      //___________|___________\\\\      ${RESET}"
  echo -e "${NEON_BLUE}     //           |           \\\\     ${RESET}"
  echo -e "${NEON_BLUE}    //            |            \\\\    ${RESET}"
  
  
  echo
  echo -e "${ACTION}  >>> $mode ClipBard ${RESET}"
  echo
}

# Print banner
print_banner() {
    echo -e "${NEON_BLUE}"
    echo -e "╔═╗╦  ╦╔═╗╔╗ ╔═╗╦═╗╔╦╗"
    echo -e "║  ║  ║╠═╝╠╩╗╠═╣╠╦╝ ║║"
    echo -e "╚═╝╩═╝╩╩  ╚═╝╩ ╩╩╚══╩╝"
    echo -e "${NEON_CYAN}v${VERSION} - Radical Clipboard Utility${RESET}"
    echo
}

# Check if a string is a command
is_command() {
    local cmd="$1"
    local commands=("help" "install" "uninstall" "update" "version" "config" "history" "browse" "search" "find" "buffer" "view" "paste" "convert" "t" "p" "ps" "stats" "h" "i" "u" "v" "c" "b" "s" "f")
    
    for c in "${commands[@]}"; do
        if [ "$cmd" = "$c" ]; then
            return 0
        fi
    done
    
    return 1
}

# Extract file paths from shell history - only looks at terminal history, not app's history
extract_files_from_history() {
    local history_size="${1:-50}"
    local display_count="${2:-5}"
    local files=()
    
    log_info "${NEON_BLUE}█▓▒░ SCANNING SHELL HISTORY ░▒▓█${RESET}" "true"
    
    # Array to store history sources
    local history_sources=()
    
    # Check which shell we're running in
    local current_shell=""
    
    # Determine current shell and preferred history
    if [ "$PREFERRED_HISTORY" = "auto" ]; then
        if [ -n "$ZSH_VERSION" ]; then
            current_shell="zsh"
        elif [ -n "$BASH_VERSION" ]; then
            current_shell="bash"
        else
            current_shell="unknown"
        fi
    else
        current_shell="$PREFERRED_HISTORY"
    fi
    
    log_info "${NEON_GREEN}Using $current_shell shell history${RESET}"
    
    case "$current_shell" in
        "zsh")
            # Get the current history file from ZSH
            if [ -n "$HISTFILE" ] && [ -f "$HISTFILE" ]; then
                log_info "${NEON_GREEN}Found HISTFILE: ${RESET}$HISTFILE"
                history_sources+=("$HISTFILE")
            fi
            
            # Check for per-directory-history plugin (jimhester/per-directory-history)
            local per_dir_hist_base="$HOME/.zsh_history_dirs"
            
            if [ -d "$per_dir_hist_base" ]; then
                log_info "${NEON_GREEN}Detected per-directory-history directory${RESET}"
                
                # Generate directory hash the same way the plugin does
                local current_dir_hash=$(echo "$PWD" | md5sum | cut -d' ' -f1)
                local per_dir_hist_file="$per_dir_hist_base/$current_dir_hash"
                
                if [ -f "$per_dir_hist_file" ]; then
                    log_info "${NEON_GREEN}Found per-directory history: ${RESET}$per_dir_hist_file"
                    
                    # If we prefer local history, add it first
                    if [ "$PREFER_LOCAL_HISTORY" = "true" ]; then
                        history_sources=("$per_dir_hist_file" "${history_sources[@]}")
                    else
                        history_sources+=("$per_dir_hist_file")
                    fi
                fi
            fi
            
            # Add global ZSH history as fallback
            if [ -f "$HOME/.zsh_history" ] && [[ ! " ${history_sources[@]} " =~ " $HOME/.zsh_history " ]]; then
                log_info "${NEON_GREEN}Found global ZSH history: ${RESET}$HOME/.zsh_history"
                history_sources+=("$HOME/.zsh_history")
            fi
            ;;
        "bash")
            # Bash history
            if [ -n "$HISTFILE" ] && [ -f "$HISTFILE" ]; then
                log_info "${NEON_GREEN}Found HISTFILE: ${RESET}$HISTFILE"
                history_sources+=("$HISTFILE")
            fi
            
            if [ -f "$HOME/.bash_history" ] && [[ ! " ${history_sources[@]} " =~ " $HOME/.bash_history " ]]; then
                log_info "${NEON_GREEN}Found bash history: ${RESET}$HOME/.bash_history"
                history_sources+=("$HOME/.bash_history")
            fi
            ;;
        *)
            log_info "${NEON_YELLOW}Unknown shell, using history command directly${RESET}" "true"
            ;;
    esac
    
    # Temporary file to store potential file paths
    local tmp_files=$(mktemp)
    log_info "${NEON_GREEN}Temp file for paths: ${RESET}$tmp_files"
    
    # If we have history sources, process them
    if [ ${#history_sources[@]} -gt 0 ]; then
        for source in "${history_sources[@]}"; do
            log_info "${NEON_GREEN}Processing history file: ${RESET}$source"
            
            # Try different extraction methods for ZSH history
            if [[ "$source" == *".zsh_history"* || "$source" == *"zsh_history_dirs"* ]]; then
                # ZSH extended history format has timestamps and other metadata
                # Extract anything that looks like a file path with or without command
                grep -o '[[:alnum:][:punct:]]\+/[[:alnum:][:punct:]]\+' "$source" 2>/dev/null | \
                    grep -v '\(cd\|rm\|rmdir\|mkdir\|chmod\|chown\) ' | \
                    grep -v ' \-[[:alnum:]]\+' >> "$tmp_files"
                
                # Also try to catch common command patterns
                grep -E '(cat|nano|vim|vi|emacs|less|more|head|tail|grep|awk|sed) [^ ]+' "$source" 2>/dev/null | \
                    awk '{print $2}' | grep -v '\-' >> "$tmp_files"
                
                # Try to extract files with extensions
                grep -o '[[:alnum:][:punct:]]\+\.[[:alnum:]]\+' "$source" 2>/dev/null | \
                    grep -v '\.[0-9]\+:' >> "$tmp_files"
            else
                # Standard history format
                grep -o '/[a-zA-Z0-9._/-]\+' "$source" 2>/dev/null >> "$tmp_files"
                grep -o '[a-zA-Z0-9._/-]\+\.[a-zA-Z0-9]\+' "$source" 2>/dev/null | \
                    grep -v '^[0-9]\+' >> "$tmp_files"
            fi
        done
    else
        # Fallback to the history command output
        log_info "${NEON_GREEN}No history files found, using history command${RESET}" "true"
        
        # Use history command and extract potential paths with different patterns
        history | tail -n "$history_size" | grep -o '/[a-zA-Z0-9._/-]\+' >> "$tmp_files"
        history | tail -n "$history_size" | grep -o '[a-zA-Z0-9._/-]\+\.[a-zA-Z0-9]\+' | grep -v '^[0-9]\+' >> "$tmp_files"
        
        # Try to catch files used with common commands
        history | tail -n "$history_size" | grep -E '(cat|nano|vim|vi|emacs|less|more|head|tail|grep|awk|sed) [^ ]+' | \
            awk '{print $2}' | grep -v '\-' >> "$tmp_files"
    fi
    
    # Debug: show what was found
    if [ "$VERBOSE_LOGGING" = "true" ]; then
        log_info "${NEON_GREEN}Raw file candidates found:${RESET}"
        if [ -s "$tmp_files" ]; then
            head -n 20 "$tmp_files"
            log_info "${NEON_YELLOW}(showing first 20 entries)${RESET}"
        else
            log_info "${NEON_YELLOW}No raw candidates found${RESET}"
        fi
    fi
    
    # Filter only existing files and directories
    local count=0
    local unique_files=()
    
    # For debugging
    log_info "${NEON_GREEN}Starting filtering process on candidates...${RESET}"
    
    # Sort and get unique entries
    sort "$tmp_files" 2>/dev/null | uniq > "${tmp_files}.sorted" 2>/dev/null
    mv "${tmp_files}.sorted" "$tmp_files" 2>/dev/null
    
    while IFS= read -r file; do
        # Remove leading/trailing whitespace
        file=$(echo "$file" | xargs 2>/dev/null)
        
        # Skip if empty
        [ -z "$file" ] && continue
        
        # Skip common patterns that aren't likely to be files
        if [[ "$file" == *.git* ]] || [[ "$file" == *"*"* ]] || [[ "$file" == *"?"* ]]; then
            continue
        fi
        
        # Handle home directory shorthand
        if [[ "$file" == \~* ]]; then
            file="${file/#\~/$HOME}"
        fi
        
        # Handle relative paths
        if [[ "$file" != /* ]]; then
            # If it doesn't start with '/', assume it's relative to current directory
            file="$PWD/$file"
        fi
        
        # Debug: show file being checked
        log_info "Checking: $file"
        
        # Check if file exists and has a recognized extension
        if [ -f "$file" ]; then
            local ext="${file##*.}"
            local is_recognized_ext=false
            
            # Check if file has no extension
            if [ "$ext" = "$file" ]; then
                # Try to determine if it's a text file
                if file "$file" 2>/dev/null | grep -q "text"; then
                    is_recognized_ext=true
                fi
            else
                # Check against recognized extensions (case insensitive)
                for valid_ext in "${FILE_EXTENSIONS[@]}"; do
                    if [[ "${ext,,}" == "${valid_ext,,}" ]]; then
                        is_recognized_ext=true
                        break
                    fi
                done
            fi
            
            # Add file if it has recognizable content
            if [ "$is_recognized_ext" = true ] || file "$file" 2>/dev/null | grep -q "text\|json\|xml\|script\|program\|source\|document"; then
                # Check if already in list (avoid duplicates)
                if ! echo "${unique_files[@]}" | grep -q "$file"; then
                    log_info "${NEON_GREEN}Found valid file:${RESET} $file"
                    unique_files+=("$file")
                    count=$((count + 1))
                    
                    # Break if we have enough files
                    if [ "$count" -ge "$display_count" ]; then
                        break
                    fi
                fi
            else
                log_info "${NEON_YELLOW}File exists but unrecognized type:${RESET} $file"
            fi
        elif [ "$VERBOSE_LOGGING" = "true" ] && [[ "$file" == *"."* ]]; then
            log_info "${NEON_YELLOW}File not found:${RESET} $file"
        fi
    done < "$tmp_files"
    
    # Clean up
    rm -f "$tmp_files"
    
    # If no files found, try to be more flexible with the matching
    if [ ${#unique_files[@]} -eq 0 ]; then
        log_info "${NEON_YELLOW}No valid files found in history, trying direct command history...${RESET}"
        
        # Try a more direct approach - look for commands that typically operate on files
        local tmp_cmds=$(mktemp)
        history 2>/dev/null | grep -E '(cat|nano|vim|vi|emacs|less|more|head|tail|grep) [^ "]+' 2>/dev/null | \
            tail -n 50 | awk 'BEGIN{FPAT="([^ ]+)|(\"[^\"]+\")"} {for(i=2;i<=NF;i++) if($i !~ /^-/) print $i}' > "$tmp_cmds" 2>/dev/null
        
        while IFS= read -r file; do
            file=$(echo "$file" | xargs 2>/dev/null)
            [ -z "$file" ] && continue
            
            # Skip options and other non-file arguments
            [[ "$file" == -* ]] && continue
            
            # Handle home directory shorthand
            if [[ "$file" == \~* ]]; then
                file="${file/#\~/$HOME}"
            fi
            
            # Convert relative path to absolute
            if [[ "$file" != /* ]]; then
                file="$PWD/$file"
            fi
            
            if [ -f "$file" ] && ! echo "${unique_files[@]}" | grep -q "$file"; then
                log_info "${NEON_GREEN}Found file from command history:${RESET} $file"
                unique_files+=("$file")
                count=$((count + 1))
                
                if [ "$count" -ge "$display_count" ]; then
                    break
                fi
            fi
        done < "$tmp_cmds"
        
        rm -f "$tmp_cmds"
    fi
    
    # If still no files found, check the current directory
    if [ ${#unique_files[@]} -eq 0 ]; then
        log_info "${NEON_YELLOW}No files found in history. Showing files in current directory.${RESET}"
        
        # Find files in current directory with recognized extensions
        for file in "$PWD"/*; do
            if [ -f "$file" ]; then
                local ext="${file##*.}"
                local is_recognized=false
                
                if [ "$ext" = "$file" ]; then
                    # No extension, check if it's text
                    if file "$file" 2>/dev/null | grep -q "text"; then
                        is_recognized=true
                    fi
                else
                    # Check against recognized extensions
                    for valid_ext in "${FILE_EXTENSIONS[@]}"; do
                        if [[ "${ext,,}" == "${valid_ext,,}" ]]; then
                            is_recognized=true
                            break
                        fi
                    done
                fi
                
                if [ "$is_recognized" = true ] && ! echo "${unique_files[@]}" | grep -q "$file"; then
                    unique_files+=("$file")
                    count=$((count + 1))
                    
                    if [ "$count" -ge "$display_count" ]; then
                        break
                    fi
                fi
            fi
        done
    fi
    
    # If no files found, return empty
    if [ ${#unique_files[@]} -eq 0 ]; then
        log_error "No valid files found. Try browsing with 'clipbard browse'."
        return 1
    fi
    
    # Use gum to create rad interactive selection
    log_success "Found ${#unique_files[@]} files in history"
    local selected_file
    
    # Use White color for menu items
    export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
    
    selected_file=$(gum choose --height=10 "${unique_files[@]}")
    
    if [ -n "$selected_file" ]; then
        # Add to clipbard history
        local tmp_file=$(mktemp)
        echo "$selected_file" > "$tmp_file"
        grep -v "^$selected_file$" "$HISTORY_FILE" 2>/dev/null | head -n $(($HISTORY_SIZE-1)) >> "$tmp_file"
        mv "$tmp_file" "$HISTORY_FILE"
        
        # Copy to clipboard
        copy_to_clipboard "$selected_file"
    else
        log_error "Operation cancelled."
        exit 1
    fi
}

# Show notification (if enabled)
show_notification() {
    local title="$1"
    local message="$2"
    
    if [ "$NOTIFICATION" = "true" ] && command -v notify-send &> /dev/null; then
        notify-send -a "CLIPBARD" "$title" "$message"
    fi
}

# Encrypt content
encrypt_content() {
    local content="$1"
    local passphrase
    
    if [ "$ENCRYPTION" = "true" ]; then
        if command -v openssl &> /dev/null; then
            log_info "${NEON_YELLOW}Enter encryption passphrase:${RESET}" "true"
            passphrase=$(gum input --password)
            
            if [ -n "$passphrase" ]; then
                local encrypted=$(echo "$content" | openssl enc -aes-256-cbc -a -salt -pass pass:"$passphrase" 2>/dev/null)
                echo "$encrypted"
                return 0
            fi
        else
            log_info "${NEON_YELLOW}OpenSSL not found, encryption disabled.${RESET}" "true"
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
            log_info "${NEON_YELLOW}Enter decryption passphrase:${RESET}" "true"
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
                log_info "${NEON_GREEN}File compressed for clipboard.${RESET}"
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
        log_info "${NEON_YELLOW}⚡ SYSTEM INCOMPATIBILITY DETECTED ⚡${RESET}" "true"
        log_info "Missing dependencies: ${missing_deps[*]}" "true"
        
        if command -v pacman &> /dev/null; then
            log_info "${NEON_GREEN}Detected Arch-based system.${RESET}" "true"
            if gum confirm "Install missing components?"; then
                sudo pacman -S "${missing_deps[@]}"
            else
                log_info "${NEON_YELLOW}Installation aborted. System remains unconfigured.${RESET}" "true"
                exit 1
            fi
        elif command -v apt &> /dev/null; then
            log_info "${NEON_GREEN}Detected Debian/Ubuntu-based system.${RESET}" "true"
            if gum confirm "Install missing components?"; then
                sudo apt update && sudo apt install -y "${missing_deps[@]}"
            else
                log_info "${NEON_YELLOW}Installation aborted. System remains unconfigured.${RESET}" "true"
                exit 1
            fi
        else
            log_info "${NEON_YELLOW}Please install the dependencies manually.${RESET}" "true"
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
        log_info "${NEON_YELLOW}ERROR: File '$file' not found in the system.${RESET}" "true"
        return 1
    fi
    
    # Check file size against max_file_size
    local file_size_kb=$(du -k "$file" | cut -f1)
    local file_size_mb=$(echo "scale=2; $file_size_kb/1024" | bc)
    local max_size_mb=$MAX_FILE_SIZE
    
    if (( $(echo "$file_size_mb > $max_size_mb" | bc -l) )); then
        log_info "${NEON_YELLOW}WARNING: File size ($file_size_mb MB) exceeds maximum size limit ($max_size_mb MB).${RESET}" "true"
        if ! gum confirm "Do you want to copy this large file anyway?"; then
            log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
            return 1
        fi
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
        log_info "${NEON_YELLOW}ERROR: No clipboard utility detected.${RESET}" "true"
        return 1
    fi
    
    # Auto-clear previous clipboard if enabled
    if [ "$AUTO_CLEAR" = "true" ]; then
        log_info "Auto-clearing previous clipboard in 60 seconds..."
        (sleep 60 && echo -n "" | clipboard_copy) &
    fi
    
    # Update history - add to beginning, maintain uniqueness
    local tmp_file=$(mktemp)
    echo "$file" > "$tmp_file"
    grep -v "^$file$" "$HISTORY_FILE" | head -n $(($HISTORY_SIZE-1)) >> "$tmp_file"
    mv "$tmp_file" "$HISTORY_FILE"
    
    # Display cool-looking success message
    log_info "${NEON_GREEN}█▓▒░ TRANSFER COMPLETE ░▒▓█${RESET}" "true"
    log_info "${NEON_BLUE}File:${RESET} $(basename "$file")" "true"
    log_info "${NEON_BLUE}Size:${RESET} $size" "true"
    log_info "${NEON_BLUE}Path:${RESET} $file" "true"
    log_info "${NEON_BLUE}Type:${RESET} $(file -b "$file" | cut -d, -f1)" "true"
    echo -e "${NEON_GREEN}Copied to memory buffer ${buffer}!${RESET}"
    
    # Send notification
    show_notification "CLIPBARD" "Copied: $(basename "$file")"
    
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
        log_info "${NEON_YELLOW}ERROR: No clipboard utility detected.${RESET}" "true"
        return 1
    fi
    
    # Auto-clear if enabled
    if [ "$AUTO_CLEAR" = "true" ]; then
        log_info "Auto-clearing clipboard in 60 seconds..."
        (sleep 60 && echo -n "" | clipboard_copy) &
    fi
    
    show_notification "CLIPBARD" "Text copied to clipboard"
    echo -e "${NEON_GREEN}Text loaded into memory buffer ${buffer}!${RESET}"
}

# Function to show file preview
preview_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_info "${NEON_YELLOW}ERROR: File not found.${RESET}" "true"
        return 1
    fi
    
    local lines=$(wc -l < "$file" 2>/dev/null || echo "N/A")
    local size=$(du -h "$file" | cut -f1)
    local type=$(file -b "$file")
    local modified=$(stat -c '%y' "$file" 2>/dev/null || echo "N/A")
    
    log_info "${NEON_BLUE}█▓▒░ FILE ANALYSIS ░▒▓█${RESET}" "true"
    log_info "${NEON_GREEN}Filename:${RESET} $(basename "$file")" "true"
    log_info "${NEON_GREEN}Size:${RESET} $size" "true"
    log_info "${NEON_GREEN}Lines:${RESET} $lines" "true"
    log_info "${NEON_GREEN}Type:${RESET} $type" "true"
    log_info "${NEON_GREEN}Modified:${RESET} $modified" "true"
    
    if [[ "$type" == *"text"* ]]; then
        log_info "${NEON_BLUE}█▓▒░ FILE PREVIEW ░▒▓█${RESET}" "true"
        head -n 10 "$file" | gum style --border normal --margin "1" --padding "1"
        
        if [ "$lines" != "N/A" ] && [ "$lines" -gt 10 ]; then
            log_info "${NEON_YELLOW}... ($(($lines - 10)) more lines)${RESET}" "true"
        fi
    elif [[ "$type" == *"image"* ]]; then
        log_info "${NEON_PURPLE}[Image File]${RESET}" "true"
        
        # Try to use image preview if available
        if command -v chafa &> /dev/null; then
            chafa --size=40x20 "$file"
        else
            log_info "${NEON_YELLOW}Install 'chafa' for terminal image previews${RESET}" "true"
        fi
    else
        log_info "${NEON_YELLOW}Binary file - preview unavailable${RESET}" "true"
        hexdump -C "$file" | head -n 5 | gum style --border normal
    fi
}

# Interactive search through history - explicitly searches app history
search_app_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        log_info "${NEON_YELLOW}No files in memory banks.${RESET}" "true"
        exit 1
    fi
    
    log_info "${NEON_BLUE}█▓▒░ SEARCH APP MEMORY BANKS ░▒▓█${RESET}" "true"
    
    # Let user input search term
    local search_term
    search_term=$(gum input --placeholder "Enter search term")
    
    if [ -z "$search_term" ]; then
        log_info "${NEON_YELLOW}Search cancelled.${RESET}" "true"
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
        log_info "${NEON_YELLOW}No matching files found.${RESET}" "true"
        exit 1
    fi
    
    log_info "${NEON_GREEN}Found ${#results[@]} matches:${RESET}" "true"
    
    # Configure gum styles for menu items
    export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
    
    local selected_file
    selected_file=$(gum choose --height=10 "${results[@]}")
    
    if [ -n "$selected_file" ]; then
        copy_to_clipboard "$selected_file"
    else
        log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
        exit 1
    fi
}

# Search within file contents
search_file_contents() {
    log_info "${NEON_BLUE}█▓▒░ DEEP CONTENT SCAN ░▒▓█${RESET}" "true"
    
    # Let user input search term
    local search_term
    search_term=$(gum input --placeholder "Enter search term")
    
    if [ -z "$search_term" ]; then
        log_info "${NEON_YELLOW}Search cancelled.${RESET}" "true"
        exit 1
    fi
    
    # Let user specify search directory
    local search_dir
    search_dir=$(gum input --placeholder "Search directory (default: $HOME)" --value "$HOME")
    
    if [ -z "$search_dir" ]; then
        search_dir="$HOME"
    fi
    
    if [ ! -d "$search_dir" ]; then
        log_info "${NEON_YELLOW}Directory not found.${RESET}" "true"
        exit 1
    fi
    
    log_info "${NEON_GREEN}Scanning files for content match...${RESET}" "true"
    
    # Use ripgrep if available for faster search
    if command -v rg &> /dev/null; then
        local results=$(rg --max-count=1 --files-with-matches "$search_term" "$search_dir" 2>/dev/null | head -n "$DISPLAY_COUNT")
    else
        local results=$(grep -l -r "$search_term" "$search_dir" 2>/dev/null | head -n "$DISPLAY_COUNT")
    fi
    
    if [ -z "$results" ]; then
        log_info "${NEON_YELLOW}No matching content found.${RESET}" "true"
        exit 1
    fi
    
    # Convert results to array
    local result_array=()
    while IFS= read -r line; do
        result_array+=("$line")
    done <<< "$results"
    
    log_info "${NEON_GREEN}Found ${#result_array[@]} files with matching content:${RESET}" "true"
    
    # Configure gum styles for menu items
    export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
    
    local selected_file
    selected_file=$(gum choose --height=10 "${result_array[@]}")
    
    if [ -n "$selected_file" ]; then
        copy_to_clipboard "$selected_file"
    else
        log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
        exit 1
    fi
}

# Interactive file selection from app history
select_from_app_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        log_info "${NEON_YELLOW}No files in memory banks.${RESET}" "true"
        log_info "${NEON_YELLOW}Try using 'clipbard' without arguments to extract from shell history.${RESET}" "true"
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
    
    # Configure gum styles for menu items
    export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
    
    # Use gum to create rad interactive selection
    log_info "${NEON_BLUE}█▓▒░ SELECT FILE FROM APP HISTORY ░▒▓█${RESET}" "true"
    local selected_file
    selected_file=$(gum choose --height=10 "${history_entries[@]:0:$max_display}")
    
    if [ -n "$selected_file" ]; then
        copy_to_clipboard "$selected_file"
    else
        log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
        exit 1
    fi
}

# Directory browser mode
browse_directory() {
    local dir="${1:-$PWD}"
    
    if [ ! -d "$dir" ]; then
        log_info "${NEON_YELLOW}Directory not found.${RESET}" "true"
        exit 1
    fi
    
    log_info "${NEON_BLUE}█▓▒░ DIRECTORY EXPLORER ░▒▓█${RESET}" "true"
    log_info "${NEON_GREEN}Current location:${RESET} $dir" "true"
    
    # Configure gum styles for menu items
    export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
    
    # List files and directories
    local entries=(".." $(ls -1 "$dir"))
    local selected_entry
    selected_entry=$(gum choose --height=20 "${entries[@]}")
    
    if [ -z "$selected_entry" ]; then
        log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
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
        log_info "${NEON_YELLOW}Invalid selection.${RESET}" "true"
        exit 1
    fi
}

# Format converter
convert_format() {
    local file="$1"
    local target_format="$2"
    
    if [ ! -f "$file" ]; then
        log_info "${NEON_YELLOW}ERROR: File not found.${RESET}" "true"
        return 1
    fi
    
    log_info "${NEON_BLUE}█▓▒░ FORMAT CONVERSION ░▒▓█${RESET}" "true"
    
    # Get current format
    local current_format="${file##*.}"
    
    if [ -z "$target_format" ]; then
        log_info "${NEON_GREEN}Available target formats:${RESET}" "true"
        log_info "- txt (plain text)" "true"
        log_info "- md (markdown)" "true"
        log_info "- html (HTML)" "true"
        log_info "- json (JSON)" "true"
        log_info "- csv (CSV)" "true"
        
        # Configure gum styles for menu items
        export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
        export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
        export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
        
        target_format=$(gum choose "txt" "md" "html" "json" "csv")
    fi
    
    if [ -z "$target_format" ]; then
        log_info "${NEON_YELLOW}Conversion cancelled.${RESET}" "true"
        return 1
    fi
    
    # Create temp output file
    local output_file="$TMP_DIR/$(basename "$file" ".$current_format").$target_format"
    
    case "$current_format:$target_format" in
        "md:html")
            if command -v pandoc &> /dev/null; then
                pandoc -f markdown -t html "$file" -o "$output_file"
            else
                log_info "${NEON_YELLOW}Pandoc required for this conversion.${RESET}" "true"
                return 1
            fi
            ;;
        "html:md")
            if command -v pandoc &> /dev/null; then
                pandoc -f html -t markdown "$file" -o "$output_file"
            else
                log_info "${NEON_YELLOW}Pandoc required for this conversion.${RESET}" "true"
                return 1
            fi
            ;;
        "json:csv")
            if command -v jq &> /dev/null; then
                # Basic JSON to CSV conversion
                jq -r '.[] | [.] | @csv' "$file" > "$output_file"
            else
                log_info "${NEON_YELLOW}jq required for this conversion.${RESET}" "true"
                return 1
            fi
            ;;
        "csv:json")
            if command -v python3 &> /dev/null; then
                python3 -c "import csv, json, sys; data = list(csv.DictReader(open('$file'))); print(json.dumps(data, indent=2))" > "$output_file"
            else
                log_info "${NEON_YELLOW}Python3 required for this conversion.${RESET}" "true"
                return 1
            fi
            ;;
        *)
            # Basic text conversion
            cat "$file" > "$output_file"
            ;;
    esac
    
    if [ -f "$output_file" ]; then
        log_info "${NEON_GREEN}Converted from .$current_format to .$target_format${RESET}" "true"
        log_info "${NEON_GREEN}Saved to:${RESET} $output_file" "true"
        
        if gum confirm "Copy converted file to clipboard?"; then
            copy_to_clipboard "$output_file"
        fi
    else
        log_info "${NEON_YELLOW}Conversion failed.${RESET}" "true"
        return 1
    fi
}

# Multiple clipboard buffers
use_buffer() {
    local buffer="$1"
    
    if [ -z "$buffer" ]; then
        log_info "${NEON_BLUE}█▓▒░ CLIPBOARD BUFFERS ░▒▓█${RESET}" "true"
        log_info "${NEON_GREEN}Current buffer:${RESET} $DEFAULT_BUFFER" "true"
        
        # Configure gum input styles
        export GUM_INPUT_CURSOR_FOREGROUND="${NEON_CYAN}"
        
        buffer=$(gum input --placeholder "Enter buffer number (0-9)")
    fi
    
    if [[ ! "$buffer" =~ ^[0-9]$ ]]; then
        log_info "${NEON_YELLOW}Invalid buffer number. Use 0-9.${RESET}" "true"
        return 1
    fi
    
    # Update config
    sed -i "s/^default_buffer=.*/default_buffer=$buffer/" "$CONFIG_FILE"
    DEFAULT_BUFFER=$buffer
    
    log_info "${NEON_GREEN}Switched to buffer ${DEFAULT_BUFFER}.${RESET}" "true"
    
    # Show current buffer content
    local content=$(get_clipboard_content "$buffer")
    local preview="${content:0:100}"
    
    if [ -n "$content" ]; then
        log_info "${NEON_BLUE}Current content (preview):${RESET}" "true"
        echo "$preview" | gum style --padding "1"
        if [ ${#content} -gt 100 ]; then
            log_info "${NEON_YELLOW}... ($(( ${#content} - 100 )) more characters)${RESET}" "true"
        fi
    else
        log_info "${NEON_YELLOW}Buffer is empty.${RESET}" "true"
    fi
}

# Installer function
install_clipbard() {
    print_synthwave_art "install"
    
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
        log_info "${NEON_GREEN}PATH updated in $shell_config${RESET}" "true"
        log_info "${NEON_YELLOW}TIP: Run 'source $shell_config' to activate${RESET}" "true"
    fi
    
    # Setup shell completion
    local completion_dir
    if [ -n "$ZSH_VERSION" ]; then
        completion_dir="$HOME/.zsh/completion"
        mkdir -p "$completion_dir"
        
        cat > "$completion_dir/_clipbard" << 'EOL'
#compdef clipbard
_clipbard() {
  local -a commands
  commands=(
    'help:Show help'
    'install:Install clipbard'
    'uninstall:Uninstall clipbard'
    'update:Update clipbard'
    'version:Show version'
    'config:Configure clipbard'
    'history:View copy history'
    'browse:Browse files'
    'search:Search history'
    'find:Search in file contents'
    'buffer:Switch clipboard buffer'
    'view:View clipboard content'
    'paste:Paste clipboard content'
    'convert:Convert file format'
    't:Copy text to clipboard'
    'p:Preview file before copying'
    'ps:Select line ranges'
  )
  
  _describe -t commands 'clipbard commands' commands
  _files
}

_clipbard
EOL
        
        echo "fpath=($completion_dir \$fpath)" >> "$HOME/.zshrc"
        echo "autoload -U compinit && compinit" >> "$HOME/.zshrc"
        log_info "${NEON_GREEN}Added ZSH completion${RESET}" "true"
    elif [ -n "$BASH_VERSION" ]; then
        completion_dir="$HOME/.bash_completion.d"
        mkdir -p "$completion_dir"
        
        cat > "$completion_dir/clipbard" << 'EOL'
_clipbard() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="help install uninstall update version config history browse search find buffer view paste convert t p ps"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    COMPREPLY=( $(compgen -f ${cur}) )
}
complete -F _clipbard clipbard
EOL
        
        echo "[ -d $completion_dir ] && for f in $completion_dir/*; do source \$f; done" >> "$HOME/.bashrc"
        log_info "${NEON_GREEN}Added Bash completion${RESET}" "true"
    fi
    
    log_info "${NEON_GREEN}▓▒░ INSTALLATION COMPLETE ░▒▓${RESET}" "true"
    exit 0
}

# Uninstaller function
uninstall_clipbard() {
    print_synthwave_art "uninstall"
    
    if gum confirm "Delete CLIPBARD from your system?"; then
        rm -f "$SCRIPT_PATH"
        if gum confirm "Delete configuration and history too?"; then
            rm -rf "$CONFIG_DIR"
        fi
        
        # Remove completions
        local zsh_completion="$HOME/.zsh/completion/_clipbard"
        local bash_completion="$HOME/.bash_completion.d/clipbard"
        
        [ -f "$zsh_completion" ] && rm -f "$zsh_completion"
        [ -f "$bash_completion" ] && rm -f "$bash_completion"
        
        log_info "${NEON_GREEN}CLIPBARD system purged successfully.${RESET}" "true"
        log_info "${NEON_YELLOW}Note: PATH modifications remain intact.${RESET}" "true"
    else
        log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
    fi
    exit 0
}

# Update function that pulls the latest version from GitHub
update_clipbard() {
    print_synthwave_art "update"
    
    # Create temporary directory for update
    local temp_dir=$(mktemp -d)
    
    # Clone the repository
    if git clone --depth 1 "$GITHUB_REPO" "$temp_dir"; then
        if [ -f "$temp_dir/clipbard.sh" ]; then
            # Make backup of current script
            cp "$SCRIPT_PATH" "$SCRIPT_PATH.backup"
            
            # Replace with new version
            cp "$temp_dir/clipbard.sh" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            
            # Clean up
            rm -rf "$temp_dir"
            
            log_info "${NEON_GREEN}▓▒░ UPGRADE COMPLETE ░▒▓${RESET}" "true"
            log_info "${NEON_YELLOW}Backup saved to:${RESET} $SCRIPT_PATH.backup" "true"
        else
            log_info "${NEON_YELLOW}ERROR: clipbard.sh not found in repository.${RESET}" "true"
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        log_info "${NEON_YELLOW}ERROR: Failed to access the repository.${RESET}" "true"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    exit 0
}

# Copy line range from file
copy_line_range() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_info "${NEON_YELLOW}ERROR: File not found.${RESET}" "true"
        return 1
    fi
    
    # Preview the file with line numbers
    log_info "${NEON_BLUE}█▓▒░ FILE CONTENTS ░▒▓█${RESET}" "true"
    nl -ba "$file" | gum style --border normal --margin "1" --padding "1"
    
    # Ask for line range
    local range
    log_info "${NEON_GREEN}Enter line range (e.g., 5-10 or 5 for single line):${RESET}" "true"
    
    # Configure gum input styles
    export GUM_INPUT_CURSOR_FOREGROUND="${NEON_CYAN}"
    
    range=$(gum input --placeholder "5-10")
    
    # Parse range and copy
    if [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}"
        local end="${BASH_REMATCH[2]}"
        
        if [ "$start" -gt "$end" ]; then
            log_info "${NEON_YELLOW}Invalid range: start > end${RESET}" "true"
            return 1
        fi
        
        local content=$(sed -n "${start},${end}p" "$file")
        copy_text_to_clipboard "$content"
        log_info "${NEON_GREEN}Copied lines ${start}-${end} to clipboard.${RESET}" "true"
    elif [[ "$range" =~ ^([0-9]+)$ ]]; then
        local line="${BASH_REMATCH[1]}"
        local content=$(sed -n "${line}p" "$file")
        copy_text_to_clipboard "$content"
        log_info "${NEON_GREEN}Copied line ${line} to clipboard.${RESET}" "true"
    else
        log_info "${NEON_YELLOW}Invalid range format.${RESET}" "true"
        return 1
    fi
}

# View current clipboard content
view_clipboard() {
    local buffer="${1:-$DEFAULT_BUFFER}"
    
    log_info "${NEON_BLUE}█▓▒░ CLIPBOARD VIEWER ░▒▓█${RESET}" "true"
    
    local content=$(get_clipboard_content "$buffer")
    local decrypted_content=$(decrypt_content "$content")
    
    if [ -z "$decrypted_content" ]; then
        log_info "${NEON_YELLOW}Clipboard is empty.${RESET}" "true"
        return 1
    fi
    
    local lines=$(echo -n "$decrypted_content" | wc -l)
    local chars=$(echo -n "$decrypted_content" | wc -m)
    
    log_info "${NEON_GREEN}Buffer:${RESET} $buffer" "true"
    log_info "${NEON_GREEN}Characters:${RESET} $chars" "true"
    log_info "${NEON_GREEN}Lines:${RESET} $lines" "true"
    
    log_info "${NEON_BLUE}Content:${RESET}" "true"
    
    echo "$decrypted_content" | gum style --border normal --margin "1" --padding "1"
    
    # Offer to save to file
    if gum confirm "Save to file?"; then
        local filename
        log_info "${NEON_GREEN}Enter filename:${RESET}" "true"
        
        # Configure gum input styles
        export GUM_INPUT_CURSOR_FOREGROUND="${NEON_CYAN}"
        
        filename=$(gum input --placeholder "output.txt")
        
        if [ -n "$filename" ]; then
            echo "$decrypted_content" > "$filename"
            log_info "${NEON_GREEN}Saved to:${RESET} $filename" "true"
        else
            log_info "${NEON_YELLOW}Save cancelled.${RESET}" "true"
        fi
    fi
}

# Paste clipboard content to file
paste_clipboard() {
    local file="$1"
    local buffer="${2:-$DEFAULT_BUFFER}"
    
    if [ -z "$file" ]; then
        log_info "${NEON_GREEN}Enter filename:${RESET}" "true"
        
        # Configure gum input styles
        export GUM_INPUT_CURSOR_FOREGROUND="${NEON_CYAN}"
        
        file=$(gum input --placeholder "output.txt")
        
        if [ -z "$file" ]; then
            log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
            return 1
        fi
    fi
    
    # Check if file exists
    if [ -f "$file" ]; then
        if ! gum confirm "File exists. Overwrite?"; then
            if gum confirm "Append instead?"; then
                local mode="append"
            else
                log_info "${NEON_YELLOW}Operation cancelled.${RESET}" "true"
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
        log_info "${NEON_YELLOW}Clipboard is empty.${RESET}" "true"
        return 1
    fi
    
    # Write to file
    if [ "$mode" = "append" ]; then
        echo "$decrypted_content" >> "$file"
    else
        echo "$decrypted_content" > "$file"
    fi
    
    log_info "${NEON_GREEN}Clipboard content ${mode}d to:${RESET} $file" "true"
}

# Display a setting with a toggle button
display_toggle_setting() {
    local setting_name="$1"
    local config_key="$2"
    local current_value=$(grep "^$config_key=" "$CONFIG_FILE" | cut -d= -f2)
    
    # Create toggle button appearance
    local toggle_display
    if [ "$current_value" = "true" ]; then
        toggle_display="${NEON_GREEN}[ON]${RESET}"
    else
        toggle_display="${NEON_YELLOW}[OFF]${RESET}"
    fi
    
    echo -e "${NEON_WHITE}$setting_name${RESET} $toggle_display"
}

# Toggle a boolean setting
toggle_setting() {
    local config_key="$1"
    local setting_name="$2"
    
    local current_value=$(grep "^$config_key=" "$CONFIG_FILE" | cut -d= -f2)
    local new_value
    
    if [ "$current_value" = "true" ]; then
        new_value="false"
    else
        new_value="true"
    fi
    
    sed -i "s/^$config_key=.*/$config_key=$new_value/" "$CONFIG_FILE"
    
    if [ "$new_value" = "true" ]; then
        log_success "$setting_name enabled"
    else
        log_success "$setting_name disabled"
    fi
    
    load_config
}

# General settings submenu
configure_general_settings() {
    local return_to_submenu=true
    
    # Define arrays for settings keys and display names
    local settings_keys=("theme" "history_size" "display_count" "verbose_logging")
    local settings_names=("Theme" "History Size" "Display Count" "Verbose Logging")
    
    while [ "$return_to_submenu" = true ]; do
        # Display current settings
        display_settings_table "GENERAL SETTINGS" settings_keys settings_names
        
        # Create options with toggle buttons for boolean settings
        local options=(
            "Theme [ ${NEON_CYAN}$(grep "^theme=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
            "History Size [ ${NEON_CYAN}$(grep "^history_size=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
            "Display Count [ ${NEON_CYAN}$(grep "^display_count=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
        )
        
        # Add toggle button for verbose logging
        if [ "$(grep "^verbose_logging=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Verbose Logging [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Verbose Logging [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        options+=("← Back")
        
        # Display options
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height 10)
        
        case "$selected_option" in
            "Theme"*)
                # Use buttons for theme selection
                local current_theme=$(grep "^theme=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Available Themes:${RESET}"
                local themes=("synthwave" "matrix" "cyberpunk" "midnight")
                local theme_options=()
                
                # Create button-like options for each theme
                for theme in "${themes[@]}"; do
                    if [ "$theme" = "$current_theme" ]; then
                        theme_options+=("${NEON_GREEN}[ $theme ]${RESET} (current)")
                    else
                        theme_options+=("${NEON_WHITE}[ $theme ]${RESET}")
                    fi
                done
                
                local selected_theme
                selected_theme=$(printf "%s\n" "${theme_options[@]}" | gum choose --height=6)
                
                # Extract theme name from selection
                if [ -n "$selected_theme" ]; then
                    local new_theme=$(echo "$selected_theme" | sed -r 's/\x1B\[[0-9;]*[mK]//g' | sed 's/\[//g' | sed 's/\].*//g' | xargs)
                    sed -i "s/^theme=.*/theme=$new_theme/" "$CONFIG_FILE"
                    log_success "Theme updated to: $new_theme"
                    # Immediately reload theme
                    load_config
                    apply_theme
                fi
                ;;
            "History Size"*)
                local current_value=$(grep "^history_size=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter new history size (1-999):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter new history size (1-999)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[1-9][0-9]{0,2}$ ]]; then
                    sed -i "s/^history_size=.*/history_size=$new_value/" "$CONFIG_FILE"
                    log_success "History size updated to: $new_value"
                    load_config
                else
                    log_error "Invalid value. Must be 1-999."
                fi
                ;;
            "Display Count"*)
                local current_value=$(grep "^display_count=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter new display count (1-99):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter new display count (1-99)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[1-9][0-9]?$ ]]; then
                    sed -i "s/^display_count=.*/display_count=$new_value/" "$CONFIG_FILE"
                    log_success "Display count updated to: $new_value"
                    load_config
                else
                    log_error "Invalid value. Must be 1-99."
                fi
                ;;
            "Verbose Logging"*)
                # Create yes/no buttons for confirmation
                echo -e "${NEON_GREEN}Toggle Verbose Logging:${RESET}"
                local current_value=$(grep "^verbose_logging=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^verbose_logging=.*/verbose_logging=true/" "$CONFIG_FILE"
                        log_success "Verbose logging enabled"
                    else
                        sed -i "s/^verbose_logging=.*/verbose_logging=false/" "$CONFIG_FILE"
                        log_success "Verbose logging disabled"
                    fi
                    load_config
                fi
                ;;
            "← Back"|"")
                return_to_submenu=false
                continue
                ;;
        esac
    done
}

# Clipboard settings submenu
configure_clipboard_settings() {
    local return_to_submenu=true
    
    # Define arrays for settings keys and display names
    local settings_keys=("auto_clear" "default_buffer" "max_file_size")
    local settings_names=("Auto Clear" "Default Buffer" "Max File Size")
    
    while [ "$return_to_submenu" = true ]; do
        # Display current settings
        display_settings_table "CLIPBOARD SETTINGS" settings_keys settings_names
        
        # Create options with toggle buttons for boolean settings
        local options=()
        
        # Add toggle button for auto_clear
        if [ "$(grep "^auto_clear=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Auto Clear [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Auto Clear [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        # Add other options
        options+=(
            "Default Buffer [ ${NEON_CYAN}$(grep "^default_buffer=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
            "Max File Size [ ${NEON_CYAN}$(grep "^max_file_size=" "$CONFIG_FILE" | cut -d= -f2) MB${RESET} ]"
            "← Back"
        )
        
        # Display options
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height 10)
        
        case "$selected_option" in
            "Auto Clear"*)
                echo -e "${NEON_GREEN}Toggle Auto Clear:${RESET}"
                local current_value=$(grep "^auto_clear=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^auto_clear=.*/auto_clear=true/" "$CONFIG_FILE"
                        log_success "Auto clear enabled"
                    else
                        sed -i "s/^auto_clear=.*/auto_clear=false/" "$CONFIG_FILE"
                        log_success "Auto clear disabled"
                    fi
                    load_config
                fi
                ;;
            "Default Buffer"*)
                local current_value=$(grep "^default_buffer=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter buffer number (0-9):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter buffer number (0-9)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[0-9]$ ]]; then
                    sed -i "s/^default_buffer=.*/default_buffer=$new_value/" "$CONFIG_FILE"
                    log_success "Default buffer updated to: $new_value"
                    load_config
                else
                    log_error "Invalid value. Must be a single digit (0-9)."
                fi
                ;;
            "Max File Size"*)
                local current_value=$(grep "^max_file_size=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter max file size in MB (1-9999):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter max file size in MB (1-9999)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[1-9][0-9]{0,3}$ ]]; then
                    sed -i "s/^max_file_size=.*/max_file_size=$new_value/" "$CONFIG_FILE"
                    log_success "Max file size updated to: $new_value MB"
                    load_config
                else
                    log_error "Invalid value. Must be 1-9999 MB."
                fi
                ;;
            "← Back"|"")
                return_to_submenu=false
                continue
                ;;
        esac
    done
}

# Security settings submenu
configure_security_settings() {
    local return_to_submenu=true
    
    # Define arrays for settings keys and display names
    local settings_keys=("notification" "compression" "encryption")
    local settings_names=("Notifications" "Compression" "Encryption")
    
    while [ "$return_to_submenu" = true ]; do
        # Display current settings
        display_settings_table "SECURITY SETTINGS" settings_keys settings_names
        
        # Create options with toggle buttons for boolean settings
        local options=()
        
        # Add toggle buttons
        if [ "$(grep "^notification=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Notifications [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Notifications [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        if [ "$(grep "^compression=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Compression [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Compression [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        if [ "$(grep "^encryption=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Encryption [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Encryption [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        options+=("← Back")
        
        # Display options
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height 10)
        
        case "$selected_option" in
            "Notifications"*)
                echo -e "${NEON_GREEN}Toggle Notifications:${RESET}"
                local current_value=$(grep "^notification=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^notification=.*/notification=true/" "$CONFIG_FILE"
                        log_success "Notifications enabled"
                    else
                        sed -i "s/^notification=.*/notification=false/" "$CONFIG_FILE"
                        log_success "Notifications disabled"
                    fi
                    load_config
                fi
                ;;
            "Compression"*)
                echo -e "${NEON_GREEN}Toggle Compression:${RESET}"
                local current_value=$(grep "^compression=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^compression=.*/compression=true/" "$CONFIG_FILE"
                        log_success "Compression enabled"
                    else
                        sed -i "s/^compression=.*/compression=false/" "$CONFIG_FILE"
                        log_success "Compression disabled"
                    fi
                    load_config
                fi
                ;;
            "Encryption"*)
                echo -e "${NEON_GREEN}Toggle Encryption:${RESET}"
                local current_value=$(grep "^encryption=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        if command -v openssl &> /dev/null; then
                            sed -i "s/^encryption=.*/encryption=true/" "$CONFIG_FILE"
                            log_success "Encryption enabled"
                        else
                            log_error "OpenSSL is required for encryption but not found on your system."
                        fi
                    else
                        sed -i "s/^encryption=.*/encryption=false/" "$CONFIG_FILE"
                        log_success "Encryption disabled"
                    fi
                    load_config
                fi
                ;;
            "← Back"|"")
                return_to_submenu=false
                continue
                ;;
        esac
    done
}

# History settings submenu
configure_history_settings() {
    local return_to_submenu=true
    
    # Define arrays for settings keys and display names
    local settings_keys=("shell_history_scan" "prefer_local_history" "preferred_history")
    local settings_names=("Shell History Scan" "Prefer Local History" "Preferred History")
    
    while [ "$return_to_submenu" = true ]; do
        # Display current settings
        display_settings_table "HISTORY SETTINGS" settings_keys settings_names
        
        # Create options with toggle buttons for boolean settings
        local options=()
        
        # Add toggle buttons
        if [ "$(grep "^shell_history_scan=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Shell History Scan [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Shell History Scan [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        if [ "$(grep "^prefer_local_history=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Prefer Local History [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Prefer Local History [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        options+=("Preferred History [ ${NEON_CYAN}$(grep "^preferred_history=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]")
        options+=("← Back")
        
        # Display options
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height 10)
        
        case "$selected_option" in
            "Shell History Scan"*)
                echo -e "${NEON_GREEN}Toggle Shell History Scan:${RESET}"
                local current_value=$(grep "^shell_history_scan=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^shell_history_scan=.*/shell_history_scan=true/" "$CONFIG_FILE"
                        log_success "Shell history scan enabled"
                    else
                        sed -i "s/^shell_history_scan=.*/shell_history_scan=false/" "$CONFIG_FILE"
                        log_success "Shell history scan disabled"
                    fi
                    load_config
                fi
                ;;
            "Prefer Local History"*)
                echo -e "${NEON_GREEN}Toggle Prefer Local History:${RESET}"
                local current_value=$(grep "^prefer_local_history=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^prefer_local_history=.*/prefer_local_history=true/" "$CONFIG_FILE"
                        log_success "Prefer local history enabled"
                    else
                        sed -i "s/^prefer_local_history=.*/prefer_local_history=false/" "$CONFIG_FILE"
                        log_success "Prefer local history disabled"
                    fi
                    load_config
                fi
                ;;
            "Preferred History"*)
                # Display history preference options
                echo -e "${NEON_GREEN}Select preferred history source:${RESET}"
                
                # Create visually appealing option buttons
                local current_value=$(grep "^preferred_history=" "$CONFIG_FILE" | cut -d= -f2)
                local history_options=()
                
                if [ "$current_value" = "auto" ]; then
                    history_options+=("${NEON_GREEN}[x] auto${RESET} (Automatically detect shell)")
                else
                    history_options+=("${NEON_WHITE}[ ] auto${RESET} (Automatically detect shell)")
                fi
                
                if [ "$current_value" = "bash" ]; then
                    history_options+=("${NEON_GREEN}[x] bash${RESET} (Always use Bash history)")
                else
                    history_options+=("${NEON_WHITE}[ ] bash${RESET} (Always use Bash history)")
                fi
                
                if [ "$current_value" = "zsh" ]; then
                    history_options+=("${NEON_GREEN}[x] zsh${RESET} (Always use ZSH history)")
                else
                    history_options+=("${NEON_WHITE}[ ] zsh${RESET} (Always use ZSH history)")
                fi
                
                local selected_history
                selected_history=$(printf "%s\n" "${history_options[@]}" | gum choose --height 5)
                
                if [ -n "$selected_history" ]; then
                    local new_value
                    if [[ "$selected_history" == *"auto"* ]]; then
                        new_value="auto"
                    elif [[ "$selected_history" == *"bash"* ]]; then
                        new_value="bash"
                    elif [[ "$selected_history" == *"zsh"* ]]; then
                        new_value="zsh"
                    fi
                    
                    sed -i "s/^preferred_history=.*/preferred_history=$new_value/" "$CONFIG_FILE"
                    log_success "Preferred history set to: $new_value"
                    load_config
                fi
                ;;
            "← Back"|"")
                return_to_submenu=false
                continue
                ;;
        esac
    done
}

# Security settings submenu
configure_security_settings() {
    local return_to_submenu=true
    
    # Define arrays for settings keys and display names
    local settings_keys=("notification" "compression" "encryption")
    local settings_names=("Notifications" "Compression" "Encryption")
    
    while [ "$return_to_submenu" = true ]; do
        # Display current settings
        display_settings_table "SECURITY SETTINGS" settings_keys settings_names
        
        # Create options with toggle buttons for boolean settings
        local options=()
        
        # Add toggle buttons
        if [ "$(grep "^notification=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Notifications [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Notifications [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        if [ "$(grep "^compression=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Compression [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Compression [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        if [ "$(grep "^encryption=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Encryption [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Encryption [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        options+=("← Back")
        
        # Display options
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height 10)
        
        case "$selected_option" in
            "Notifications"*)
                echo -e "${NEON_GREEN}Toggle Notifications:${RESET}"
                local current_value=$(grep "^notification=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^notification=.*/notification=true/" "$CONFIG_FILE"
                        log_success "Notifications enabled"
                    else
                        sed -i "s/^notification=.*/notification=false/" "$CONFIG_FILE"
                        log_success "Notifications disabled"
                    fi
                    load_config
                fi
                ;;
            "Compression"*)
                echo -e "${NEON_GREEN}Toggle Compression:${RESET}"
                local current_value=$(grep "^compression=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^compression=.*/compression=true/" "$CONFIG_FILE"
                        log_success "Compression enabled"
                    else
                        sed -i "s/^compression=.*/compression=false/" "$CONFIG_FILE"
                        log_success "Compression disabled"
                    fi
                    load_config
                fi
                ;;
            "Encryption"*)
                echo -e "${NEON_GREEN}Toggle Encryption:${RESET}"
                local current_value=$(grep "^encryption=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        if command -v openssl &> /dev/null; then
                            sed -i "s/^encryption=.*/encryption=true/" "$CONFIG_FILE"
                            log_success "Encryption enabled"
                        else
                            log_error "OpenSSL is required for encryption but not found on your system."
                        fi
                    else
                        sed -i "s/^encryption=.*/encryption=false/" "$CONFIG_FILE"
                        log_success "Encryption disabled"
                    fi
                    load_config
                fi
                ;;
            "← Back"|"")
                return_to_submenu=false
                continue
                ;;
        esac
    done
}

# Clipboard settings submenu
configure_clipboard_settings() {
    local return_to_submenu=true
    
    # Define arrays for settings keys and display names
    local settings_keys=("auto_clear" "default_buffer" "max_file_size")
    local settings_names=("Auto Clear" "Default Buffer" "Max File Size")
    
    while [ "$return_to_submenu" = true ]; do
        # Display current settings
        display_settings_table "CLIPBOARD SETTINGS" settings_keys settings_names
        
        # Create options with toggle buttons for boolean settings
        local options=()
        
        # Add toggle button for auto_clear
        if [ "$(grep "^auto_clear=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Auto Clear [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Auto Clear [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        # Add other options
        options+=(
            "Default Buffer [ ${NEON_CYAN}$(grep "^default_buffer=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
            "Max File Size [ ${NEON_CYAN}$(grep "^max_file_size=" "$CONFIG_FILE" | cut -d= -f2) MB${RESET} ]"
            "← Back"
        )
        
        # Display options
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height 10)
        
        case "$selected_option" in
            "Auto Clear"*)
                echo -e "${NEON_GREEN}Toggle Auto Clear:${RESET}"
                local current_value=$(grep "^auto_clear=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^auto_clear=.*/auto_clear=true/" "$CONFIG_FILE"
                        log_success "Auto clear enabled"
                    else
                        sed -i "s/^auto_clear=.*/auto_clear=false/" "$CONFIG_FILE"
                        log_success "Auto clear disabled"
                    fi
                    load_config
                fi
                ;;
            "Default Buffer"*)
                local current_value=$(grep "^default_buffer=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter buffer number (0-9):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter buffer number (0-9)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[0-9]$ ]]; then
                    sed -i "s/^default_buffer=.*/default_buffer=$new_value/" "$CONFIG_FILE"
                    log_success "Default buffer updated to: $new_value"
                    load_config
                else
                    log_error "Invalid value. Must be a single digit (0-9)."
                fi
                ;;
            "Max File Size"*)
                local current_value=$(grep "^max_file_size=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter max file size in MB (1-9999):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter max file size in MB (1-9999)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[1-9][0-9]{0,3}$ ]]; then
                    sed -i "s/^max_file_size=.*/max_file_size=$new_value/" "$CONFIG_FILE"
                    log_success "Max file size updated to: $new_value MB"
                    load_config
                else
                    log_error "Invalid value. Must be 1-9999 MB."
                fi
                ;;
            "← Back"|"")
                return_to_submenu=false
                continue
                ;;
        esac
    done
}

# General settings submenu
configure_general_settings() {
    local return_to_submenu=true
    
    # Define arrays for settings keys and display names
    local settings_keys=("theme" "history_size" "display_count" "verbose_logging")
    local settings_names=("Theme" "History Size" "Display Count" "Verbose Logging")
    
    while [ "$return_to_submenu" = true ]; do
        # Display current settings
        display_settings_table "GENERAL SETTINGS" settings_keys settings_names
        
        # Create options with toggle buttons for boolean settings
        local options=(
            "Theme [ ${NEON_CYAN}$(grep "^theme=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
            "History Size [ ${NEON_CYAN}$(grep "^history_size=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
            "Display Count [ ${NEON_CYAN}$(grep "^display_count=" "$CONFIG_FILE" | cut -d= -f2)${RESET} ]"
        )
        
        # Add toggle button for verbose logging
        if [ "$(grep "^verbose_logging=" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
            options+=("Verbose Logging [ ${NEON_GREEN}ON${RESET} ]")
        else
            options+=("Verbose Logging [ ${NEON_YELLOW}OFF${RESET} ]")
        fi
        
        options+=("← Back")
        
        # Display options
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height 10)
        
        case "$selected_option" in
            "Theme"*)
                # Use buttons for theme selection
                local current_theme=$(grep "^theme=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Available Themes:${RESET}"
                local themes=("synthwave" "matrix" "cyberpunk" "midnight")
                local theme_options=()
                
                # Create button-like options for each theme
                for theme in "${themes[@]}"; do
                    if [ "$theme" = "$current_theme" ]; then
                        theme_options+=("${NEON_GREEN}[ $theme ]${RESET} (current)")
                    else
                        theme_options+=("${NEON_WHITE}[ $theme ]${RESET}")
                    fi
                done
                
                local selected_theme
                selected_theme=$(printf "%s\n" "${theme_options[@]}" | gum choose --height=6)
                
                # Extract theme name from selection
                if [ -n "$selected_theme" ]; then
                    local new_theme=$(echo "$selected_theme" | sed -r 's/\x1B\[[0-9;]*[mK]//g' | sed 's/\[//g' | sed 's/\].*//g' | xargs)
                    sed -i "s/^theme=.*/theme=$new_theme/" "$CONFIG_FILE"
                    log_success "Theme updated to: $new_theme"
                    # Immediately reload theme
                    load_config
                    apply_theme
                fi
                ;;
            "History Size"*)
                local current_value=$(grep "^history_size=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter new history size (1-999):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter new history size (1-999)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[1-9][0-9]{0,2}$ ]]; then
                    sed -i "s/^history_size=.*/history_size=$new_value/" "$CONFIG_FILE"
                    log_success "History size updated to: $new_value"
                    load_config
                else
                    log_error "Invalid value. Must be 1-999."
                fi
                ;;
            "Display Count"*)
                local current_value=$(grep "^display_count=" "$CONFIG_FILE" | cut -d= -f2)
                
                echo -e "${NEON_GREEN}Enter new display count (1-99):${RESET}"
                local new_value
                new_value=$(gum input --placeholder "Enter new display count (1-99)" --value "$current_value")
                
                if [[ "$new_value" =~ ^[1-9][0-9]?$ ]]; then
                    sed -i "s/^display_count=.*/display_count=$new_value/" "$CONFIG_FILE"
                    log_success "Display count updated to: $new_value"
                    load_config
                else
                    log_error "Invalid value. Must be 1-99."
                fi
                ;;
            "Verbose Logging"*)
                # Create yes/no buttons for confirmation
                echo -e "${NEON_GREEN}Toggle Verbose Logging:${RESET}"
                local current_value=$(grep "^verbose_logging=" "$CONFIG_FILE" | cut -d= -f2)
                local options
                
                if [ "$current_value" = "true" ]; then
                    options=("${NEON_GREEN}[x] ON${RESET}" "${NEON_WHITE}[ ] OFF${RESET}")
                else
                    options=("${NEON_WHITE}[ ] ON${RESET}" "${NEON_GREEN}[x] OFF${RESET}")
                fi
                
                local toggle_choice
                toggle_choice=$(printf "%s\n" "${options[@]}" | gum choose --height 3)
                
                if [ -n "$toggle_choice" ]; then
                    if [[ "$toggle_choice" == *"ON"* ]]; then
                        sed -i "s/^verbose_logging=.*/verbose_logging=true/" "$CONFIG_FILE"
                        log_success "Verbose logging enabled"
                    else
                        sed -i "s/^verbose_logging=.*/verbose_logging=false/" "$CONFIG_FILE"
                        log_success "Verbose logging disabled"
                    fi
                    load_config
                fi
                ;;
            "← Back"|"")
                return_to_submenu=false
                continue
                ;;
        esac
    done
}

# Configure settings with improved menu structure
configure() {
    local return_to_config=true
    
    while [ "$return_to_config" = true ]; do
        # Main configuration menu with categories as buttons
        echo -e "${NEON_BLUE}█▓▒░ SYSTEM CONFIGURATION ░▒▓█${RESET}"
        
        # Create button-like menu options
        local options=(
            "${NEON_WHITE}[ General Settings ]${RESET}"
            "${NEON_WHITE}[ Clipboard Settings ]${RESET}"
            "${NEON_WHITE}[ Security Settings ]${RESET}"
            "${NEON_WHITE}[ History Settings ]${RESET}"
            "${NEON_WHITE}[ Exit Configuration ]${RESET}"
        )
        
        # Display options as buttons
        local selected_option
        selected_option=$(printf "%s\n" "${options[@]}" | gum choose --height=10)
        
        case "$selected_option" in
            "${NEON_WHITE}[ General Settings ]${RESET}")
                configure_general_settings
                ;;
            "${NEON_WHITE}[ Clipboard Settings ]${RESET}")
                configure_clipboard_settings
                ;;
            "${NEON_WHITE}[ Security Settings ]${RESET}")
                configure_security_settings
                ;;
            "${NEON_WHITE}[ History Settings ]${RESET}")
                configure_history_settings
                ;;
            "${NEON_WHITE}[ Exit Configuration ]${RESET}"|"")
                log_success "Configuration menu closed."
                return_to_config=false
                return 0
                ;;
        esac
    done
}

# View history
view_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        log_info "${NEON_YELLOW}No files in memory banks.${RESET}" "true"
        exit 1
    fi
    
    log_info "${NEON_BLUE}█▓▒░ MEMORY BANKS ░▒▓█${RESET}" "true"
    cat "$HISTORY_FILE" | nl | head -n "$HISTORY_SIZE" | gum style --border normal --margin "1" --padding "1"
    
    log_info "${NEON_GREEN}Displaying ${HISTORY_SIZE} most recent entries.${RESET}" "true"
    
    # Offer to clear history
    if gum confirm "Clear history?"; then
        > "$HISTORY_FILE"
        log_info "${NEON_GREEN}History cleared.${RESET}" "true"
    fi
    
    exit 0
}

# Show statistics
show_stats() {
    log_info "${NEON_BLUE}█▓▒░ SYSTEM STATISTICS ░▒▓█${RESET}" "true"
    
    if [ ! -s "$HISTORY_FILE" ]; then
        log_info "${NEON_YELLOW}No history data available.${RESET}" "true"
        return 1
    fi
    
    local total_entries=$(wc -l < "$HISTORY_FILE")
    local unique_entries=$(sort "$HISTORY_FILE" | uniq | wc -l)
    
    local most_copied=$(sort "$HISTORY_FILE" | uniq -c | sort -nr | head -n 1)
    local most_copied_file=$(echo "$most_copied" | awk '{$1=""; print $0}' | xargs)
    local most_copied_count=$(echo "$most_copied" | awk '{print $1}')
    
    log_info "${NEON_GREEN}Total copies:${RESET} $total_entries" "true"
    log_info "${NEON_GREEN}Unique files:${RESET} $unique_entries" "true"
    
    if [ -n "$most_copied_file" ]; then
        log_info "${NEON_GREEN}Most copied file:${RESET} $most_copied_file ($most_copied_count times)" "true"
    fi
    
    # File type statistics
    log_info "${NEON_BLUE}█▓▒░ FILE TYPE ANALYSIS ░▒▓█${RESET}" "true"
    
    log_info "Calculating..." "true"
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
        log_info "${NEON_GREEN}${types[$i]}:${RESET} ${type_counts[$i]}" "true"
    done
}

# Handle command and filename conflict
handle_command_conflict() {
    local command="$1"
    local file="$command"
    
    if [ -f "$file" ]; then
        log_info "${NEON_YELLOW}CONFLICT DETECTED:${RESET} '$command' is both a clipbard command and a file in this directory." "true"
        log_info "Do you want to:" "true"
        
        # Configure gum styles for menu items
        export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
        export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
        export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
        
        local choice
        choice=$(gum choose "Execute clipbard command '$command'" "Copy the file '$file' to clipboard")
        
        if [[ "$choice" == "Copy"* ]]; then
            copy_to_clipboard "$file"
            exit 0
        fi
        # Otherwise continue with command execution
    fi
}

# Print help message with fancy styling
print_help() {
    print_banner
    echo -e "${NEON_BLUE}█▓▒░ COMMAND REFERENCE ░▒▓█${RESET}"
    echo
    echo -e "${NEON_GREEN}Basic Usage:${RESET}"
    echo -e "  ${NEON_CYAN}clipbard${RESET} [FILENAME]          Copy file to clipboard"
    echo -e "  ${NEON_CYAN}clipbard${RESET}                   Select from recent files in shell history"
    echo -e "  ${NEON_CYAN}clipbard${RESET} t \"text\"          Copy text directly"
    echo
    echo -e "${NEON_GREEN}Preview Commands:${RESET}"
    echo -e "  ${NEON_CYAN}clipbard${RESET} p [FILENAME]      Preview file before copying"
    echo -e "  ${NEON_CYAN}clipbard${RESET} ps [FILENAME]     Preview and select line ranges"
    echo
    echo -e "${NEON_GREEN}Search Commands:${RESET}"
    echo -e "  ${NEON_CYAN}clipbard${RESET} search          Search through app history"
    echo -e "  ${NEON_CYAN}clipbard${RESET} find            Search in file contents"
    echo -e "  ${NEON_CYAN}clipbard${RESET} browse [DIR]    Browse files in directory"
    echo -e "  ${NEON_CYAN}clipbard${RESET} history         View application copy history"
    echo
    echo -e "${NEON_GREEN}Clipboard Commands:${RESET}"
    echo -e "  ${NEON_CYAN}clipbard${RESET} view            View clipboard content"
    echo -e "  ${NEON_CYAN}clipbard${RESET} paste [FILE]    Paste clipboard to file"
    echo -e "  ${NEON_CYAN}clipbard${RESET} buffer [NUM]    Switch clipboard buffer (0-9)"
    echo
    echo -e "${NEON_GREEN}Utility Commands:${RESET}"
    echo -e "  ${NEON_CYAN}clipbard${RESET} convert [FILE]  Convert file format"
    echo -e "  ${NEON_CYAN}clipbard${RESET} stats           Show usage statistics"
    echo -e "  ${NEON_CYAN}clipbard${RESET} config          Configure settings"
    echo
    echo -e "${NEON_GREEN}System Commands:${RESET}"
    echo -e "  ${NEON_CYAN}clipbard${RESET} install         Install to system"
    echo -e "  ${NEON_CYAN}clipbard${RESET} uninstall       Remove from system"
    echo -e "  ${NEON_CYAN}clipbard${RESET} update          Upgrade to latest version"
    echo -e "  ${NEON_CYAN}clipbard${RESET} version         Show version info"
    echo -e "  ${NEON_CYAN}clipbard${RESET} help            Show this help"
    echo
    echo -e "${NEON_BLUE}Created by Arash Abolhasani (@eraxe)${RESET}"
    exit 0
}

# Set up global gum styles for consistent look
setup_gum_styles() {
    # Menu items
    export GUM_CHOOSE_ITEM_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_FOREGROUND="${NEON_WHITE}"
    export GUM_CHOOSE_SELECTED_BACKGROUND="${NEON_CYAN}"
    
    # Input fields
    export GUM_INPUT_CURSOR_FOREGROUND="${NEON_CYAN}"
    export GUM_INPUT_PROMPT_FOREGROUND="${NEON_CYAN}"
    
    # Filter
    export GUM_FILTER_INDICATOR_FOREGROUND="${NEON_CYAN}"
    export GUM_FILTER_SELECTED_PREFIX_FOREGROUND="${NEON_CYAN}"
    export GUM_FILTER_SELECTED_FOREGROUND="${NEON_WHITE}"
    
    # Confirm
    export GUM_CONFIRM_SELECTED_BACKGROUND="${NEON_CYAN}"
    export GUM_CONFIRM_SELECTED_FOREGROUND="${NEON_WHITE}"
}

# Display a setting with a toggle button
display_toggle_setting() {
    local setting_name="$1"
    local config_key="$2"
    local current_value=$(grep "^$config_key=" "$CONFIG_FILE" | cut -d= -f2)
    
    # Create toggle button appearance
    local toggle_display
    if [ "$current_value" = "true" ]; then
        toggle_display="${NEON_GREEN}[ON]${RESET}"
    else
        toggle_display="${NEON_YELLOW}[OFF]${RESET}"
    fi
    
    echo -e "${NEON_WHITE}$setting_name${RESET} $toggle_display"
}

# Toggle a boolean setting
toggle_setting() {
    local config_key="$1"
    local setting_name="$2"
    
    local current_value=$(grep "^$config_key=" "$CONFIG_FILE" | cut -d= -f2)
    local new_value
    
    if [ "$current_value" = "true" ]; then
        new_value="false"
    else
        new_value="true"
    fi
    
    sed -i "s/^$config_key=.*/$config_key=$new_value/" "$CONFIG_FILE"
    
    if [ "$new_value" = "true" ]; then
        log_success "$setting_name enabled"
    else
        log_success "$setting_name disabled"
    fi
    
    load_config
}

# Display the current settings in a formatted table
display_settings_table() {
    local category="$1"
    local -n settings_keys=$2
    local -n settings_names=$3
    
    echo -e "${NEON_BLUE}█▓▒░ $category ░▒▓█${RESET}"
    
    local output=""
    for i in "${!settings_keys[@]}"; do
        local key="${settings_keys[$i]}"
        local name="${settings_names[$i]}"
        local value=$(grep "^$key=" "$CONFIG_FILE" | cut -d= -f2)
        
        # Format boolean values
        if [[ "$value" == "true" || "$value" == "false" ]]; then
            if [ "$value" == "true" ]; then
                value="${NEON_GREEN}Enabled${RESET}"
            else
                value="${NEON_YELLOW}Disabled${RESET}"
            fi
        fi
        
        # Add units or additional context for certain settings
        if [[ "$key" == "history_size" ]]; then
            value="$value items"
        elif [[ "$key" == "display_count" ]]; then
            value="$value items"
        elif [[ "$key" == "max_file_size" ]]; then
            value="$value MB"
        fi
        
        output+="${NEON_GREEN}$name:${RESET} $value\n"
    done
    
    echo -e "$output" | gum style --border normal --margin "1" --padding "1" --border-foreground "${NEON_CYAN}"
}

# Main logic
check_dependencies
setup_gum_styles

# Parse arguments without requiring double dashes
if [ $# -eq 0 ]; then
    # No arguments provided, show selection UI with shell history
    extract_files_from_history
    exit 0
fi

# First argument as command
cmd="$1"

# Check if the command is in conflict with a file (both a command and a filename)
if is_command "$cmd" && [ -f "$cmd" ]; then
    handle_command_conflict "$cmd"
fi

# Process commands
case "$cmd" in
    # System commands
    "install"|"i")
        install_clipbard
        ;;
    "uninstall"|"u")
        uninstall_clipbard
        ;;
    "update")
        update_clipbard
        ;;
    "version"|"v")
        print_banner
        exit 0
        ;;
    "help"|"h")
        print_help
        ;;
    # History and search commands
    "history")
        view_history
        ;;
    "search"|"s")
        search_app_history
        ;;
    "find"|"f")
        search_file_contents
        ;;
    "browse"|"b")
        browse_directory "$2"
        ;;
    # Clipboard commands
    "buffer")
        use_buffer "$2"
        ;;
    "view")
        view_clipboard "$2"
        ;;
    "paste")
        paste_clipboard "$2"
        ;;
    "convert"|"c")
        convert_format "$2" "$3"
        ;;
    "config")
        configure
        ;;
    "stats")
        show_stats
        ;;
    # Text and preview commands
    "t")
        # Copy text directly
        [ -n "$2" ] && copy_text_to_clipboard "$2" || log_error "No text provided."
        ;;
    "p")
        # Preview file then copy
        if [ -n "$2" ]; then
            preview_file "$2"
            if gum confirm "Copy to clipboard?"; then
                copy_to_clipboard "$2"
            fi
        else
            log_error "No file specified."
        fi
        ;;
    "ps")
        # Preview file and select line ranges to copy
        [ -n "$2" ] && copy_line_range "$2" || log_error "No file specified."
        ;;
    *)
        # Assume it's a file path
        if [ -f "$cmd" ]; then
            copy_to_clipboard "$cmd"
        else
            log_error "ERROR: '$cmd' is not a valid command or file."
            log_info "${NEON_GREEN}Try 'clipbard help' for usage information.${RESET}"
            exit 1
        fi
        ;;
esac
