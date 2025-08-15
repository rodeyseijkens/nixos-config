#!/usr/bin/env bash

# commit-gen.sh - Generate commit messages using llm command     
# Uses Conventional Commits format with gitmoji and scopes

set -euo pipefail

# Ensure we're in a proper terminal for interactive prompts
if [[ -t 0 && -t 2 ]]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
HELP=false
PRINT_ONLY=false
DEBUG=false
STAGED=false
AUTO_COMMIT=false
WORKSPACE=""
MODEL=""

# Functions
show_help() {
    cat << EOF
commit-gen.sh - Generate commit messages using llm command

USAGE:
    commit-gen.sh [OPTIONS]

OPTIONS:
    -h, --help        Show this help message
    -m, --model       Specify the model to use with llm command (default: uses llm's configured default)
    -p, --print       Print the generated message only (no commit, no prompts)
    -D, --debug       Show verbose output
    -s, --staged      Analyze staged changes only
    -c, --commit      Automatically commit without confirmation
    -w, --workspace   Specify workspace/scope for commit message (e.g., -w frontend)

EXAMPLES:
    commit-gen.sh                    # Interactive mode - analyze all changes by default
    commit-gen.sh -s                 # Analyze staged changes only
    commit-gen.sh -c                 # Automatically commit all changes
    commit-gen.sh -c -s              # Automatically commit staged changes only
    commit-gen.sh -p                 # Print message only for all changes
    commit-gen.sh -p -s              # Print message only for staged changes
    commit-gen.sh -D                 # Debug mode for all changes
    commit-gen.sh -w frontend        # Use 'frontend' as scope for all changes
    commit-gen.sh -m claude-3-haiku  # Use claude-3-haiku model instead of default

FORMAT:
    Generated commits follow Conventional Commits with gitmoji and scopes:
    feat(walker): :sparkles: added walker wallpaper plugin & use repo for wallpapers
    refactor: :art: improve formatting of device and menu titles
    chore: :memo: update readme and screenshot

REQUIREMENTS:
    - git
    - llm command (https://github.com/simonw/llm)
EOF
}

debug_log() {
    if [[ "$DEBUG" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

error_exit() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

info_inline() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2
    printf "" >&2  # Indent to align with [INFO]
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

highlight() {
    echo -e "${YELLOW}$1${NC}"
}

# Spinner function for loading indicator
show_spinner() {
    local pid=$1
    local message="$2"
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    # Show initial message using info_inline function
    info_inline "$message"
    
    while kill -0 $pid 2>/dev/null; do
        printf "\b%s" "${spinner_chars:$i:1}" >&2
        i=$(( (i + 1) % ${#spinner_chars} ))
        sleep 0.1
    done
    
    # Just clear the spinner, no completion symbol needed
    printf "\b \b" >&2  # Backspace, space to clear, backspace again
    printf "\n" >&2     # New line for clean output
}

check_requirements() {
    debug_log "Checking requirements..."
    
    if ! command -v git &> /dev/null; then
        error_exit "git is not installed or not in PATH"
    fi
    
    # Check for llm command
    if ! command -v llm &> /dev/null; then
        error_exit "llm command is not available. Install it from:
  - https://github.com/simonw/llm
  - pip install llm"
    fi
    
    debug_log "All requirements satisfied, using llm command$(if [[ -n "$MODEL" ]]; then echo " with model: $MODEL"; else echo " with default model"; fi)"
}

check_git_repo() {
    debug_log "Checking if we're in a git repository..."
    
    if ! git rev-parse --git-dir &> /dev/null; then
        error_exit "Not in a git repository"
    fi
    
    debug_log "Git repository detected"
}

get_changes() {
    local change_type="$1"
    debug_log "Getting $change_type changes..."
    
    local diff_output
    if [[ "$change_type" == "staged" ]]; then
        diff_output=$(git diff --cached)
        if [[ -z "$diff_output" ]]; then
            error_exit "No staged changes found. Run 'git add <files>' first."
        fi
    else
        # For "all" changes, check unstaged first, then staged, then untracked
        diff_output=$(git diff)
        if [[ -z "$diff_output" ]]; then
            debug_log "No unstaged changes found, checking for staged changes..."
            diff_output=$(git diff --cached)
            if [[ -z "$diff_output" ]]; then
                debug_log "No staged changes found, checking for untracked files..."
                local untracked_files
                untracked_files=$(git ls-files --others --exclude-standard)
                if [[ -n "$untracked_files" ]]; then
                    debug_log "Found untracked files, generating diff for them"
                    # Create a diff-like output for untracked files
                    diff_output=""
                    while IFS= read -r file; do
                        if [[ -n "$file" ]]; then
                            diff_output+="diff --git a/$file b/$file
new file mode 100644
index 0000000..$(git hash-object "$file" 2>/dev/null || echo "unknown")
--- /dev/null
+++ b/$file
$(cat "$file" | sed 's/^/+/')

"
                        fi
                    done <<< "$untracked_files"
                else
                    error_exit "No changes found. Either make changes, add files, or run 'git add <files>' to stage changes."
                fi
            else
                debug_log "Found staged changes instead of unstaged, using staged changes"
                change_type="staged"
            fi
        fi
    fi
    
    debug_log "Found $change_type changes (${#diff_output} characters)"
    echo "$diff_output"
}

choose_scope() {
    if [[ -n "$WORKSPACE" ]]; then
        echo "$WORKSPACE"
        return
    fi
    
    if [[ "$INTERACTIVE" == true ]]; then
        printf "\nEnter a scope for this commit (optional, press Enter for no scope):\n" >&2
    fi
    
    local scope
    read -p "Scope: " scope
    
    # Trim whitespace
    scope=$(echo "$scope" | xargs)
    
    debug_log "Selected scope: '$scope'"
    echo "$scope"
}

generate_commit_message() {
    local changes="$1"
    debug_log "Generating commit message using llm$(if [[ -n "$MODEL" ]]; then echo " with model: $MODEL"; else echo " with default model"; fi)"
    
    # Determine scope
    local scope=""
    if [[ "$PRINT_ONLY" == true ]] || [[ "$AUTO_COMMIT" == true ]]; then
        # For print-only or auto-commit mode, use provided workspace or empty
        scope="$WORKSPACE"
        debug_log "Non-interactive mode, using workspace scope: '$scope'"
    else
        scope=$(choose_scope)
        debug_log "Using selected scope: '$scope'"
    fi
    
    # Build scope part of the prompt
    local scope_instruction=""
    if [[ -n "$scope" ]]; then
        scope_instruction="- Use scope ($scope) for this commit"
    else
        scope_instruction="- Do not include a scope for this commit"
    fi
    
    local prompt="Generate a commit message for the following git diff following the Conventional Commits specification STRICTLY.

REQUIRED FORMAT: <type>[optional scope]: <description>

RULES (MUST follow):
1. Commits MUST be prefixed with a type (feat, fix, docs, style, refactor, test, chore, etc.)
2. Type MUST be followed by OPTIONAL scope in parentheses, then REQUIRED colon and space
3. Description MUST immediately follow the colon and space
4. Description MUST be a short summary of code changes
5. Use present tense imperitive (add, fix, update - NOT added, fixed, updated)
6. Description should start with lowercase letter
7. Include gitmoji after the colon and space, before description

TYPES (use appropriate one):
- feat: new feature
- fix: bug fix  
- docs: documentation changes
- style: formatting, missing semicolons, etc (no code change)
- refactor: code change that neither fixes bug nor adds feature
- test: adding or correcting tests
- chore: updating build tasks, package manager configs, etc

SCOPE GUIDANCE:
$scope_instruction

EXAMPLES:
- feat(walker): :sparkles: add wallpaper plugin support
- fix(hyprland): :bug: resolve window focus issue  
- docs: :memo: update installation instructions
- refactor(nixos): :recycle: improve module organization
- chore: :wrench: update dependencies

Only return the commit message, nothing else.

Git diff:
$changes"
    
    local commit_message
    if [[ "$PRINT_ONLY" == false ]] && [[ "$INTERACTIVE" == true ]]; then
        # Show spinner for interactive mode (not for print-only)
        
        # Create a temporary file to store the result
        local temp_file=$(mktemp)
        local temp_error=$(mktemp)
        
        # Run llm command in background
        if [[ -n "$MODEL" ]]; then
            (echo "$prompt" | llm -m "$MODEL" 2>"$temp_error" > "$temp_file") &
        else
            (echo "$prompt" | llm 2>"$temp_error" > "$temp_file") &
        fi
        local llm_pid=$!
        
        # Show spinner while waiting
        show_spinner $llm_pid "Generating commit message using llm$(if [[ -n "$MODEL" ]]; then echo " (model: $MODEL)"; fi)"
        
        # Wait for completion
        wait $llm_pid
        local exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            local error_msg=$(cat "$temp_error" 2>/dev/null || echo "Unknown error")
            rm -f "$temp_file" "$temp_error"
            error_exit "Failed to generate commit message with llm$(if [[ -n "$MODEL" ]]; then echo " (model: $MODEL)"; fi): $error_msg"
        fi
        
        # Get the result
        commit_message=$(cat "$temp_file")
        rm -f "$temp_file" "$temp_error"
    else
        # For print-only or non-interactive mode, run without spinner
        if [[ -n "$MODEL" ]]; then
            if ! commit_message=$(echo "$prompt" | llm -m "$MODEL" 2>/dev/null); then
                error_exit "Failed to generate commit message with llm (model: $MODEL)"
            fi
        else
            if ! commit_message=$(echo "$prompt" | llm 2>/dev/null); then
                error_exit "Failed to generate commit message with llm"
            fi
        fi
    fi
    
    # Clean up the message (remove any extra whitespace/newlines)
    commit_message=$(echo "$commit_message" | xargs)
    
    if [[ -z "$commit_message" ]]; then
        error_exit "Generated commit message is empty"
    fi
    
    debug_log "Generated commit message"
    echo "$commit_message"
}

choose_change_type() {
    if [[ "$STAGED" == true ]]; then
        echo "staged"
    else
        if [[ "$INTERACTIVE" == true ]]; then
            printf "\nAnalyze all changes (Y/n): " >&2
        fi
        
        local choice
        read choice
        
        # Default to "all" if empty or yes
        case $choice in
            [Nn]|[Nn][Oo]) echo "staged" ;;
            *) echo "all" ;;
        esac
    fi
}

confirm_commit() {
    local message="$1"
    
    if [[ "$INTERACTIVE" == true ]]; then
        printf "\n" >&2
        success "Generated commit message:" >&2
        highlight "$message" >&2
        printf "\n" >&2
    fi
    
    local confirm
    read -p "Do you want to commit with this message? [Y/n]: " confirm
    
    case $confirm in
        [Nn]|[Nn][Oo]) return 1 ;;
        *) return 0 ;;  # Default to yes for empty input or anything else
    esac
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                HELP=true
                shift
                ;;
            -m|--model)
                if [[ -n "${2-}" && "${2-}" != -* ]]; then
                    MODEL="$2"
                    shift 2
                else
                    error_exit "Option $1 requires a value (e.g., -m gpt-4)"
                fi
                ;;
            -p|--print)
                PRINT_ONLY=true
                shift
                ;;
            -D|--debug)
                DEBUG=true
                shift
                ;;
            -s|--staged)
                STAGED=true
                shift
                ;;
            -c|--commit)
                AUTO_COMMIT=true
                shift
                ;;
            -w|--workspace)
                if [[ -n "${2-}" && "${2-}" != -* ]]; then
                    WORKSPACE="$2"
                    shift 2
                else
                    error_exit "Option $1 requires a value (e.g., -w frontend)"
                fi
                ;;
            *)
                error_exit "Unknown option: $1. Use -h or --help for usage information."
                ;;
        esac
    done
    
    if [[ "$HELP" == true ]]; then
        show_help
        exit 0
    fi
    
    debug_log "Starting commit-gen.sh..."
    debug_log "Flags: MODEL='$MODEL', PRINT_ONLY=$PRINT_ONLY, DEBUG=$DEBUG, STAGED=$STAGED, AUTO_COMMIT=$AUTO_COMMIT, WORKSPACE='$WORKSPACE'"
    
    check_requirements
    check_git_repo
    
    # Determine what changes to analyze
    local change_type
    if [[ "$PRINT_ONLY" == true ]]; then
        # For print-only mode, default to all if no staged flag
        if [[ "$STAGED" == false ]]; then
            change_type="all"
        else
            change_type="staged"
        fi
    elif [[ "$AUTO_COMMIT" == true ]]; then
        # For auto-commit mode, default to all if no staged flag
        if [[ "$STAGED" == false ]]; then
            change_type="all"
        else
            change_type="staged"
        fi
    else
        change_type=$(choose_change_type)
    fi
    
    debug_log "Analyzing $change_type changes"
    
    # Get changes and generate message
    local changes
    changes=$(get_changes "$change_type")
    
    local commit_message
    commit_message=$(generate_commit_message "$changes")
    
    if [[ "$PRINT_ONLY" == true ]]; then
        echo "$commit_message"
        exit 0
    fi
    
    # Confirm and commit
    if [[ "$AUTO_COMMIT" == true ]] || confirm_commit "$commit_message"; then
        debug_log "Committing..."
        
        if [[ "$change_type" == "all" ]]; then
            debug_log "Adding all changes for commit"
            git add .
        fi
        
        if git commit -m "$commit_message"; then
            printf "\n" >&2
            info "Successfully committed with message"
        else
            error_exit "Failed to commit changes"
        fi
    else
        info "Commit cancelled by user"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
