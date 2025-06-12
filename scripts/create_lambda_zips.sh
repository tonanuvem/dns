#!/bin/bash

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Create lambda_zip directory if it doesn't exist
mkdir -p lambda_zip

# Function to create zip file
create_zip() {
    local function_name=$1
    local source_file=$2
    
    echo "Creating zip for $function_name..."
    
    # Create function directory
    mkdir -p "$TEMP_DIR/$function_name"
    
    # Copy source file
    cp "$source_file" "$TEMP_DIR/$function_name/lambda_function.py"
    
    # Install dependencies
    pip install -r requirements.txt -t "$TEMP_DIR/$function_name"
    
    # Create zip file
    cd "$TEMP_DIR/$function_name"
    zip -r "../../lambda_zip/${function_name}.zip" .
    cd - > /dev/null
    
    echo "Created ${function_name}.zip"
}

# Create zip for gerenciador_dns function
create_zip "gerenciador_dns" "lambda/gerenciador_dns.py"

# Clean up
rm -rf "$TEMP_DIR"
echo "Cleaned up temporary directory" 