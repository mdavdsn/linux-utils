#!/bin/bash

# WebP Converter Script
# Converts PNG, TIF, BMP, and JPG files to WebP format
# Usage: ./webp_converter.sh [directory] [quality]

# Function to display usage
show_usage() {
    echo "Usage: $0 [directory] [quality]"
    echo ""
    echo "Arguments:"
    echo "  directory  - Directory containing images to convert (default: current directory)"
    echo "  quality    - WebP compression quality 0-100 (default: 80)"
    echo ""
    echo "Supported formats: PNG, TIF, BMP, JPG, JPEG"
    echo ""
    echo "Examples:"
    echo "  $0                    # Convert files in current directory with quality 80"
    echo "  $0 ./images           # Convert files in ./images directory with quality 80"
    echo "  $0 ./images 90        # Convert files in ./images directory with quality 90"
}

# Check if cwebp is installed
if ! command -v cwebp &> /dev/null; then
    echo "Error: cwebp command not found!"
    echo "Please install WebP tools first."
    echo "Ubuntu/Debian: sudo apt-get install webp"
    echo "macOS: brew install webp"
    exit 1
fi

# Set directory (default to current directory)
DIRECTORY="${1:-.}"

# Handle quality parameter
if [ -n "$2" ]; then
    QUALITY="$2"
else
    echo "Enter WebP compression quality (0-100, default is 80):"
    read -p "Quality [80]: " input_quality
    QUALITY="${input_quality:-80}"
fi

# Validate directory
if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory '$DIRECTORY' does not exist!"
    show_usage
    exit 1
fi

# Validate quality parameter
if ! [[ "$QUALITY" =~ ^[0-9]+$ ]] || [ "$QUALITY" -lt 0 ] || [ "$QUALITY" -gt 100 ]; then
    echo "Error: Quality must be a number between 0 and 100!"
    show_usage
    exit 1
fi

echo "Converting images in directory: $DIRECTORY"
echo "WebP quality setting: $QUALITY"
echo "----------------------------------------"

# Counter for converted files
converted_count=0
skipped_count=0
overwrite_all=false

# Function to prompt user for overwrite decision
prompt_overwrite() {
    local filename="$1"
    local output_file="$2"

    # If overwrite_all is set, return true
    if [ "$overwrite_all" = true ]; then
        return 0
    fi

    echo ""
    echo "WebP file already exists: $(basename "$output_file")"
    echo "Options:"
    echo "  [y] Yes, overwrite this file"
    echo "  [n] No, skip this file"
    echo "  [a] Yes to all (overwrite all existing WebP files)"
    echo "  [q] Quit the script"
    echo ""

    while true; do
        read -p "What would you like to do? [y/n/a/q]: " choice </dev/tty
        case $choice in
            [Yy]* )
                return 0  # Overwrite this file
                ;;
            [Nn]* )
                return 1  # Skip this file
                ;;
            [Aa]* )
                overwrite_all=true
                return 0  # Overwrite this file and all future ones
                ;;
            [Qq]* )
                echo "Script terminated by user."
                exit 0
                ;;
            * )
                echo "Please answer y (yes), n (no), a (yes to all), or q (quit)."
                ;;
        esac
    done
}

# Function to convert a single file
convert_file() {
    local input_file="$1"
    local filename=$(basename "$input_file")
    local name_without_ext="${filename%.*}"
    local output_file="$DIRECTORY/$name_without_ext.webp"

    # Check if output file already exists
    if [ -f "$output_file" ]; then
        if prompt_overwrite "$filename" "$output_file"; then
            echo "Overwriting: $filename -> $name_without_ext.webp"
        else
            echo "Skipping: $filename (keeping existing WebP file)"
            ((skipped_count++))
            return
        fi
    fi

    echo "Converting: $filename -> $name_without_ext.webp"

    if cwebp -q "$QUALITY" "$input_file" -o "$output_file" 2>/dev/null; then
        ((converted_count++))

        # Show file size comparison
        original_size=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file" 2>/dev/null)
        webp_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)

        if [ -n "$original_size" ] && [ -n "$webp_size" ]; then
            reduction=$(( (original_size - webp_size) * 100 / original_size ))
            echo "  Size reduction: $reduction% ($(numfmt --to=iec "$original_size") -> $(numfmt --to=iec "$webp_size"))"
        fi
    else
        echo "  Error: Failed to convert $filename"
    fi
}

# Find and convert supported image files
# Using case-insensitive matching for extensions
while IFS= read -r -d '' file; do
    convert_file "$file"
done < <(find "$DIRECTORY" -maxdepth 1 -type f \( \
    -iname "*.png" -o \
    -iname "*.tif" -o \
    -iname "*.tiff" -o \
    -iname "*.bmp" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" \
\) -print0)

echo "----------------------------------------"
echo "Conversion complete!"
echo "Files converted: $converted_count"
echo "Files skipped: $skipped_count"

# Show total files processed
total_files=$(find "$DIRECTORY" -maxdepth 1 -type f \( \
    -iname "*.png" -o \
    -iname "*.tif" -o \
    -iname "*.tiff" -o \
    -iname "*.bmp" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" \
\) | wc -l)

echo "Total image files found: $total_files"

# Show overwrite mode if it was used
if [ "$overwrite_all" = true ]; then
    echo "Mode: Overwrite all was selected"
fi
