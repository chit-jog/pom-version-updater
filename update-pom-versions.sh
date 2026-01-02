#!/bin/bash

# Get the script's directory (not the lib directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/functions.sh"

# =====================================================================================================================
# Main execution
# =====================================================================================================================

printWelcomeMessage

# Check prerequisites
checkPrerequisites
if [ $? -ne 0 ]; then
    echo -e "${RED}Prerequisites check failed. Please install missing tools.${RESET}"
    exit 1
fi

# Get parameters
echo -e "${YELLOW}Note: For 'folder name', just enter a simple name like 'temp_repos'${RESET}"
echo -e "${YELLOW}      (Don't enter a full path)${RESET}"
echo ""
getParameters

# Check if repos.txt exists
REPOS_FILE="$SCRIPT_DIR/repos.txt"
if [ ! -f "$REPOS_FILE" ]; then
    echo -e "${RED}repos.txt file not found!${RESET}"
    echo -e "${YELLOW}Creating a sample repos.txt file...${RESET}"
    cat > "$REPOS_FILE" << EOF
# List your repository names here (one per line)
# Lines starting with # are ignored
# Example:
# repo-name-1
# repo-name-2
# repo-name-3
EOF
    echo -e "${GREEN}Sample repos.txt created. Please edit it and add your repository names.${RESET}"
    exit 1
fi

# Read repositories
echo -e "${BLUE}Reading repositories from repos.txt...${RESET}"
echo "DEBUG: REPOS_FILE=$REPOS_FILE"
repos=()
while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ ! -z "$line" ]] && [[ ! "$line" =~ ^# ]]; then
        echo "DEBUG: Adding repo: [$line]"
        repos+=("$line")
    fi
done < "$REPOS_FILE"

echo "DEBUG: Total repos found: ${#repos[@]}"
if [ ${#repos[@]} -eq 0 ]; then
    echo -e "${RED}No repositories found in repos.txt${RESET}"
    exit 1
fi

echo -e "${GREEN}Found ${#repos[@]} repository/repositories to process${RESET}"
echo ""

# Confirm before proceeding
read -p "Do you want to proceed? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo -e "${YELLOW}Operation cancelled${RESET}"
    exit 0
fi

# Process each repository
success_count=0
failed_count=0
skipped_count=0

for i in "${!repos[@]}"; do
    repo_name="${repos[$i]}"
    current=$((i + 1))
    total=${#repos[@]}
    
    echo ""
    echo -e "${GREEN}===============================================================================${RESET}"
    echo -e "${GREEN}[$current/$total] Processing: $repo_name${RESET}"
    echo -e "${GREEN}===============================================================================${RESET}"
    
    processRepository "$repo_name"
    result=$?
    
    if [ $result -eq 0 ]; then
        ((success_count++))
    else
        ((failed_count++))
    fi
done

# Print summary
echo ""
echo -e "${GREEN}===============================================================================${RESET}"
echo -e "${GREEN}                              SUMMARY${RESET}"
echo -e "${GREEN}===============================================================================${RESET}"
echo -e "Total repositories: ${#repos[@]}"
echo -e "${GREEN}✓ Successful: $success_count${RESET}"
echo -e "${RED}✗ Failed: $failed_count${RESET}"
echo -e "${GREEN}===============================================================================${RESET}"
echo ""

# Cleanup option
read -p "Do you want to cleanup cloned repositories? (y/n): " cleanup
if [ "$cleanup" == "y" ] || [ "$cleanup" == "Y" ]; then
    echo -e "${BLUE}Cleaning up...${RESET}"
    rm -rf "$FOLDER_NAME"
    echo -e "${GREEN}✓ Cleanup complete${RESET}"
fi

echo -e "${GREEN}Done! Thank you for using POM Version Updater${RESET}"

# Made with Bob
