#!/usr/bin/env bash

# TUI Frameworks Explorer
# Script to check, install, and demonstrate features of various TUI/CLI frameworks on Arch Linux

# ANSI color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Array to keep track of any installation failures
FAILED_INSTALLS=()

# ====================================
# Utility Functions
# ====================================

print_header() {
    echo -e "\n${BOLD}${BLUE}===== $1 =====${NC}\n"
}

print_subheader() {
    echo -e "\n${BOLD}${CYAN}--- $1 ---${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_feature() {
    echo -e "${MAGENTA}• $1${NC}"
}

ask_to_continue() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

# ====================================
# Package Management Functions
# ====================================

install_pacman_package() {
    local package=$1
    
    if pacman -Q "$package" >/dev/null 2>&1; then
        print_success "$package is already installed via pacman"
        return 0
    else
        print_warning "Installing $package via pacman..."
        if sudo pacman -S --noconfirm "$package"; then
            print_success "$package installed successfully"
            return 0
        else
            print_error "Failed to install $package via pacman"
            FAILED_INSTALLS+=("$package (pacman)")
            return 1
        fi
    fi
}

install_aur_package() {
    local package=$1
    local aur_helper
    
    # Check if either yay or paru is installed
    if check_command "yay"; then
        aur_helper="yay"
    elif check_command "paru"; then
        aur_helper="paru"
    else
        print_warning "Neither yay nor paru is installed. Installing yay..."
        
        # Create a temporary directory
        local temp_dir
        temp_dir=$(mktemp -d)
        cd "$temp_dir" || return 1
        
        # Clone and build yay
        if pacman -Q git >/dev/null 2>&1 || sudo pacman -S --noconfirm git; then
            if git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm; then
                aur_helper="yay"
                print_success "yay installed successfully"
            else
                print_error "Failed to install yay"
                FAILED_INSTALLS+=("yay (AUR helper)")
                return 1
            fi
        else
            print_error "Failed to install git, which is required for AUR"
            FAILED_INSTALLS+=("git (required for AUR)")
            return 1
        fi
        
        # Cleanup
        cd / && rm -rf "$temp_dir"
    fi
    
    # Check if the package is already installed
    if pacman -Q "$package" >/dev/null 2>&1; then
        print_success "$package is already installed"
        return 0
    else
        print_warning "Installing $package via $aur_helper..."
        if "$aur_helper" -S --noconfirm "$package"; then
            print_success "$package installed successfully"
            return 0
        else
            print_error "Failed to install $package via $aur_helper"
            FAILED_INSTALLS+=("$package (AUR)")
            return 1
        fi
    fi
}

install_pip_package() {
    local package=$1
    
    # Ensure pip is installed
    if ! check_command "pip"; then
        print_warning "pip is not installed. Installing python-pip..."
        if ! install_pacman_package "python-pip"; then
            print_error "Failed to install pip, cannot install Python packages"
            FAILED_INSTALLS+=("python-pip (required for Python packages)")
            return 1
        fi
    fi
    
    # Check if the package is already installed
    if pip list | grep -i "^$package " >/dev/null 2>&1; then
        print_success "$package is already installed via pip"
        return 0
    else
        print_warning "Installing $package via pip..."
        if pip install --user "$package"; then
            print_success "$package installed successfully"
            return 0
        else
            print_error "Failed to install $package via pip"
            FAILED_INSTALLS+=("$package (pip)")
            return 1
        fi
    fi
}

install_cargo_package() {
    local package=$1
    
    # Ensure cargo is installed
    if ! check_command "cargo"; then
        print_warning "cargo is not installed. Installing rustup..."
        if ! install_pacman_package "rustup"; then
            print_error "Failed to install rustup, cannot install Rust packages"
            FAILED_INSTALLS+=("rustup (required for Rust packages)")
            return 1
        fi
        
        # Initialize rustup
        rustup default stable
    fi
    
    # Check if the package is already installed
    if cargo install --list | grep -i "^$package " >/dev/null 2>&1; then
        print_success "$package is already installed via cargo"
        return 0
    else
        print_warning "Installing $package via cargo..."
        if cargo install "$package"; then
            print_success "$package installed successfully"
            return 0
        else
            print_error "Failed to install $package via cargo"
            FAILED_INSTALLS+=("$package (cargo)")
            return 1
        fi
    fi
}

install_go_package() {
    local package=$1
    local binary_name=$2  # The name of the binary to check, often different from package name
    
    # Ensure go is installed
    if ! check_command "go"; then
        print_warning "go is not installed. Installing go..."
        if ! install_pacman_package "go"; then
            print_error "Failed to install go, cannot install Go packages"
            FAILED_INSTALLS+=("go (required for Go packages)")
            return 1
        fi
    fi
    
    # Check if the binary is already available
    if check_command "$binary_name"; then
        print_success "$package is already installed (found $binary_name)"
        return 0
    else
        print_warning "Installing $package via go install..."
        if go install "$package@latest"; then
            # Make sure GOPATH/bin is in PATH for this session
            export PATH="$PATH:$(go env GOPATH)/bin"
            if check_command "$binary_name"; then
                print_success "$package installed successfully"
                return 0
            else
                print_error "Installation seemed successful but $binary_name not found in PATH"
                print_warning "Add \$(go env GOPATH)/bin to your PATH"
                FAILED_INSTALLS+=("$package (go, binary not in PATH)")
                return 1
            fi
        else
            print_error "Failed to install $package via go"
            FAILED_INSTALLS+=("$package (go)")
            return 1
        fi
    fi
}

# ====================================
# Tool Installation & Feature Demonstration
# ====================================

