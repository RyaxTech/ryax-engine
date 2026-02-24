#!/usr/bin/env bash

# For debug
# set -x
set -e
set -u

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <output_directory>"
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT_DIR="$2"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
MERGED_DEPS=$OUTPUT_DIR/requirements.txt
rm -rf $MERGED_DEPS

# Find all requirements.txt files recursively
echo "Found requirements.txt files:"
for req_file in $(find "$SOURCE_DIR" -name "requirements.txt")
do
    echo "# START $req_file" >> $MERGED_DEPS
    cat $req_file >> $MERGED_DEPS
    # Add an empty line to avoid format issue
    echo "" >> $MERGED_DEPS
    echo "# END $req_file" >> $MERGED_DEPS
done

# Download each package as a tarball
while read package; do
    # Skip empty lines and comments
    if [[ -z "$package" || "$package" == \#* ]]; then
        continue
    fi

    # TODO add support for ryax.lock 
    echo "Downloading $package..."
    pip download --dest "$OUTPUT_DIR" "$package"
done < <(cat $MERGED_DEPS | sort | uniq )

echo "All packages downloaded to $OUTPUT_DIR"
