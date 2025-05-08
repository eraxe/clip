#!/bin/bash
#
# ╔═╗╦  ╦╔═╗╔╗ ╔═╗╦═╗╔╦╗
# ║  ║  ║╠═╝╠╩╗╠═╣╠╦╝ ║║
# ╚═╝╩═╝╩╩  ╚═╝╩ ╩╩╚══╩╝
#
# A  R A D I C A L  clipboard utility
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

# Create default config if doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOL
# CLIPBARD Configuration File
history_size=$DEFAULT_HISTORY_SIZE
display_count=$DEFAULT_DISPLAY_COUNT
theme=$DEFAULT_THEME
auto_clear=false
notification=true
compression=false
encryption=false
default_buffer=$DEFAULT_CLIPBOARD_BUFFER
shell_history_scan=true
max_file_size=$DEFAULT_MAX_FILE_SIZE
prefer_local_history=true
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
        SHELL_HISTORY_SCAN=$(grep "^shell_history_scan=" "$CONFIG_FILE" | cut -d= -f2 || echo "true")
        MAX_FILE_SIZE=$(grep "^max_file_size=" "$CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_MAX_FILE_SIZE")
        PREFER_LOCAL_HISTORY=$(grep "^prefer_local_history=" "$CONFIG_FILE" | cut -d= -f2 || echo "true")
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
    echo -e "${NEON_PINK}v${VERSION} - Radical Clipboard Utility${RESET}"
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
    
    echo -e "${NEON_BLUE}█▓▒░ SCANNING SHELL HISTORY ░▒▓█${RESET}"
    
    # Array to store history sources
    local history_sources=()
    
    # Debug flag
    local debug_mode=true
    
    # Check which shell we're running in
    if [ -n "$ZSH_VERSION" ]; then
        echo -e "${NEON_GREEN}Detected ZSH shell${RESET}"
        
        # Get the current history file from ZSH
        if [ -n "$HISTFILE" ] && [ -f "$HISTFILE" ]; then
            [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Found HISTFILE: ${RESET}$HISTFILE"
            history_sources+=("$HISTFILE")
        fi
        
        # Check for per-directory-history plugin (jimhester/per-directory-history)
        local per_dir_hist_base="$HOME/.zsh_history_dirs"
        
        if [ -d "$per_dir_hist_base" ]; then
            [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Detected per-directory-history directory${RESET}"
            
            # Generate directory hash the same way the plugin does
            local current_dir_hash=$(echo "$PWD" | md5sum | cut -d' ' -f1)
            local per_dir_hist_file="$per_dir_hist_base/$current_dir_hash"
            
            if [ -f "$per_dir_hist_file" ]; then
                [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Found per-directory history: ${RESET}$per_dir_hist_file"
                
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
            [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Found global ZSH history: ${RESET}$HOME/.zsh_history"
            history_sources+=("$HOME/.zsh_history")
        fi
    elif [ -n "$BASH_VERSION" ]; then
        # Bash history
        echo -e "${NEON_GREEN}Detected Bash shell${RESET}"
        
        if [ -n "$HISTFILE" ] && [ -f "$HISTFILE" ]; then
            [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Found HISTFILE: ${RESET}$HISTFILE"
            history_sources+=("$HISTFILE")
        fi
        
        if [ -f "$HOME/.bash_history" ] && [[ ! " ${history_sources[@]} " =~ " $HOME/.bash_history " ]]; then
            [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Found bash history: ${RESET}$HOME/.bash_history"
            history_sources+=("$HOME/.bash_history")
        fi
    else
        echo -e "${NEON_YELLOW}Unknown shell, using history command directly${RESET}"
    fi
    
    # Temporary file to store potential file paths
    local tmp_files=$(mktemp)
    [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Temp file for paths: ${RESET}$tmp_files"
    
    # If we have history sources, process them
    if [ ${#history_sources[@]} -gt 0 ]; then
        for source in "${history_sources[@]}"; do
            echo -e "${NEON_GREEN}Processing history file: ${RESET}$source"
            
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
        echo -e "${NEON_GREEN}No history files found, using history command${RESET}"
        
        # Use history command and extract potential paths with different patterns
        history | tail -n "$history_size" | grep -o '/[a-zA-Z0-9._/-]\+' >> "$tmp_files"
        history | tail -n "$history_size" | grep -o '[a-zA-Z0-9._/-]\+\.[a-zA-Z0-9]\+' | grep -v '^[0-9]\+' >> "$tmp_files"
        
        # Try to catch files used with common commands
        history | tail -n "$history_size" | grep -E '(cat|nano|vim|vi|emacs|less|more|head|tail|grep|awk|sed) [^ ]+' | \
            awk '{print $2}' | grep -v '\-' >> "$tmp_files"
    fi
    
    # Debug: show what was found
    if [ "$debug_mode" = true ]; then
        echo -e "${NEON_GREEN}Raw file candidates found:${RESET}"
        if [ -s "$tmp_files" ]; then
            head -n 20 "$tmp_files"
            echo -e "${NEON_YELLOW}(showing first 20 entries)${RESET}"
        else
            echo -e "${NEON_YELLOW}No raw candidates found${RESET}"
        fi
    fi
    
    # Filter only existing files and directories
    local count=0
    local unique_files=()
    
    # For debugging
    if [ "$debug_mode" = true ]; then
        echo -e "${NEON_GREEN}Starting filtering process on candidates...${RESET}"
    fi
    
    # Sort and get unique entries
    sort "$tmp_files" | uniq > "${tmp_files}.sorted"
    mv "${tmp_files}.sorted" "$tmp_files"
    
    while IFS= read -r file; do
        # Remove leading/trailing whitespace
        file=$(echo "$file" | xargs)
        
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
        [ "$debug_mode" = true ] && echo -e "Checking: $file"
        
        # Check if file exists and has a recognized extension
        if [ -f "$file" ]; then
            local ext="${file##*.}"
            local is_recognized_ext=false
            
            # Check if file has no extension
            if [ "$ext" = "$file" ]; then
                # Try to determine if it's a text file
                if file "$file" | grep -q "text"; then
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
            if [ "$is_recognized_ext" = true ] || file "$file" | grep -q "text\|json\|xml\|script\|program\|source\|document"; then
                # Check if already in list (avoid duplicates)
                if ! echo "${unique_files[@]}" | grep -q "$file"; then
                    [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Found valid file:${RESET} $file"
                    unique_files+=("$file")
                    count=$((count + 1))
                    
                    # Break if we have enough files
                    if [ "$count" -ge "$display_count" ]; then
                        break
                    fi
                fi
            else
                [ "$debug_mode" = true ] && echo -e "${NEON_YELLOW}File exists but unrecognized type:${RESET} $file"
            fi
        elif [ "$debug_mode" = true ] && [[ "$file" == *"."* ]]; then
            echo -e "${NEON_YELLOW}File not found:${RESET} $file"
        fi
    done < "$tmp_files"
    
    # Clean up
    rm -f "$tmp_files"
    
    # If no files found, try to be more flexible with the matching
    if [ ${#unique_files[@]} -eq 0 ]; then
        echo -e "${NEON_YELLOW}No valid files found in history, trying direct command history...${RESET}"
        
        # Try a more direct approach - look for commands that typically operate on files
        local tmp_cmds=$(mktemp)
        history | grep -E '(cat|nano|vim|vi|emacs|less|more|head|tail|grep) [^ ]+' | \
            tail -n 50 | awk '{for(i=2;i<=NF;i++) if($i !~ /^-/) print $i}' > "$tmp_cmds"
        
        while IFS= read -r file; do
            file=$(echo "$file" | xargs)
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
                [ "$debug_mode" = true ] && echo -e "${NEON_GREEN}Found file from command history:${RESET} $file"
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
        echo -e "${NEON_YELLOW}No files found in history. Showing files in current directory.${RESET}"
        
        # Find files in current directory with recognized extensions
        for file in "$PWD"/*; do
            if [ -f "$file" ]; then
                local ext="${file##*.}"
                local is_recognized=false
                
                if [ "$ext" = "$file" ]; then
                    # No extension, check if it's text
                    if file "$file" | grep -q "text"; then
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
        echo -e "${NEON_YELLOW}No valid files found. Try browsing with 'clipbard browse'.${RESET}"
        return 1
    fi
    
    # Use gum to create rad interactive selection
    echo -e "${NEON_GREEN}Found ${#unique_files[@]} files in history:${RESET}"
    local selected_file
    selected_file=$(gum choose --height=10 "${unique_files[@]}")
    
    if [ -n "$selected_file" ]; then
        # Add to clipbard history
        local tmp_file=$(mktemp)
        echo "$selected_file" > "$tmp_file"
        grep -v "^$selected_file$" "$HISTORY_FILE" | head -n $(($HISTORY_SIZE-1)) >> "$tmp_file"
        mv "$tmp_file" "$HISTORY_FILE"
        
        # Copy to clipboard
        copy_to_clipboard "$selected_file"
    else
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
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
    
    # Check file size against max_file_size
    local file_size_kb=$(du -k "$file" | cut -f1)
    local file_size_mb=$(echo "scale=2; $file_size_kb/1024" | bc)
    local max_size_mb=$MAX_FILE_SIZE
    
    if (( $(echo "$file_size_mb > $max_size_mb" | bc -l) )); then
        echo -e "${NEON_YELLOW}WARNING: File size ($file_size_mb MB) exceeds maximum size limit ($max_size_mb MB).${RESET}"
        if ! gum confirm "Do you want to copy this large file anyway?"; then
            echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
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
        echo -e "${NEON_YELLOW}ERROR: No clipboard utility detected.${RESET}"
        return 1
    fi
    
    # Auto-clear if enabled
    if [ "$AUTO_CLEAR" = "true" ]; then
        echo "Auto-clearing clipboard in 60 seconds..."
        (sleep 60 && echo -n "" | clipboard_copy) &
    fi
    
    show_notification "CLIPBARD" "Text copied to clipboard"
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

# Interactive search through history - explicitly searches app history
search_app_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${NEON_YELLOW}No files in memory banks.${RESET}"
        exit 1
    fi
    
    echo -e "${NEON_BLUE}█▓▒░ SEARCH APP MEMORY BANKS ░▒▓█${RESET}"
    
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

# Interactive file selection from app history
select_from_app_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${NEON_YELLOW}No files in memory banks.${RESET}"
        echo -e "${NEON_YELLOW}Try using 'clipbard' without arguments to extract from shell history.${RESET}"
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
    echo -e "${NEON_BLUE}█▓▒░ SELECT FILE FROM APP HISTORY ░▒▓█${RESET}"
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
        echo -e "${NEON_GREEN}PATH updated in $shell_config${RESET}"
        echo -e "${NEON_YELLOW}TIP: Run 'source $shell_config' to activate${RESET}"
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
        echo -e "${NEON_GREEN}Added ZSH completion${RESET}"
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
        echo -e "${NEON_GREEN}Added Bash completion${RESET}"
    fi
    
    echo -e "${NEON_GREEN}▓▒░ INSTALLATION COMPLETE ░▒▓${RESET}"
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
        
        echo -e "${NEON_GREEN}CLIPBARD system purged successfully.${RESET}"
        echo -e "${NEON_YELLOW}Note: PATH modifications remain intact.${RESET}"
    else
        echo -e "${NEON_YELLOW}Operation cancelled.${RESET}"
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
            
            echo -e "${NEON_GREEN}▓▒░ UPGRADE COMPLETE ░▒▓${RESET}"
            echo -e "${NEON_YELLOW}Backup saved to:${RESET} $SCRIPT_PATH.backup"
        else
            echo -e "${NEON_YELLOW}ERROR: clipbard.sh not found in repository.${RESET}"
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
    setting=$(gum choose "history_size" "display_count" "theme" "auto_clear" "notification" "compression" "encryption" "shell_history_scan" "default_buffer" "max_file_size" "prefer_local_history")
    
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
        "default_buffer")
            local new_value
            new_value=$(gum input --placeholder "Enter buffer number (0-9)" --value "$current_value")
            
            if [[ ! "$new_value" =~ ^[0-9]$ ]]; then
                echo -e "${NEON_YELLOW}Invalid value. Must be 0-9.${RESET}"
                return 1
            fi
            ;;
        "max_file_size")
            local new_value
            new_value=$(gum input --placeholder "Enter max file size in MB (1-9999)" --value "$current_value")
            
            if [[ ! "$new_value" =~ ^[1-9][0-9]{0,3}$ ]]; then
                echo -e "${NEON_YELLOW}Invalid value. Must be 1-9999 MB.${RESET}"
                return 1
            fi
            ;;
        "auto_clear"|"notification"|"compression"|"encryption"|"shell_history_scan"|"prefer_local_history")
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
    if grep -q "^$setting=" "$CONFIG_FILE"; then
        sed -i "s/^$setting=.*/$setting=$new_value/" "$CONFIG_FILE"
    else
        echo "$setting=$new_value" >> "$CONFIG_FILE"
    fi
    
    echo -e "${NEON_GREEN}Setting updated:${RESET} $setting = $new_value"
    echo -e "${NEON_YELLOW}Restart clipbard for changes to take effect.${RESET}"
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

# Handle command and filename conflict
handle_command_conflict() {
    local command="$1"
    local file="$command"
    
    if [ -f "$file" ]; then
        echo -e "${NEON_YELLOW}CONFLICT DETECTED:${RESET} '$command' is both a clipbard command and a file in this directory."
        echo -e "Do you want to:"
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
    echo -e "  ${NEON_PINK}clipbard${RESET} [FILENAME]          Copy file to clipboard"
    echo -e "  ${NEON_PINK}clipbard${RESET}                   Select from recent files in shell history"
    echo -e "  ${NEON_PINK}clipbard${RESET} t \"text\"          Copy text directly"
    echo
    echo -e "${NEON_GREEN}Preview Commands:${RESET}"
    echo -e "  ${NEON_PINK}clipbard${RESET} p [FILENAME]      Preview file before copying"
    echo -e "  ${NEON_PINK}clipbard${RESET} ps [FILENAME]     Preview and select line ranges"
    echo
    echo -e "${NEON_GREEN}Search Commands:${RESET}"
    echo -e "  ${NEON_PINK}clipbard${RESET} search          Search through app history"
    echo -e "  ${NEON_PINK}clipbard${RESET} find            Search in file contents"
    echo -e "  ${NEON_PINK}clipbard${RESET} browse [DIR]    Browse files in directory"
    echo -e "  ${NEON_PINK}clipbard${RESET} history         View application copy history"
    echo
    echo -e "${NEON_GREEN}Clipboard Commands:${RESET}"
    echo -e "  ${NEON_PINK}clipbard${RESET} view            View clipboard content"
    echo -e "  ${NEON_PINK}clipbard${RESET} paste [FILE]    Paste clipboard to file"
    echo -e "  ${NEON_PINK}clipbard${RESET} buffer [NUM]    Switch clipboard buffer (0-9)"
    echo
    echo -e "${NEON_GREEN}Utility Commands:${RESET}"
    echo -e "  ${NEON_PINK}clipbard${RESET} convert [FILE]  Convert file format"
    echo -e "  ${NEON_PINK}clipbard${RESET} stats           Show usage statistics"
    echo -e "  ${NEON_PINK}clipbard${RESET} config          Configure settings"
    echo
    echo -e "${NEON_GREEN}System Commands:${RESET}"
    echo -e "  ${NEON_PINK}clipbard${RESET} install         Install to system"
    echo -e "  ${NEON_PINK}clipbard${RESET} uninstall       Remove from system"
    echo -e "  ${NEON_PINK}clipbard${RESET} update          Upgrade to latest version"
    echo -e "  ${NEON_PINK}clipbard${RESET} version         Show version info"
    echo -e "  ${NEON_PINK}clipbard${RESET} help            Show this help"
    echo
    echo -e "${NEON_BLUE}Created by Arash Abolhasani (@eraxe)${RESET}"
    exit 0
}

# Main logic
check_dependencies

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
        [ -n "$2" ] && copy_text_to_clipboard "$2" || echo -e "${NEON_YELLOW}ERROR: No text provided.${RESET}"
        ;;
    "p")
        # Preview file then copy
        if [ -n "$2" ]; then
            preview_file "$2"
            if gum confirm "Copy to clipboard?"; then
                copy_to_clipboard "$2"
            fi
        else
            echo -e "${NEON_YELLOW}ERROR: No file specified.${RESET}"
        fi
        ;;
    "ps")
        # Preview file and select line ranges to copy
        [ -n "$2" ] && copy_line_range "$2" || echo -e "${NEON_YELLOW}ERROR: No file specified.${RESET}"
        ;;
    *)
        # Assume it's a file path
        if [ -f "$cmd" ]; then
            copy_to_clipboard "$cmd"
        else
            echo -e "${NEON_YELLOW}ERROR: '$cmd' is not a valid command or file.${RESET}"
            echo -e "${NEON_GREEN}Try 'clipbard help' for usage information.${RESET}"
            exit 1
        fi
        ;;
esac