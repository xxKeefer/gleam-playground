#!/bin/bash

# Path to the .env file
ENV_FILE=".env"

# Check if the .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "$ENV_FILE not found!"
    exit 1
fi

# Export variables from the .env file
set -a # Automatically export all variables
source "$ENV_FILE"
set +a # Stop automatically exporting

echo "Environment variables from $ENV_FILE have been set."