# --- GUM ---
install_and_demo_gum() {
    print_header "GUM (Charmbracelet)"
    
    # Install gum
    if install_pacman_package "gum"; then
        print_subheader "GUM Features"
        
        echo "GUM is a tool for glamorous shell scripts, providing styled text, inputs, selections, etc."
        
        print_feature "Styled Text & Spinners:"
        gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Gum provides styled text with borders, margins, and padding" | gum spin --spinner dot --title "Loading..."
        
        print_feature "User Input:"
        echo "What's your name? $(gum input --placeholder "Enter your name")"
        
        print_feature "Confirmations:"
        if gum confirm "Would you like to see more GUM features?"; then
            print_feature "Selections:"
            CHOICE=$(gum choose "Option 1" "Option 2" "Option 3")
            echo "You selected: $CHOICE"
            
            print_feature "Multi-selections:"
            echo "Select multiple options:"
            CHOICES=$(gum choose --no-limit "Option 1" "Option 2" "Option 3" "Option 4")
            echo "You selected: $CHOICES"
            
            print_feature "Filter/Fuzzy Finding:"
            FILTERED=$(gum filter --placeholder "Search..." <<< "Apple
Banana
Cherry
Date
Elderberry")
            echo "You filtered to: $FILTERED"
            
            print_feature "File Picker:"
            echo "Pick a file: $(gum file)"
            
            print_feature "Writing with Vim motions:"
            echo "Write something (Use Ctrl+D to finish):"
            gum write --width 40 --height 5
        fi
    else
        print_error "Skipping GUM demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- BUBBLES (Charmbracelet UI Components) ---
install_and_demo_bubbles() {
    print_header "BUBBLES (Charmbracelet UI Components)"
    
    if check_command "go"; then
        print_subheader "BUBBLES Features"
        
        echo "Bubbles is a collection of TUI components for BubbleTea applications."
        
        print_feature "Key Bubbles Components:"
        echo " - Text Input: Fields for user input with validation"
        echo " - Text Area: Multi-line text editing"
        echo " - Viewport: Scrollable views for content larger than the terminal"
        echo " - Progress: Progress bars and spinners"
        echo " - List: Interactive lists with keyboard navigation"
        echo " - Table: Data tables with sorting and filtering"
        echo " - Key Map: Keyboard shortcut handling"
        echo " - Help: Context-sensitive help screens"
        
        print_feature "Example Code (for your TUI project):"
        echo '```go'
        echo 'import ('
        echo '    "github.com/charmbracelet/bubbles/list"'
        echo '    "github.com/charmbracelet/bubbles/textinput"'
        echo '    "github.com/charmbracelet/bubbles/viewport"'
        echo '    tea "github.com/charmbracelet/bubbletea"'
        echo ')'
        echo ''
        echo '// Create a text input field'
        echo 'func initialModel() model {'
        echo '    ti := textinput.New()'
        echo '    ti.Placeholder = "Type something..."'
        echo '    ti.Focus()'
        echo ''
        echo '    // Create a list'
        echo '    items := []list.Item{...}'
        echo '    l := list.New(items, list.NewDefaultDelegate(), 0, 0)'
        echo '    l.Title = "My List"'
        echo ''
        echo '    return model{textInput: ti, list: l}'
        echo '}'
        echo '```'
    else
        print_error "Go is not installed. Bubbles is a Go library."
        print_warning "Install Go first to use Bubbles in your projects."
    fi
    
    ask_to_continue
}

# --- RATATUI (Rust TUI Framework) ---
install_and_demo_ratatui() {
    print_header "RATATUI (Rust TUI Framework)"
    
    if check_command "cargo"; then
        print_subheader "RATATUI Features"
        
        echo "Ratatui is a Rust library for building rich terminal user interfaces."
        echo "It's the successor to the popular tui-rs library."
        
        print_feature "Key Ratatui Features:"
        echo " - Widgets: Text, Paragraph, Block, List, Table, Chart, Canvas, Gauge, etc."
        echo " - Layout system: Constraint-based for responsive designs"
        echo " - Event handling: Keyboard, mouse, terminal resize"
        echo " - Custom styling: Colors, modifiers (bold, italic), etc."
        echo " - Backend agnostic: Works with crossterm, termion, etc."
        
        print_feature "Example Code (for your TUI project):"
        echo '```rust'
        echo 'use ratatui::{backend::CrosstermBackend, Terminal};'
        echo 'use ratatui::widgets::{Block, Borders, Paragraph};'
        echo 'use ratatui::layout::{Layout, Constraint, Direction};'
        echo 'use std::io;'
        echo ''
        echo 'fn main() -> Result<(), io::Error> {'
        echo '    // Setup terminal'
        echo '    let backend = CrosstermBackend::new(io::stdout());'
        echo '    let mut terminal = Terminal::new(backend)?;'
        echo ''
        echo '    terminal.draw(|f| {'
        echo '        let chunks = Layout::default()'
        echo '            .direction(Direction::Vertical)'
        echo '            .constraints(['
        echo '                Constraint::Percentage(10),'
        echo '                Constraint::Percentage(80),'
        echo '                Constraint::Percentage(10)'
        echo '            ].as_ref())'
        echo '            .split(f.size());'
        echo ''
        echo '        let block = Block::default()'
        echo '            .title("Block")'
        echo '            .borders(Borders::ALL);'
        echo '        f.render_widget(block, chunks[0]);'
        echo ''
        echo '        let paragraph = Paragraph::new("Hello Ratatui!")'
        echo '            .block(Block::default().title("Paragraph").borders(Borders::ALL));'
        echo '        f.render_widget(paragraph, chunks[1]);'
        echo '    })?;'
        echo ''
        echo '    Ok(())'
        echo '}'
        echo '```'
        
        # Install demo app if not already installed
        if ! check_command "ratatui-demo"; then
            print_warning "No Ratatui demo found. Would you like to install a simple example? (Will take a minute)"
            if gum confirm "Install Ratatui demo?"; then
                echo "Creating a simple Ratatui demo app..."
                TEMP_DIR=$(mktemp -d)
                cd "$TEMP_DIR" || return
                
                # Initialize a new Rust project
                cargo init --bin ratatui-demo
                cd ratatui-demo || return
                
                # Add dependencies
                echo 'ratatui = "0.24.0"' >> Cargo.toml
                echo 'crossterm = "0.27.0"' >> Cargo.toml
                
                # Create a simple Ratatui app
                cat > src/main.rs << 'EOL'
use std::{io, time::Duration};
use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    widgets::{Block, Borders, Paragraph},
    Terminal,
};

fn main() -> Result<(), io::Error> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // App state
    let mut counter = 0;

    loop {
        // Draw UI
        terminal.draw(|f| {
            let size = f.size();
            let block = Block::default()
                .title("Ratatui Demo")
                .borders(Borders::ALL);
            f.render_widget(block, size);

            let text = format!("Counter: {}\n\nPress Up/Down to change counter\nPress 'q' to quit", counter);
            let paragraph = Paragraph::new(text)
                .block(Block::default().borders(Borders::NONE));
            f.render_widget(paragraph, size);
        })?;

        // Handle input
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') => break,
                    KeyCode::Up => counter += 1,
                    KeyCode::Down => counter -= 1,
                    _ => {}
                }
            }
        }
    }

    // Restore terminal
    disable_raw_mode()?;
    execute!(io::stdout(), LeaveAlternateScreen)?;
    Ok(())
}
EOL
                
                # Build and install the demo
                cargo install --path .
                
                cd / && rm -rf "$TEMP_DIR"
                print_success "Installed ratatui-demo"
                
                print_feature "Running Ratatui Demo:"
                echo "Use Up/Down arrow keys to change counter. Press 'q' to quit."
                sleep 2
                ratatui-demo
            fi
        elif check_command "ratatui-demo"; then
            print_feature "Running Ratatui Demo:"
            echo "Use Up/Down arrow keys to change counter. Press 'q' to quit."
            sleep 2
            ratatui-demo
        fi
    else
        print_error "Rust/Cargo is not installed. Ratatui is a Rust library."
        print_warning "Install Rust first to use Ratatui in your projects."
    fi
    
    ask_to_continue
}

