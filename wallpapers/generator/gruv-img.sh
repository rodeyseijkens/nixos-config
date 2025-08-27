#!/usr/bin/env bash

set -euo pipefail

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PALETTE="mix"
METHOD="remap"
IMAGES=()
PALETTE_COLORS=()
VIBRANCE_ADJUSTMENT=100
BRIGHTNESS_ADJUSTMENT=0
CONTRAST_ADJUSTMENT=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Signal handler for SIGINT
cleanup() {
    echo -e "\n${RED}Process interrupted${NC}"
    exit 2
}
trap cleanup SIGINT

# Check if ImageMagick is installed
check_dependencies() {
    if ! command -v magick &> /dev/null; then
        print_color "$RED" "ImageMagick is not installed. Please install it first:"
        echo "  Ubuntu/Debian: sudo apt-get install imagemagick"
        echo "  macOS: brew install imagemagick"
        echo "  Arch: sudo pacman -S imagemagick"
        exit 1
    fi
}

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Print title
print_title() {
    echo -e "${YELLOW}================================${NC}"
    echo -e "${BOLD}${GREEN}Gruvbox Image${NC}"
    echo -e "${YELLOW}================================${NC}"
}

# Show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

A simple cli to manufacture Gruvbox themed wallpapers.

Options:
    -p, --palette PALETTE   Choose your palette: 'black', 'white', or 'mix' (default: mix)
    -m, --method METHOD     Processing method: 'remap' or 'quantize' (default: remap)
    -i, --images IMAGES     Path(s) to the image(s) (space-separated)
    -v, --vibrance VALUE    Vibrance adjustment (default: 100, range: 0-200)
    -b, --brightness VALUE  Brightness adjustment (default: 0, range: -100 to 100)
    -c, --contrast VALUE    Contrast adjustment (default: 0, range: -100 to 100)
    -h, --help             Show this help message

Methods:
    remap     - Color remapping with Floyd-Steinberg dithering (best quality)
    quantize  - Color quantization with palette matching (balanced)

Examples:
    $0 -p black -m remap -i image1.jpg image2.png
    $0 --palette white --method quantize --images *.jpg
    $0 -i image.jpg -v 120 -b 10 -c 15
EOF
}

# Validate palette
is_valid_palette() {
    local palette="$1"
    case "$palette" in
        black|white|mix) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate method
is_valid_method() {
    local method="$1"
    case "$method" in
        remap|quantize) return 0 ;;
        *) return 1 ;;
    esac
}

