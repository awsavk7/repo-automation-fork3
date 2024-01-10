#!/bin/bash

# Artifactory server URL
ARTIFACTORY_URL="https://vminds.jfrog.io/artifactory"

# Artifactory username and password (replace with your credentials)
USERNAME="avardhineni4@gmail.com"
API_KEY="AKCpBrvkRp4gkkQ3BtVzZPNh8pGnZfGEhn411GUeatAKHPRExdgPZVxgU2YRTsUsCLNzRBRso"

# Set the path to the new input file
input_file="/Repository-Inputs.txt"

# Read the repository inputs from the specified file
REPO_NAME=$(grep -m 1 "New Repository Name:" "$input_file" | cut -d ':' -f 2 | tr -d ' ' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
PACKAGE_TYPE=$(grep -o "Package Type: [[:alnum:]]*" "$input_file" | cut -d ' ' -f 3)
RCLASS=$(grep -m 1 "Type of Repository:" "$input_file" | cut -d ':' -f 2 | tr '[:upper:]' '[:lower:]' | tr -d ' ')
URL=$(grep "URL:" "$input_file" | cut -d ' ' -f 2)
repository_poc=$(grep "Repository POC:" "$input_file" | cut -d ':' -f 2 | sed 's/,$//' | sed 's/^ *//')
INCLUSION_RULES=$(grep "Inclusion Rules:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')
EXCLUSION_RULES=$(grep "Exclusion Rules:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')
REPOSITORIES=$(grep "Repositories:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')
DEFAULT_LOCAL_REPO=$(grep "Default Local Repo:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')

# Convert the comma-separated list to an array
IFS=',' read -ra REPO_ARRAY <<< "$REPOSITORIES"

# Create a JSON-friendly string for repositories
# REPO_LIST=$(IFS=, ; echo "${REPO_ARRAY[*]}")

# JSON payload for repository creation with the extracted information
REPO_JSON='{
  "key": "'"$REPO_NAME"'",
  "rclass": "'"$RCLASS"'",
  "url": "'"$URL"'",
  "packageType": "'"$PACKAGE_TYPE"'",
  "description": "'"$repository_poc"'",
  "includesPattern": "'"$INCLUSION_RULES"'",
  "excludesPattern": "'"$EXCLUSION_RULES"'",
  "repositories": '"$(printf '%s\n' "${REPO_ARRAY[@]}" | jq -R -s -c 'split("\n")[:-1]')"',
  "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'"
}'

echo "JSON Payload: $REPO_JSON"
# Function to create a local repository using the Artifactory REST API
create_repo() {
  local response
  response=$(curl -u "$USERNAME:$API_KEY" -X PUT -H "Content-Type: application/json" \
    "$ARTIFACTORY_URL/api/repositories/$REPO_NAME" -d "$REPO_JSON"
  )
  if [[ $response == *"error"* ]]; then
    echo "Error creating repository: $response"
    exit 1  # Exit the script if repository creation fails
  else
    echo "Repository '$REPO_NAME' created successfully."
    # Check if the repository class is "local" and set the storage quota
    if [ "$RCLASS" == "local" ]; then
      quota_response=$(curl -u "$USERNAME:$API_KEY" -X PUT "$ARTIFACTORY_URL/api/storage/$REPO_NAME?properties=repository.path.quota=107374182400")
      if [[ $quota_response == *"error"* ]]; then
        echo "Error setting storage quota for the local repository: $quota_response"
      else
        echo "Storage quota set for the local repository '$REPO_NAME'."
      fi
    fi
  fi
}

# Main script execution
create_repo  # Attempt to create the repository