# --- CROSSTERM (Rust Terminal Control) ---
install_and_demo_crossterm() {
    print_header "CROSSTERM (Rust Terminal Control)"
    
    if check_command "cargo"; then
        print_subheader "CROSSTERM Features"
        
        echo "Crossterm is a Rust library for cross-platform terminal manipulation."
        echo "It's often used as a backend for TUI frameworks like Ratatui."
        
        print_feature "Key Crossterm Features:"
        echo " - Cross-platform terminal control (Windows, macOS, Linux)"
        echo " - Raw mode handling"
        echo " - Cursor control"
        echo " - Terminal events (keyboard, mouse, resize)"
        echo " - Colors and styles"
        echo " - Alternate screen buffer"
        
        print_feature "Example Code (for your TUI project):"
        echo '```rust'
        echo 'use std::io::{stdout, Write};'
        echo 'use crossterm::{'
        echo '    execute,'
        echo '    style::{Color, Print, ResetColor, SetBackgroundColor, SetForegroundColor},'
        echo '    terminal::{Clear, ClearType},'
        echo '    cursor::{Hide, Show, MoveTo},'
        echo '    event::{read, Event, KeyCode},'
        echo '    Result'
        echo '};'
        echo ''
        echo 'fn main() -> Result<()> {'
        echo '    // Set up terminal'
        echo '    let mut stdout = stdout();'
        echo '    execute!(stdout, Hide)?;'
        echo ''
        echo '    // Draw colored text'
        echo '    execute!('
        echo '        stdout,'
        echo '        SetForegroundColor(Color::Blue),'
        echo '        SetBackgroundColor(Color::White),'
        echo '        Print("Styled text with Crossterm"),'
        echo '        ResetColor'
        echo '    )?;'
        echo ''
        echo '    // Wait for a keypress'
        echo '    loop {'
        echo '        if let Event::Key(key) = read()? {'
        echo '            if key.code == KeyCode::Esc {'
        echo '                break;'
        echo '            }'
        echo '        }'
        echo '    }'
        echo ''
        echo '    // Clean up'
        echo '    execute!(stdout, Show)?;'
        echo '    Ok(())'
        echo '}'
        echo '```'
    else
        print_error "Rust/Cargo is not installed. Crossterm is a Rust library."
        print_warning "Install Rust first to use Crossterm in your projects."
    fi
    
    ask_to_continue
}