# Load palette colors from file
load_palette() {
    local palette="$1"
    local palette_file="$SCRIPT_DIR/palette-$palette.txt"
    
    if [[ ! -f "$palette_file" ]]; then
        print_color "$RED" "Palette file $palette_file not found."
        exit 1
    fi
    
    # Read colors from file into array
    PALETTE_COLORS=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Ensure color starts with #
        if [[ ! "$line" =~ ^# ]]; then
            line="#$line"
        fi

        # Validate hex color format (3 or 6 digits after #)
        if [[ "$line" =~ ^#[0-9a-fA-F]{3}$ || "$line" =~ ^#[0-9a-fA-F]{6}$ ]]; then
            PALETTE_COLORS+=("$line")
        else
            print_color "$YELLOW" "Skipping invalid color format: $line"
        fi
    done < "$palette_file"

    if [[ ${#PALETTE_COLORS[@]} -eq 0 ]]; then
        print_color "$RED" "No valid colors found in palette file $palette_file"
        print_color "$YELLOW" "Expected format: one hex color per line (e.g., #282828 or 282828)"
        exit 1
    fi
    
    print_color "$GREEN" "Loaded palette: $palette (${#PALETTE_COLORS[@]} colors)"
}

# Create temporary palette image
create_temp_palette_image() {
    local temp_palette="$1"
    
    # Construct the ImageMagick command to create the palette image dynamically
    local palette_string=""
    for color in "${PALETTE_COLORS[@]}"; do
        palette_string="${palette_string} xc:${color}"
    done
    
    # Create the temporary palette image
    if ! magick $palette_string +append "$temp_palette" 2>/dev/null; then
        print_color "$RED" "Failed to create color palette"
        return 1
    fi
    
    return 0
}

# Process image with remap method
process_image_remap() {
    local image_path="$1"
    local output_path="$2"
    local temp_palette="$3"
    
    magick "$image_path" \
        -modulate "100,${VIBRANCE_ADJUSTMENT},100" \
        -brightness-contrast "${BRIGHTNESS_ADJUSTMENT}%,${CONTRAST_ADJUSTMENT}%" \
        -dither FloydSteinberg \
        -remap "$temp_palette" \
        "$output_path" 2>/dev/null
}

# Process image with quantize method
process_image_quantize() {
    local image_path="$1"
    local output_path="$2"
    local temp_palette="$3"
    
    magick "$image_path" \
        -modulate "100,${VIBRANCE_ADJUSTMENT},100" \
        -brightness-contrast "${BRIGHTNESS_ADJUSTMENT}%,${CONTRAST_ADJUSTMENT}%" \
        -colors ${#PALETTE_COLORS[@]} \
        -colorspace RGB \
        -dither FloydSteinberg \
        "$output_path" 2>/dev/null && \
    magick "$output_path" \
        -remap "$temp_palette" \
        "$output_path" 2>/dev/null
}

# Process a single image with specified method
process_image() {
    local image_path="$1"
    local dir="$(dirname "$image_path")"
    local filename="$(basename "$image_path")"
    local name="${filename%.*}"
    local ext="${filename##*.}"
    local output_path="$SCRIPT_DIR/$name.$ext"
    
    if [[ ! -f "$image_path" ]]; then
        print_color "$RED" "Skipping $image_path (file not found)"
        return 1
    fi
    
    print_color "$YELLOW" "Creating '$filename' -> $(basename "$output_path") [method: $METHOD]"
    
    local temp_palette=$(mktemp --suffix=.png)
    
    # Create a palette image from our colors
    if ! create_temp_palette_image "$temp_palette"; then
        rm -f "$temp_palette"
        return 1
    fi
    
    # Process image based on selected method
    local success=false
    case "$METHOD" in
        remap)
            if process_image_remap "$image_path" "$output_path" "$temp_palette"; then
                success=true
            fi
            ;;
        quantize)
            if process_image_quantize "$image_path" "$output_path" "$temp_palette"; then
                success=true
            fi
            ;;
    esac
    
    rm -f "$temp_palette"
    
    if [[ "$success" == true ]]; then
        print_color "$GREEN" "Done! (saved to '$(basename "$output_path")')"
        return 0
    else
        print_color "$RED" "Failed to process $image_path with method '$METHOD'"
        return 1
    fi
}

# Process all images
process_images() {
    local images=("$@")
    local failed=0
    local passed=0
    
    for image in "${images[@]}"; do
        if process_image "$image"; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        print_color "$GREEN" "All images processed successfully!"
        return 0
    elif [[ $failed -gt 0 && $passed -gt 0 ]]; then
        print_color "$YELLOW" "Some images processed successfully!"
        return 0
    else
        print_color "$RED" "Couldn't process any images"
        return 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--palette)
                if [[ -n "${2:-}" ]] && is_valid_palette "$2"; then
                    PALETTE="$2"
                    shift 2
                else
                    print_color "$RED" "Error: Invalid or missing palette argument"
                    exit 1
                fi
                ;;
            -m|--method)
                if [[ -n "${2:-}" ]] && is_valid_method "$2"; then
                    METHOD="$2"
                    shift 2
                else
                    print_color "$RED" "Error: Invalid or missing method argument"
                    exit 1
                fi
                ;;
            -i|--images)
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    IMAGES+=("$1")
                    shift
                done
                ;;
            -v|--vibrance)
                if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    VIBRANCE_ADJUSTMENT="$2"
                    shift 2
                else
                    print_color "$RED" "Error: Invalid or missing vibrance value"
                    exit 1
                fi
                ;;
            -b|--brightness)
                if [[ -n "${2:-}" ]] && [[ "$2" =~ ^-?[0-9]+$ ]]; then
                    BRIGHTNESS_ADJUSTMENT="$2"
                    shift 2
                else
                    print_color "$RED" "Error: Invalid or missing brightness value"
                    exit 1
                fi
                ;;
            -c|--contrast)
                if [[ -n "${2:-}" ]] && [[ "$2" =~ ^-?[0-9]+$ ]]; then
                    CONTRAST_ADJUSTMENT="$2"
                    shift 2
                else
                    print_color "$RED" "Error: Invalid or missing contrast value"
                    exit 1
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_color "$RED" "Error: Unknown option $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    print_title
    
    # Check dependencies
    check_dependencies
    
    # Parse arguments
    parse_args "$@"
    
    # Show help if no arguments
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    # Load palette
    load_palette "$PALETTE"
    
    # Validate we have images
    if [[ ${#IMAGES[@]} -eq 0 ]]; then
        print_color "$RED" "Error: No valid images provided"
        exit 1
    fi
    
    # Process images
    if ! process_images "${IMAGES[@]}"; then
        exit 1
    fi
    
    exit 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi