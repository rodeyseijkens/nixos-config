#!/usr/bin/env bash
# gen-commit.sh - Generate commit messages using llm command
# Uses Conventional Commits format with gitmoji and scopes
set -euo pipefail

# ---------------------------------------------------------------------------
# Colour & messaging helpers
# ---------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly WHITE='\033[0;37m'
readonly NC='\033[0m'

print_color() {
  local colour=$1; shift
  printf '%b%s%b\n' "$colour" "$*" "$NC"
}

print_message() {
  local type=$1; shift
  case "$type" in
    error) print_color "$RED"   "[ERROR] $*"   >&2 ;;
    info)  print_color "$BLUE"   "[INFO] $*"   >&2 ;;
    warn)  print_color "$YELLOW" "[WARN] $*"   >&2 ;;
    success) print_color "$GREEN" "󰗠 $*"   >&2 ;;
    normal) print_color "$WHITE" "$*"   >&2 ;;
  esac
}

print_debug() {
  if [[ "${DEBUG:-false}" == true || "${VERBOSE:-false}" == true ]]; then
    print_message info "$*"
  fi
}
error_exit()  { print_message error "$1"; exit 1; }


# ---------------------------------------------------------------------------
# Help message
# ---------------------------------------------------------------------------
show_help() {
  cat <<EOF
gen-commit.sh - Generate commit messages using llm command
USAGE:
    gen-commit.sh [OPTIONS]
OPTIONS:
    -h, --help        Show this help message
    -m, --model       Specify the model to use with llm command
    -p, --print       Print the generated message only
    -D, --debug       Special debug mode (no real committing etc.)
    -v, --verbose     Show all output
    -s, --staged      Analyze staged changes only
    -c, --commit      Automatically commit without confirmation
    -w, --workspace   Specify workspace/scope for commit message
EXAMPLES:
    gen-commit.sh                    # Interactive mode
    gen-commit.sh -s                 # Staged changes only
    gen-commit.sh -c -s              # Auto-commit staged
    gen-commit.sh -p                 # Print only
    gen-commit.sh -w frontend        # Use 'frontend' scope

REQUIRED TOOLS:
    git           https://git-scm.com
    llm           https://github.com/simonw/llm
EOF
}

# ---------------------------------------------------------------------------
# Spinner helper
# ---------------------------------------------------------------------------
run_with_spinner() {
  local msg=$1; shift
  local cmd=("$@")

  local tmp_out tmp_err
  tmp_out=$(mktemp)
  tmp_err=$(mktemp)

  # shellcheck disable=SC2068
  "${cmd[@]}" >"$tmp_out" 2>"$tmp_err" &
  local pid=$!

  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  print_message normal "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    printf '\b%s' "${spin:i:1}" >&2
    i=$(((i + 1) % ${#spin}))
    sleep 0.1
  done
  printf '\b \b' >&2
  wait "$pid"
  local ec=$?

  cat "$tmp_out"
  cat "$tmp_err" >&2
  rm -f "$tmp_out" "$tmp_err"
  return "$ec"
}

# ---------------------------------------------------------------------------
# LLM wrapper
# ---------------------------------------------------------------------------
run_llm() {
  if [[ "${DEBUG:-false}" == true ]]; then
    echo "fake(debug): :clown_face: fake llm message"
  elif [[ -n "${MODEL:-}" ]]; then
    llm -m "$MODEL"
  else
    llm
  fi
}

# ---------------------------------------------------------------------------
# Change detection
# ---------------------------------------------------------------------------
outline_or_preview() {
  local file="$1"
  # [TODO] Make a tree-sitter outline for $file
  # if command -v tree-sitter >/dev/null 2>&1; then
  #   tree-sitter "$file"
  # else
  #   printf '=== %s (outline unavailable) ===\n' "$file"
  #   head -n 10 "$file"
  #   echo "..."
  #   tail -n 5 "$file"
  # fi
  
  head -n 10 "$file"
  echo "..."
  tail -n 5 "$file"
}

get_changes() {
  local mode="${1:-all}"
  local diff_out="" untracked_out=""

  # Diff for tracked changes
  case "$mode" in
    staged)
      diff_out=$(git diff --cached --unified=3 --no-color --minimal)
      ;;
    unstaged)
      diff_out=$(git diff --unified=3 --no-color --minimal)
      ;;
    all)
      diff_out=$(git diff HEAD --unified=3 --no-color --minimal)
      ;;
    *) echo "Usage: get_changes [all|staged|unstaged]" >&2; return 1 ;;
  esac

  # Untracked files (outline only)
  if [[ "$mode" == "all" || "$mode" == "unstaged" ]]; then
    local file
    while IFS= read -r -d '' file; do
      untracked_out+=$'\n'"Untracked file: $(realpath --relative-to="$(git rev-parse --show-toplevel)" "$file")"$'\n'
      untracked_out+=$(outline_or_preview "$file")
    done < <(git ls-files --others --exclude-standard -z)
  fi

  # Combine & trim
  local out="${diff_out}${untracked_out}"
  [[ -z "${out//[$'\n\t ']}" ]] && return 1
  echo "$out" | sed '/^[[:space:]]*$/d'
}

# ---------------------------------------------------------------------------
# Utility checks
# ---------------------------------------------------------------------------
check_requirements() {
  print_debug "Checking requirements..."
  command -v git  >/dev/null || error_exit "git is not installed."
  command -v llm >/dev/null || error_exit "llm command not found. Install from https://github.com/simonw/llm"
  # [TODO] command -v tree-sitter >/dev/null || error_exit "tree-sitter command not found. Install from https://tree-sitter.github.io"
  print_debug "All requirements satisfied."
}