# --- ZELLIJ (Rust Terminal Workspace) ---
install_and_demo_zellij() {
    print_header "ZELLIJ (Terminal Workspace)"
    
    # Install zellij
    if install_pacman_package "zellij" || install_cargo_package "zellij"; then
        print_subheader "ZELLIJ Features"
        
        echo "Zellij is a terminal workspace with native multiplexing, tabs, and panes."
        echo "It also provides a plugin system for creating terminal applications."
        
        print_feature "Key Zellij Features:"
        echo " - Terminal multiplexer (like tmux/screen)"
        echo " - Tabs and panes"
        echo " - Session management"
        echo " - Plugin system"
        echo " - Layouts"
        echo " - Floating windows"
        
        print_feature "Basic Zellij Commands:"
        echo " - zellij: Start a new session"
        echo " - zellij attach: Attach to an existing session"
        echo " - zellij ls: List sessions"
        echo " - Ctrl+p: Open command palette"
        
        print_feature "Plugin Framework:"
        echo "Zellij allows you to create custom TUI plugins using Rust or WASM."
        echo "You can create status bars, popups, and other UI elements."
        
        print_feature "Would you like to start a demo Zellij session?"
        if gum confirm "Launch Zellij?"; then
            echo "Starting Zellij. Use Ctrl+p to open command palette. Type 'quit' to exit."
            sleep 2
            zellij
        fi
    else
        print_error "Skipping ZELLIJ demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- REEDLINE (Rust Line Editor) ---
install_and_demo_reedline() {
    print_header "REEDLINE (Rust Line Editor)"
    
    if check_command "cargo"; then
        print_subheader "REEDLINE Features"
        
        echo "Reedline is a line editor for interactive CLI applications in Rust."
        echo "It's similar to GNU Readline but written in Rust."
        
        print_feature "Key Reedline Features:"
        echo " - Command history"
        echo " - Line editing with emacs/vi keybindings"
        echo " - Tab completion"
        echo " - Syntax highlighting"
        echo " - Hinting"
        echo " - Unicode support"
        
        print_feature "Example Code (for your TUI project):"
        echo '```rust'
        echo 'use reedline::{DefaultPrompt, Reedline, Signal};'
        echo ''
        echo 'fn main() -> Result<(), Box<dyn std::error::Error>> {'
        echo '    let mut line_editor = Reedline::create();'
        echo '    let prompt = DefaultPrompt::default();'
        echo ''
        echo '    loop {'
        echo '        let sig = line_editor.read_line(&prompt)?;'
        echo '        match sig {'
        echo '            Signal::Success(line) => {'
        echo '                println!("Line: {}", line);'
        echo '                if line == "exit" {'
        echo '                    break;'
        echo '                }'
        echo '            }'
        echo '            Signal::CtrlD | Signal::CtrlC => {'
        echo '                println!("\nAborted!");'
        echo '                break;'
        echo '            }'
        echo '        }'
        echo '    }'
        echo ''
        echo '    Ok(())'
        echo '}'
        echo '```'
        
        # Note that the Nu shell uses Reedline
        if check_command "nu"; then
            print_feature "Try Reedline in Nu Shell:"
            echo "The Nu shell uses Reedline. Would you like to try it?"
            if gum confirm "Launch Nu Shell?"; then
                nu
            fi
        else
            print_warning "Nu shell (which uses Reedline) is not installed."
            echo "You can install it with: sudo pacman -S nushell"
        fi
    else
        print_error "Rust/Cargo is not installed. Reedline is a Rust library."
        print_warning "Install Rust first to use Reedline in your projects."
    fi
    
    ask_to_continue
}

# --- TEXTUAL (Python TUI Framework) ---
install_and_demo_textual() {
    print_header "TEXTUAL (Python TUI Framework)"
    
    # Install textual
    if install_pip_package "textual"; then
        print_subheader "TEXTUAL Features"
        
        echo "Textual is a modern TUI framework for Python, inspired by web technologies."
        
        print_feature "Key Textual Features:"
        echo " - CSS-like styling system"
        echo " - Widget system with composition"
        echo " - Reactive design pattern"
        echo " - Event handling"
        echo " - Animations"
        echo " - High-level UI components (buttons, inputs, grids, etc.)"
        
        print_feature "Example Code (for your TUI project):"
        echo '```python'
        echo 'from textual.app import App, ComposeResult'
        echo 'from textual.widgets import Header, Footer, Button, Static'
        echo 'from textual.containers import Container'
        echo ''
        echo 'class TextualDemo(App):'
        echo '    CSS = """'
        echo '    Button {'
        echo '        width: 100%;'
        echo '        margin: 1 0;'
        echo '    }'
        echo '    #counter {'
        echo '        content-align: center;'
        echo '        width: 100%;'
        echo '        height: 3;'
        echo '        text-style: bold;'
        echo '    }'
        echo '    """'
        echo ''
        echo '    def __init__(self):'
        echo '        super().__init__()'
        echo '        self.counter = 0'
        echo ''
        echo '    def compose(self) -> ComposeResult:'
        echo '        yield Header()'
        echo '        yield Container('
        echo '            Static(f"Counter: {self.counter}", id="counter"),'
        echo '            Button("Increment", id="increment"),'
        echo '            Button("Decrement", id="decrement"),'
        echo '            Button("Quit", id="quit")'
        echo '        )'
        echo '        yield Footer()'
        echo ''
        echo '    def on_button_pressed(self, event: Button.Pressed) -> None:'
        echo '        if event.button.id == "increment":'
        echo '            self.counter += 1'
        echo '        elif event.button.id == "decrement":'
        echo '            self.counter -= 1'
        echo '        elif event.button.id == "quit":'
        echo '            self.exit()'
        echo ''
        echo '        self.query_one("#counter").update(f"Counter: {self.counter}")'
        echo ''
        echo 'if __name__ == "__main__":'
        echo '    app = TextualDemo()'
        echo '    app.run()'
        echo '```'
        
        # Try to run the textual demo if available
        if check_command "textual"; then
            print_feature "Running Textual Demo:"
            if textual demo --list >/dev/null 2>&1; then
                echo "Available Textual demos:"
                textual demo --list | grep -v "No.*found"
                
                demo=$(textual demo --list | grep -v "No.*found" | head -1 | awk '{print $1}')
                if [[ -n "$demo" ]]; then
                    echo "Running demo: $demo"
                    if gum confirm "Run Textual demo?"; then
                        textual demo "$demo"
                    fi
                fi
            else
                echo "No Textual demos available."
            fi
        fi
    else
        print_error "Skipping TEXTUAL demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- RICH (Python Terminal Formatting) ---
install_and_demo_rich() {
    print_header "RICH (Python Terminal Formatting)"
    
    # Install rich
    if install_pip_package "rich"; then
        print_subheader "RICH Features"
        
        echo "Rich is a Python library for rich text and beautiful formatting in the terminal."
        
        # Create a temporary Python script to demonstrate Rich
        TEMP_PY=$(mktemp --suffix=.py)
        
        cat > "$TEMP_PY" << 'EOL'
from rich import print
from rich.console import Console
from rich.table import Table
from rich.progress import track
from rich.syntax import Syntax
from rich.panel import Panel
from rich.markdown import Markdown
from rich.layout import Layout
from rich.tree import Tree
import time

console = Console()

# Header
console.print("[bold magenta]Rich Demo[/bold magenta]", justify="center")
console.print("A Python library for rich text and beautiful formatting in the terminal.", style="italic")
console.print()

# Styled text
console.print("Rich supports [bold]bold[/bold], [italic]italic[/italic], [underline]underline[/underline], and many other styles.")
console.print("[bold red]Red text[/bold red] and [green]green text[/green] are easy to create.")
console.print()

# Progress bar
console.print("[bold]Progress Bars:[/bold]")
for i in track(range(10), description="Processing..."):
    time.sleep(0.1)
console.print()

# Tables
console.print("[bold]Tables:[/bold]")
table = Table(title="Rich Features")
table.add_column("Feature", style="cyan")
table.add_column("Description", style="magenta")

table.add_row("Styled text", "Apply multiple styles to text")
table.add_row("Tables", "Create beautiful tables")
table.add_row("Progress bars", "Show progress for long-running tasks")
table.add_row("Syntax highlighting", "Highlight code in various languages")
table.add_row("Markdown", "Render markdown in the terminal")
table.add_row("Panels", "Draw boxes around content")
table.add_row("Tree views", "Display hierarchical data")
table.add_row("Layouts", "Create complex layouts")

console.print(table)
console.print()

# Syntax highlighting
console.print("[bold]Syntax Highlighting:[/bold]")
code = '''
def hello_world():
    print("Hello, World!")
    for i in range(10):
        print(f"Count: {i}")
'''
syntax = Syntax(code, "python", theme="monokai", line_numbers=True)
console.print(syntax)
console.print()

# Markdown
console.print("[bold]Markdown Rendering:[/bold]")
markdown = """
# Markdown Example

This is a simple markdown example with:

* Bullet points
* **Bold text**
* *Italic text*

```python
print("Code blocks too!")
```
"""
md = Markdown(markdown)
console.print(md)
console.print()

# Tree view
console.print("[bold]Tree Views:[/bold]")
tree = Tree("Root Directory")
docs = tree.add("Documents")
docs.add("resume.docx")
docs.add("report.pdf")
pictures = tree.add("Pictures")
pictures.add("vacation/")
pictures.add("family.jpg")
pictures.add("cat.png")
console.print(tree)
console.print()

# Panels
console.print("[bold]Panels:[/bold]")
console.print(Panel.fit("Rich makes it easy to add borders around content", title="Panel Example"))
console.print()

# Layout
console.print("[bold]Layouts:[/bold]")
layout = Layout()
layout.split_column(
    Layout(Panel("Header"), size=3),
    Layout(name="main"),
    Layout(Panel("Footer"), size=3)
)
layout["main"].split_row(
    Layout(Panel("Sidebar", style="on blue"), ratio=1),
    Layout(Panel("Content\nWith multiple\nlines of text", title="Main Content"), ratio=3)
)
console.print(layout)
EOL
        
        print_feature "Rich Demo:"
        python3 "$TEMP_PY"
        
        # Cleanup
        rm "$TEMP_PY"
        
        print_feature "Rich is Often Used For:"
        echo " - Beautiful terminal output"
        echo " - Logging with rich formatting"
        echo " - Creating dashboards and monitoring tools"
        echo " - Enhancing CLI applications with professional styling"
        echo " - Textual (shown previously) is built on Rich"
    else
        print_error "Skipping RICH demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- NPYSCREEN (Python Forms Library) ---
install_and_demo_npyscreen() {
    print_header "NPYSCREEN (Python Forms Library)"
    
    # Install npyscreen
    if install_pip_package "npyscreen"; then
        print_subheader "NPYSCREEN Features"
        
        echo "NPyScreen is a Python library for creating form-based applications in terminals."
        
        print_feature "Key NPyScreen Features:"
        echo " - Form-based interface"
        echo " - Widgets: TextBox, MultiLine, TitleText, etc."
        echo " - Multi-page applications"
        echo " - Mouse support"
        echo " - Theming capabilities"
        
        # Create a temporary Python script to demonstrate NPyScreen
        TEMP_PY=$(mktemp --suffix=.py)
        
        cat > "$TEMP_PY" << 'EOL'
#!/usr/bin/env python3
import npyscreen
import curses

class TestForm(npyscreen.Form):
    def create(self):
        self.add(npyscreen.TitleText, name="Text:", value="NPyScreen Demo")
        self.add(npyscreen.TitlePassword, name="Password:")
        self.add(npyscreen.TitleDateCombo, name="Date:")
        self.add(npyscreen.TitleSlider, name="Slider:", out_of=100)
        self.add(npyscreen.MultiLine, 
                 values=["NPyScreen is a Python library", 
                         "for building form-based interfaces",
                         "in terminal applications.",
                         "",
                         "It provides various widgets like:",
                         "- Text fields",
                         "- Selection lists",
                         "- Multi-line editors",
                         "- And more!",
                         "",
                         "Press 'q' to exit this demo."],
                 max_height=10)

class TestApp(npyscreen.NPSAppManaged):
    def onStart(self):
        self.addForm("MAIN", TestForm, name="NPyScreen Demo")

if __name__ == "__main__":
    app = TestApp()
    app.run()
EOL
        
        chmod +x "$TEMP_PY"
        
        print_feature "NPyScreen Demo:"
        echo "Starting NPyScreen demo. Press 'q' to exit."
        sleep 2
        python3 "$TEMP_PY"
        
        # Cleanup
        rm "$TEMP_PY"
        
        print_feature "Example Code (for your TUI project):"
        echo '```python'
        echo 'import npyscreen'
        echo ''
        echo 'class MyForm(npyscreen.Form):'
        echo '    def create(self):'
        echo '        self.name = self.add(npyscreen.TitleText, name="Name:")'
        echo '        self.age = self.add(npyscreen.TitleSlider, name="Age:", out_of=100)'
        echo '        self.occupation = self.add(npyscreen.TitleSelectOne, name="Occupation:", '
        echo '                                  values=["Developer", "Designer", "Manager"], scroll_exit=True)'
        echo ''
        echo 'class MyApp(npyscreen.NPSAppManaged):'
        echo '    def onStart(self):'
        echo '        self.addForm("MAIN", MyForm, name="My Application")'
        echo ''
        echo 'if __name__ == "__main__":'
        echo '    app = MyApp()'
        echo '    app.run()'
        echo '```'
    else
        print_error "Skipping NPYSCREEN demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- URWID (Python Console UI Library) ---
install_and_demo_urwid() {
    print_header "URWID (Python Console UI Library)"
    
    # Install urwid
    if install_pip_package "urwid"; then
        print_subheader "URWID Features"
        
        echo "Urwid is a console user interface library for Python."
        
        print_feature "Key Urwid Features:"
        echo " - Text-based widgets"
        echo " - Support for colors and styles"
        echo " - Input handling"
        echo " - Display resizing"
        echo " - UTF-8 encoding"
        echo " - Fairly low-level but powerful"
        
        # Create a temporary Python script to demonstrate Urwid
        TEMP_PY=$(mktemp --suffix=.py)
        
        cat > "$TEMP_PY" << 'EOL'
#!/usr/bin/env python3
import urwid

def exit_on_q(key):
    if key in ('q', 'Q'):
        raise urwid.ExitMainLoop()

# Create some content
header = urwid.Text(('banner', 'Urwid Demo'), align='center')
subtitle = urwid.Text(('subtitle', 'A Console UI Library for Python'), align='center')

# Create a menu of choices
choices = [
    ('Button', urwid.Button(['Button'])),
    ('CheckBox', urwid.CheckBox('CheckBox')),
    ('RadioButton', urwid.RadioButton([], 'RadioButton')),
    ('Edit', urwid.Edit('Edit: ', 'Editable text')),
    ('IntEdit', urwid.IntEdit('IntEdit: ', 42)),
    ('Text', urwid.Text('Simple Text')),
    ('Divider', urwid.Divider('-')),
]

# Build the menu
content = []
for title, widget in choices:
    content.append(urwid.AttrMap(urwid.Text(f'[{title}]'), None, focus_map='reversed'))
    content.append(widget)
    content.append(urwid.Divider())

# Create a ListBox with all the content
listbox = urwid.ListBox(urwid.SimpleListWalker(content))

# Add a box decoration around the ListBox
box = urwid.LineBox(listbox, title="Widgets Demo")

# Create a Frame with header and box
frame = urwid.Frame(header=urwid.Pile([header, subtitle]), body=box, footer=urwid.Text('Press Q to exit'))

# Define a color palette
palette = [
    ('banner', 'black', 'light gray'),
    ('subtitle', 'dark blue', 'light gray'),
    ('streak', 'black', 'dark red'),
    ('bg', 'black', 'dark blue'),
]

# Create the main loop
loop = urwid.MainLoop(frame, palette=palette, unhandled_input=exit_on_q)

# Run the application
if __name__ == "__main__":
    loop.run()
EOL
        
        chmod +x "$TEMP_PY"
        
        print_feature "Urwid Demo:"
        echo "Starting Urwid demo. Press 'q' to exit."
        sleep 2
        python3 "$TEMP_PY"
        
        # Cleanup
        rm "$TEMP_PY"
        
        print_feature "Example Code (for your TUI project):"
        echo '```python'
        echo 'import urwid'
        echo ''
        echo 'def show_or_exit(key):'
        echo '    if key in ("q", "Q"):'
        echo '        raise urwid.ExitMainLoop()'
        echo '    elif key in ("h", "H"):'
        echo '        txt.set_text("Hello, World!")'
        echo '    elif key in ("c", "C"):'
        echo '        txt.set_text("Goodbye, cruel world!")'
        echo ''
        echo 'txt = urwid.Text("Welcome to Urwid!")'
        echo 'fill = urwid.Filler(txt, "top")'
        echo 'loop = urwid.MainLoop(fill, unhandled_input=show_or_exit)'
        echo 'loop.run()'
        echo '```'
        
        print_feature "Notable Apps Using Urwid:"
        echo " - Wicd (Network Manager)"
        echo " - Bpython (Python Interpreter)"
        echo " - Ranger (File Manager)"
    else
        print_error "Skipping URWID demo due to installation failure"
    fi
    
    ask_to_continue
}

# ====================================
# Main Function
# ====================================

main() {
    print_header "TUI Frameworks Explorer"
    echo "This script will check, install (if needed), and demonstrate features of various TUI/CLI frameworks."
    echo "You can use this to explore options for building your Linux TUI project."
    echo -e "\n${YELLOW}Press Enter to begin...${NC}"
    read -r
    
    # Charmbracelet Tools (CLI UX)
    install_and_demo_gum
    install_and_demo_gumrs
    install_and_demo_fzf
    install_and_demo_whiptail
    install_and_demo_dialog
    install_and_demo_zenity
    install_and_demo_glow
    
    # Charmbracelet Ecosystem (Go)
    install_and_demo_bubbletea
    install_and_demo_lipgloss
    install_and_demo_bubbles
    
    # Rust TUI Frameworks
    install_and_demo_ratatui
    install_and_demo_crossterm
    install_and_demo_zellij
    install_and_demo_reedline
    
    # Python TUI Frameworks
    install_and_demo_textual
    install_and_demo_rich
    install_and_demo_npyscreen
    install_and_demo_urwid
    
    # Summary
    print_header "TUI Frameworks Explorer Summary"
    
    if [[ ${#FAILED_INSTALLS[@]} -gt 0 ]]; then
        print_warning "The following packages failed to install:"
        for pkg in "${FAILED_INSTALLS[@]}"; do
            echo "  - $pkg"
        done
        echo
    fi
    
    echo "Based on the demos, here are some recommendations for your TUI project:"
    echo
    echo "1. For Go-based development:"
    echo "   - BubbleTea + Lipgloss + Bubbles: Comprehensive, modern framework with excellent styling"
    echo "   - Gum: For simpler CLI utilities with beautiful styling"
    echo
    echo "2. For Rust-based development:"
    echo "   - Ratatui + Crossterm: Powerful combination for full TUIs"
    echo "   - Reedline: For command-line applications with readline functionality"
    echo
    echo "3. For Python-based development:"
    echo "   - Textual: Modern, CSS-like styling with powerful widgets"
    echo "   - Rich: Excellent for beautiful output in CLI tools"
    echo "   - Urwid: More traditional but very stable and powerful"
    echo
    echo "4. For shell script-based tools:"
    echo "   - Dialog/Whiptail: Simple form-based interfaces"
    echo "   - FZF: Extremely powerful fuzzy finding"
    echo "   - Gum: Modern CLI components"
    echo
    echo "Consider your language preferences, project complexity, and UI requirements"
    echo "when selecting a framework for your Linux TUI project."
    
    echo -e "\n${GREEN}All demos completed. Happy TUI building!${NC}"
}

# Run the main function
main
}

# --- GUMRS (Rust version of Gum) ---
install_and_demo_gumrs() {
    print_header "GUMRS (Rust version of Gum)"
    
    # Install gumrs using cargo
    if install_cargo_package "gumrs"; then
        print_subheader "GUMRS Features"
        
        echo "GUMRS is a Rust-based implementation similar to GUM."
        
        print_feature "Styled Text:"
        gumrs style --border normal --margin "1" --padding "1 2" "Gumrs provides styled text with borders, margins, and padding"
        
        print_feature "User Input:"
        echo "What's your favorite color? $(gumrs input --placeholder "Enter a color")"
        
        print_feature "Confirmations:"
        if gumrs confirm "Would you like to see more GUMRS features?"; then
            print_feature "Selections:"
            CHOICE=$(gumrs choose "Red" "Green" "Blue")
            echo "You selected: $CHOICE"
            
            print_feature "File Picker:"
            echo "Pick a file: $(gumrs file)"
        fi
    else
        print_error "Skipping GUMRS demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- FZF ---
install_and_demo_fzf() {
    print_header "FZF (Fuzzy Finder)"
    
    # Install fzf
    if install_pacman_package "fzf"; then
        print_subheader "FZF Features"
        
        echo "FZF is a general-purpose command-line fuzzy finder."
        
        print_feature "Basic Fuzzy Finding:"
        echo "Select a fruit:"
        SELECTION=$(echo -e "Apple\nBanana\nCherry\nDate\nElderberry" | fzf --height 10)
        echo "You selected: $SELECTION"
        
        print_feature "Multi-selection (press TAB to select multiple items):"
        echo "Select multiple fruits:"
        SELECTIONS=$(echo -e "Apple\nBanana\nCherry\nDate\nElderberry" | fzf --multi --height 10)
        echo "You selected: $SELECTIONS"
        
        print_feature "Finding Files:"
        echo "Select a file (Press ESC to cancel):"
        FILE=$(find . -type f | fzf --preview 'cat {}' --height 20)
        if [[ -n "$FILE" ]]; then
            echo "You selected: $FILE"
        else
            echo "No file selected"
        fi
        
        print_feature "History Search:"
        echo "Search command history (Press ESC to cancel):"
        CMD=$(history | cut -c 8- | fzf --height 10)
        if [[ -n "$CMD" ]]; then
            echo "Command selected: $CMD"
        else
            echo "No command selected"
        fi
    else
        print_error "Skipping FZF demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- WHIPTAIL ---
install_and_demo_whiptail() {
    print_header "WHIPTAIL"
    
    # Install whiptail
    if install_pacman_package "libnewt"; then
        print_subheader "WHIPTAIL Features"
        
        echo "WHIPTAIL is a dialog-like program with a more compact interface."
        
        print_feature "Message Box:"
        whiptail --title "Message Box" --msgbox "This is a simple message box." 10 60
        
        print_feature "Yes/No Box:"
        if whiptail --title "Question" --yesno "Would you like to see more WHIPTAIL features?" 10 60; then
            print_feature "Input Box:"
            NAME=$(whiptail --title "Input Box" --inputbox "What is your name?" 10 60 3>&1 1>&2 2>&3)
            echo "Hello, $NAME!"
            
            print_feature "Password Box:"
            echo "Enter a password (it won't be saved):"
            PASS=$(whiptail --title "Password" --passwordbox "Enter a password:" 10 60 3>&1 1>&2 2>&3)
            echo "Password entered (length: ${#PASS} characters)"
            
            print_feature "Menu Box:"
            OPTION=$(whiptail --title "Menu" --menu "Choose an option:" 15 60 4 \
                "1" "Option 1" \
                "2" "Option 2" \
                "3" "Option 3" 3>&1 1>&2 2>&3)
            echo "You selected option: $OPTION"
            
            print_feature "Checklist (Multi-select):"
            SELECTIONS=$(whiptail --title "Checklist" --checklist "Choose items:" 15 60 4 \
                "1" "Item 1" OFF \
                "2" "Item 2" ON \
                "3" "Item 3" OFF \
                "4" "Item 4" OFF 3>&1 1>&2 2>&3)
            echo "You selected: $SELECTIONS"
            
            print_feature "Radio List (Single Select):"
            SELECTION=$(whiptail --title "Radio List" --radiolist "Choose one item:" 15 60 4 \
                "1" "Item 1" OFF \
                "2" "Item 2" ON \
                "3" "Item 3" OFF \
                "4" "Item 4" OFF 3>&1 1>&2 2>&3)
            echo "You selected: $SELECTION"
            
            print_feature "Gauge (Progress Bar):"
            {
                for i in {1..100}; do
                    echo "$i"
                    sleep 0.02
                done
            } | whiptail --gauge "Progress:" 6 50 0
        fi
    else
        print_error "Skipping WHIPTAIL demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- DIALOG ---
install_and_demo_dialog() {
    print_header "DIALOG"
    
    # Install dialog
    if install_pacman_package "dialog"; then
        print_subheader "DIALOG Features"
        
        echo "DIALOG is a program that allows you to build nice user interfaces using dialog boxes."
        
        print_feature "Message Box:"
        dialog --title "Message Box" --msgbox "This is a simple message box." 10 60
        
        print_feature "Yes/No Box:"
        if dialog --title "Question" --yesno "Would you like to see more DIALOG features?" 10 60; then
            print_feature "Input Box:"
            NAME=$(dialog --title "Input Box" --inputbox "What is your name?" 10 60 2>&1 >/dev/tty)
            echo "Hello, $NAME!"
            
            print_feature "Password Box:"
            echo "Enter a password (it won't be saved):"
            PASS=$(dialog --title "Password" --passwordbox "Enter a password:" 10 60 2>&1 >/dev/tty)
            echo "Password entered (length: ${#PASS} characters)"
            
            print_feature "Menu Box:"
            OPTION=$(dialog --title "Menu" --menu "Choose an option:" 15 60 4 \
                "1" "Option 1" \
                "2" "Option 2" \
                "3" "Option 3" 2>&1 >/dev/tty)
            echo "You selected option: $OPTION"
            
            print_feature "Checklist (Multi-select):"
            SELECTIONS=$(dialog --title "Checklist" --checklist "Choose items:" 15 60 4 \
                "1" "Item 1" off \
                "2" "Item 2" on \
                "3" "Item 3" off \
                "4" "Item 4" off 2>&1 >/dev/tty)
            echo "You selected: $SELECTIONS"
            
            print_feature "Calendar:"
            DATE=$(dialog --title "Calendar" --calendar "Choose a date:" 0 0 2>&1 >/dev/tty)
            echo "Selected date: $DATE"
            
            print_feature "File Selection:"
            FILE=$(dialog --title "File Selection" --fselect "$HOME/" 10 60 2>&1 >/dev/tty)
            echo "Selected file: $FILE"
        fi
        
        clear  # Clear the screen after dialog
    else
        print_error "Skipping DIALOG demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- ZENITY ---
install_and_demo_zenity() {
    print_header "ZENITY (GTK Dialog)"
    
    # Install zenity
    if install_pacman_package "zenity"; then
        print_subheader "ZENITY Features"
        
        echo "ZENITY creates GTK+ dialogs from command line or shell scripts."
        
        print_feature "Info Dialog:"
        zenity --info --title="Info" --text="This is an information dialog." --width=300
        
        print_feature "Question Dialog:"
        if zenity --question --title="Question" --text="Would you like to see more ZENITY features?" --width=300; then
            print_feature "Entry Dialog (Input):"
            NAME=$(zenity --entry --title="Entry" --text="Enter your name:" --width=300)
            echo "Hello, $NAME!"
            
            print_feature "Password Dialog:"
            PASS=$(zenity --entry --title="Password" --text="Enter a password:" --hide-text --width=300)
            echo "Password entered (length: ${#PASS} characters)"
            
            print_feature "List Dialog:"
            SELECTION=$(zenity --list --title="List" --text="Choose an option:" --column="Option" --column="Description" \
                "1" "Option 1" \
                "2" "Option 2" \
                "3" "Option 3" --width=400 --height=300)
            echo "You selected: $SELECTION"
            
            print_feature "Check List (Multi-select):"
            SELECTIONS=$(zenity --list --title="Check List" --text="Choose items:" --column="Select" --column="Option" --column="Description" \
                TRUE "1" "Item 1" \
                FALSE "2" "Item 2" \
                FALSE "3" "Item 3" \
                FALSE "4" "Item 4" --checklist --width=400 --height=300)
            echo "You selected: $SELECTIONS"
            
            print_feature "Calendar:"
            DATE=$(zenity --calendar --title="Calendar" --text="Choose a date:" --width=300)
            echo "Selected date: $DATE"
            
            print_feature "File Selection:"
            FILE=$(zenity --file-selection --title="Choose a file")
            echo "Selected file: $FILE"
            
            print_feature "Color Selection:"
            COLOR=$(zenity --color-selection --title="Choose a color")
            echo "Selected color: $COLOR"
        fi
    else
        print_error "Skipping ZENITY demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- GLOW (Markdown Terminal Viewer) ---
install_and_demo_glow() {
    print_header "GLOW (Markdown Terminal Viewer)"
    
    # Install glow
    if install_pacman_package "glow"; then
        print_subheader "GLOW Features"
        
        echo "GLOW is a terminal based markdown reader by Charmbracelet."
        
        print_feature "Markdown Rendering:"
        # Create a temporary markdown file
        TEMP_MD=$(mktemp --suffix=.md)
        
        # Write some markdown content
        cat > "$TEMP_MD" << 'EOL'
# Glow Markdown Example

This is a *demonstration* of **Glow**, a terminal markdown viewer.

## Features

- Syntax highlighting
- Support for tables
- Lists (like this one!)
- Images (ASCII art in terminal)
- Support for multiple styles/themes

### Code Example

```python
def hello_world():
    print("Hello, World!")
    return True
```

| Feature | Description |
|---------|-------------|
| Styling | Apply different themes |
| Paging  | Scroll through content |
| Search  | Find text in document |

> Glow makes reading documentation, READMEs, and other markdown content enjoyable in the terminal.
EOL
        
        # Display the markdown file
        glow "$TEMP_MD"
        
        print_feature "Available Styles:"
        echo "Glow supports different styles:"
        glow --style help
        
        print_feature "Directory Mode:"
        echo "Glow can browse and render markdown files in a directory"
        
        # Cleanup
        rm "$TEMP_MD"
    else
        print_error "Skipping GLOW demo due to installation failure"
    fi
    
    ask_to_continue
}

# --- BUBBLETEA (Go TUI Framework) ---
install_and_demo_bubbletea() {
    print_header "BUBBLETEA (Charmbracelet TUI Framework)"
    
    # Bubbletea is a library, not a command, so we'll just check if Go is installed
    # and then show examples of what can be built with it
    if check_command "go"; then
        print_subheader "BUBBLETEA Features"
        
        echo "BubbleTea is a powerful Go framework for building terminal user interfaces."
        echo "It's a library rather than a standalone tool, so we'll showcase examples that use it."
        
        # Check if either soft or bubble is installed
        local bubbletea_demo
        if check_command "soft"; then
            bubbletea_demo="soft"
        elif check_command "bubble"; then
            bubbletea_demo="bubble"
        elif check_command "bubbletea"; then
            bubbletea_demo="bubbletea"
        else
            print_warning "No BubbleTea demo apps found. Installing a simple one..."
            # Install a simple bubbletea example app
            if go install github.com/charmbracelet/bubbletea/examples/basics@latest; then
                export PATH="$PATH:$(go env GOPATH)/bin"
                bubbletea_demo="basics"
                print_success "Installed BubbleTea example app"
            else
                print_error "Failed to install BubbleTea example app"
            fi
        fi
        
        if [[ -n "$bubbletea_demo" ]]; then
            print_feature "Running a BubbleTea demo ($bubbletea_demo):"
            echo "Press 'q' to quit the demo when done."
            sleep 2
            "$bubbletea_demo"
        fi
        
        print_feature "Key BubbleTea Framework Features:"
        echo " - Event-based architecture with a Model-View-Update (Elm-like) pattern"
        echo " - Powerful component system"
        echo " - Keyboard and mouse input handling"
        echo " - Built-in support for viewport management, tables, spinners, etc."
        echo " - Can be combined with Lipgloss for styling and Bubbles for common components"
        
        print_feature "Common Applications Built with BubbleTea:"
        echo " - 'soft': Softserve - A self-hosted Git server for the command line"
        echo " - 'gum': Command-line tool for shell scripts"
        echo " - 'charm': Charm Cloud CLI (https://charm.sh)"
        echo " - 'vhs': Tool for recording terminal GIFs"
        echo " - 'mods.sh': AI tools for the terminal"
    else
        print_error "Go is not installed. BubbleTea is a Go framework."
        print_warning "Install Go first to use BubbleTea in your projects."
    fi
    
    ask_to_continue
}

# --- LIPGLOSS (Go Terminal Styling) ---
install_and_demo_lipgloss() {
    print_header "LIPGLOSS (Charmbracelet Terminal Styling)"
    
    if check_command "go"; then
        print_subheader "LIPGLOSS Features"
        
        echo "Lipgloss is a Go library for styling terminal applications."
        echo "It works well with BubbleTea for creating styled TUIs."
        
        print_feature "Key Lipgloss Features:"
        echo " - Declarative API for styling text"
        echo " - Support for borders, margins, and padding"
        echo " - Flexbox-like layouts"
        echo " - Color management (including 24-bit color)"
        echo " - Style composition and reuse"
        
        print_feature "Example Code (for your TUI project):"
        echo '```go'
        echo 'import "github.com/charmbracelet/lipgloss"'
        echo ''
        echo '// Define styles'
        echo 'var ('
        echo '    titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#FAFAFA"))'
        echo '    infoStyle  = lipgloss.NewStyle().Italic(true).Foreground(lipgloss.Color("#AAAAAA"))'
        echo '    errorStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF0000"))'
        echo '    boxStyle   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(1).BorderForeground(lipgloss.Color("#33CCFF"))'
        echo ')'
        echo ''
        echo '// Use styles'
        echo 'func main() {'
        echo '    title := titleStyle.Render("My Terminal App")'
        echo '    info := infoStyle.Render("Version 1.0.0")'
        echo '    content := "This is styled with Lipgloss"'
        echo '    styledBox := boxStyle.Render(content)'
        echo '    
        echo '    // Join the elements together'
        echo '    ui := lipgloss.JoinVertical(lipgloss.Center, title, info, styledBox)'
        echo '    fmt.Println(ui)'
        echo '}'
        echo '```'
        
        print_feature "Lipgloss UI Examples:"
        echo " - Borders, padding, margins"
        echo " - Layout management (horizontal/vertical joining)"
        echo " - Style inheritance and composition"
        echo " - Responsive designs that adapt to terminal width"
    else
        print_error "Go is not installed. Lipgloss is a Go library."
        print_warning "Install Go first to use Lipgloss in your projects."
    fi
    
    ask_to_continue
}
