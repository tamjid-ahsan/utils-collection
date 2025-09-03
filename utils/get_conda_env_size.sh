#!/bin/bash

# Function to check if Conda is installed
check_conda_installed() {
    if ! command -v conda &>/dev/null; then
        echo "Error: Conda is not installed or not in PATH. Please install Conda first."
        exit 1
    fi
}

# Function to get the size of a Conda environment
get_env_size() {
    local env_path=$1
    if [ -d "$env_path" ]; then
        du -sh "$env_path" | awk '{print $1}'
    else
        echo "0"
    fi
}

# Function to calculate and display sizes of all Conda environments
calculate_all_env_sizes() {
    local total_size_bytes=0
    echo "Calculating sizes for all Conda environments..."
    echo ""

    # Loop through all environments and calculate sizes
    while IFS= read -r env_line; do
        env_name=$(echo "$env_line" | awk '{print $1}')
        env_path=$(echo "$env_line" | awk '{print $NF}')
        if [ -d "$env_path" ]; then
            size=$(get_env_size "$env_path")
            echo "Size of environment '$env_name': $size"
            # Add to total size (in bytes)
            size_in_kb=$(du -sk "$env_path" | awk '{print $1}')
            total_size_bytes=$((total_size_bytes + size_in_kb))
        fi
    done < <(conda env list | grep -v "#" | grep -v "^$")

    # Convert total size from KB to human-readable format
    total_size_human=$(echo "$total_size_bytes" | awk '{
        split("K M G T", units)
        for (i = 1; bytes >= 1024 && i < 5; i++) bytes /= 1024;
        printf "%.2f%s\n", bytes, units[i]
    }' bytes="$total_size_bytes")
    
    echo ""
    echo "Total size of all Conda environments: $total_size_human"
}

# Function to display Conda information
display_conda_info() {
    echo "Fetching Conda information..."
    conda info
    echo ""
}

# Main script execution
check_conda_installed

# Check if --info flag is provided
show_info=false
if [[ "$1" == "--info" ]]; then
    show_info=true
fi

# If --info is set, display Conda information
if $show_info; then
    display_conda_info
fi

echo "Available Conda environments:"
conda env list

# Prompt user to select an environment
echo ""
read -p "Enter the name of the Conda environment (or 'ALL' to calculate for all environments): " env_name

if [ "$env_name" == "ALL" ]; then
    # Calculate and display sizes for all environments
    calculate_all_env_sizes
else
    # Get the path of the selected environment
    env_path=$(conda env list | grep -w "$env_name" | awk '{print $NF}')
    if [ -z "$env_path" ]; then
        echo "Error: Environment '$env_name' not found!"
        exit 1
    fi
    # Get the size of the environment
    echo "Calculating size for environment: $env_name"
    du -sh "$env_path"
fi