check_git_repo() {
  print_debug "Checking if we're in a git repository..."
  git rev-parse --git-dir >/dev/null || error_exit "Not in a git repository."
  print_debug "Git repository detected."
}

# ---------------------------------------------------------------------------
# Commit message generation
# ---------------------------------------------------------------------------
generate_commit_message() {
  local changes=$1 scope=$2
  local scope_instruction
  if [[ -n "$scope" ]]; then
    scope_instruction="- Use scope ($scope)"
  else
    scope_instruction="- Do not include a scope, unless obvious from full context"
  fi

  local prompt="Generate a Conventional Commit message for this diff.

Format: <type>[scope]: <gitmoji> <description>

Rules:
- type: feat|fix|docs|style|refactor|test|chore
- description: present tense, lowercase, ≤50 chars
- use correct gitmoji
- only return the commit message
$scope_instruction

Examples:
feat(walker): ✨ add wallpaper plugin
fix(hyprland): 🐛 resolve focus bug
docs: 📝 update install guide

Diff:
$changes"

  print_debug "Changes preview: ${changes}"

  local cmd=(run_llm)
  local msg
  if [[ "${SHOW_SPINNER:-false}" == true ]]; then
    msg=$(echo "$prompt" | run_with_spinner "Generating commit message " "${cmd[@]}")
  else
    msg=$(echo "$prompt" | "${cmd[@]}")
  fi
  echo "$msg" | xargs
}

# ---------------------------------------------------------------------------
# Interactive helpers
# ---------------------------------------------------------------------------
choose_scope() {
  # If workspace is already provided, use it
  [[ -n "$WORKSPACE" ]] && { echo "$WORKSPACE"; return; }
  
  # Only prompt if we're in interactive mode
  [[ "$INTERACTIVE" != true ]] && { echo ""; return; }
  
  printf '\nEnter a scope for this commit (optional, press Enter for no scope):\n' >&2
  local scope
  read -r -p "Scope: " scope
  echo "$scope" | xargs
}

confirm_commit() {
  local msg=$1
  [[ "$DEBUG" == true ]] && return 1 # No commit on debug mode
  [[ "$AUTO_COMMIT" == true ]] && return 0
  print_color "$YELLOW" "$msg"
  local c
  read -r -p "Do you want to commit with this message? [Y/n]: " c
  [[ "$c" =~ ^[Nn] ]] && return 1
  return 0
}

# ---------------------------------------------------------------------------
# Option parsing
# ---------------------------------------------------------------------------
OPTS=$(getopt -o hm:pDscvw: --long help,model:,print,debug,staged,commit,verbose,workspace: -n "$0" -- "$@")
eval set -- "$OPTS"

HELP=false
PRINT_ONLY=false
DEBUG=false
VERBOSE=false
STAGED=false
AUTO_COMMIT=false
WORKSPACE="" 
MODEL=""

while true; do
  case "$1" in
    -h|--help) HELP=true; shift ;;
    -m|--model) MODEL=$2; shift 2 ;;
    -p|--print) PRINT_ONLY=true; shift ;;
    -D|--debug) DEBUG=true; shift ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -s|--staged) STAGED=true; shift ;;
    -c|--commit) AUTO_COMMIT=true; shift ;;
    -w|--workspace) WORKSPACE=$2; shift 2 ;;
    --) shift; break ;;
    *) error_exit "Internal error while parsing options" ;;
  esac
done

[[ "$HELP" == true ]] && { show_help; exit 0; }

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------
main() {
  print_debug "Starting..."
  
  # Determine if we should be interactive
  INTERACTIVE=false
  if [[ "$AUTO_COMMIT" != true || -z "$WORKSPACE" ]]; then
    INTERACTIVE=true
  fi
  
  # Show spinner only in interactive mode
  [[ "$PRINT_ONLY" != true ]] && SHOW_SPINNER=true

  print_debug "Flags: MODEL='$MODEL', STAGED=$STAGED, AUTO_COMMIT=$AUTO_COMMIT, WORKSPACE='$WORKSPACE', PRINT_ONLY=$PRINT_ONLY, INTERACTIVE=$INTERACTIVE"

  check_requirements
  check_git_repo

  # Determine mode (all changes vs staged only)
  local mode="all"
  if [[ "$STAGED" == true ]]; then
    mode="staged"
  elif [[ "$INTERACTIVE" == true ]]; then
    local choice
    read -r -p "Analyze all changes (Y/n): " choice
    [[ "$choice" =~ ^[Nn] ]] && mode="staged"
  fi

  local needs_add=false changes
  if changes=$(get_changes "$mode"); then
    [[ "$mode" != "staged" ]] && needs_add=true
  else
    error_exit "No changes detected."
  fi

  local scope
  scope=$(choose_scope)
  print_debug "Scope: '$scope'"

  # Generate message
  local message
  message=$(generate_commit_message "$changes" "$scope")
  [[ "$PRINT_ONLY" == true ]] && { echo "$message"; exit 0; }
  print_message success "Generated commit message"
  print_debug "Generated message: $message"

  # Add changes if needed
  if [[ "$needs_add" == true && "$DEBUG" == false ]]; then
    print_debug "Adding changes..."
    git add -A
  fi

  # Commit
  if [[ "$AUTO_COMMIT" == true ]]; then
    git commit -m "$message"
    print_message success "Committed"
  else
    if confirm_commit "$message"; then
      git commit -m "$message"
      print_message success "Committed"
    else
      print_message warn "Aborted by user"
      exit 0
    fi
  fi
}

main "$@"