#!/bin/bash

# Color definitions
export GREEN='\033[1;92m'  # Bright/Bold Green
export RED='\033[1;31m'     # Bright/Bold Red
export YELLOW='\033[1;33m'  # Bright/Bold Yellow
export BLUE='\033[1;34m'    # Bright/Bold Blue
export RESET='\033[0m'      # Reset to default color

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =====================================================================================================================
# Print a message header
# =====================================================================================================================
function printHeader() {
    local message="$1"
    local length=${#message}
    local border=$(printf '%*s' "$length" | tr ' ' '-')

    echo -e "${GREEN}"
    echo -e "--${border}--"
    echo -e "| ${message} |"
    echo -e "--${border}--"
    echo -e "${RESET}"
}

# =====================================================================================================================
# Print welcome message
# =====================================================================================================================
function printWelcomeMessage() {
    echo -e "${GREEN}"
    echo -e "==============================================================================="
    echo -e ""
    echo -e "                    POM Version Updater - WIoTP Team"
    echo -e ""
    echo -e "  This script will help you update Maven version ranges to fixed versions"
    echo -e "  across multiple repositories for Renovate compatibility."
    echo -e ""
    echo -e "  Before we get rolling, make sure you have:"
    echo -e ""
    echo -e "    - GitHub Personal Access Token (set as GITHUB_TOKEN env variable)"
    echo -e "    - Python 3 installed (for XML parsing)"
    echo -e "    - Git configured with your credentials"
    echo -e "    - repos.txt file with repository names"
    echo -e ""
    echo -e "  Ready Dev? Let's get started!"
    echo -e ""
    echo -e "==============================================================================="
    echo -e "${RESET}"
}

# =====================================================================================================================
# Get runtime parameters
# =====================================================================================================================
function getParameters() {
    read -p "Enter organization name [wiotp]: " ORG_NAME
    ORG_NAME=${ORG_NAME:-wiotp}
    
    read -p "Enter folder name to store cloned repos [temp_repos]: " FOLDER_NAME
    FOLDER_NAME=${FOLDER_NAME:-temp_repos}
    
    # Validate folder name - should not be a path
    if [[ "$FOLDER_NAME" == *"/"* ]]; then
        echo -e "${RED}Error: Folder name should not contain '/' (don't use full paths)${RESET}"
        echo -e "${YELLOW}Please use a simple name like 'temp_repos' or 'cloned_repos'${RESET}"
        exit 1
    fi
    
    read -p "Enter branch name [feature/update-pom-versions]: " BRANCH_NAME
    BRANCH_NAME=${BRANCH_NAME:-feature/update-pom-versions}
    
    read -p "Enter Jira Issue (e.g., WIOTP-1234): " JIRA_ISSUE
    
    # Ask about version mappings file
    echo -e ""
    echo -e "${BLUE}Do you want to use a saved version mappings file?${RESET}"
    echo -e "  (This allows you to reuse the same versions across multiple repos)"
    read -p "Use saved mappings? (y/n) [n]: " USE_MAPPINGS
    USE_MAPPINGS=${USE_MAPPINGS:-n}
    
    if [ "$USE_MAPPINGS" == "y" ] || [ "$USE_MAPPINGS" == "Y" ]; then
        read -p "Enter mappings file path [version-mappings.txt]: " MAPPINGS_FILE
        MAPPINGS_FILE=${MAPPINGS_FILE:-version-mappings.txt}
        
        if [ ! -f "$MAPPINGS_FILE" ]; then
            echo -e "${YELLOW}Warning: File $MAPPINGS_FILE not found. Will prompt for versions.${RESET}"
            USE_MAPPINGS="n"
        else
            echo -e "${GREEN}✓ Will use mappings from: $MAPPINGS_FILE${RESET}"
        fi
    else
        MAPPINGS_FILE=""
    fi
    
    echo -e ""
    echo -e "---------------------------------------------------------------"
    echo "Organization: $ORG_NAME"
    echo "Folder: $FOLDER_NAME"
    echo "Branch: $BRANCH_NAME"
    echo "Jira Issue: $JIRA_ISSUE"
    if [ "$USE_MAPPINGS" == "y" ]; then
        echo "Version Mappings: $MAPPINGS_FILE"
    fi
    echo -e "---------------------------------------------------------------"
    echo -e ""
    
    mkdir -p "$FOLDER_NAME"
    
    export ORG_NAME
    export FOLDER_NAME
    export BRANCH_NAME
    export JIRA_ISSUE
    export USE_MAPPINGS
    export MAPPINGS_FILE
}

# =====================================================================================================================
# Load version mappings from file
# =====================================================================================================================
function loadVersionMappings() {
    local mappings_file="$1"
    local temp_file=$(mktemp)
    
    if [ ! -f "$mappings_file" ]; then
        return 1
    fi
    
    # Read mappings file and convert to temp format
    while IFS='=' read -r dependency version; do
        # Skip comments and empty lines
        if [[ "$dependency" =~ ^#.*$ ]] || [ -z "$dependency" ]; then
            continue
        fi
        echo "${dependency}=${version}" >> "$temp_file"
    done < "$mappings_file"
    
    echo "$temp_file"
}

# =====================================================================================================================
# Save version mappings to file
# =====================================================================================================================
function saveVersionMappings() {
    local temp_mappings="$1"
    local output_file="version-mappings.txt"
    
    if [ ! -f "$temp_mappings" ] || [ ! -s "$temp_mappings" ]; then
        return
    fi
    
    echo -e "${BLUE}Saving version mappings for reuse...${RESET}"
    
    # Create header
    cat > "$output_file" << EOF
# Version Mappings File
# Generated: $(date)
# Format: groupId:artifactId:versionRange=fixedVersion
#
# You can reuse this file for other repositories with the same dependencies
# Edit this file to change versions, then use it with --use-mappings option
#
EOF
    
    # Append mappings
    while IFS='=' read -r key value; do
        echo "${key}=${value}" >> "$output_file"
    done < "$temp_mappings"
    
    echo -e "${GREEN}✓ Saved version mappings to: $output_file${RESET}"
    echo -e "${YELLOW}  You can reuse this file for other repos!${RESET}"
}

# =====================================================================================================================
# Clone a GitHub repository
# =====================================================================================================================
function cloneRepo() {
    local repo_name="$1"
    
    printHeader "Cloning $repo_name..."
    
    # Create folder if it doesn't exist
    mkdir -p "$FOLDER_NAME"
    
    # Remove existing clone if present
    if [ -d "$FOLDER_NAME/$repo_name" ]; then
        echo -e "${YELLOW}Repository already exists, removing...${RESET}"
        rm -rf "$FOLDER_NAME/$repo_name"
    fi
    
    # Clone into the folder
    git clone "git@github.ibm.com:${ORG_NAME}/${repo_name}.git" "$FOLDER_NAME/$repo_name"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to clone repository: ${repo_name}${RESET}"
        return 1
    fi
    
    cd "$FOLDER_NAME/$repo_name"
    return 0
}

# =====================================================================================================================
# Find version ranges in pom.xml files using Python
# =====================================================================================================================
function findVersionRanges() {
    local repo_path="$1"
    
    echo -e "${BLUE}Scanning for version ranges...${RESET}"
    
    # Use Python to parse XML and find version ranges
    python3 - <<EOF
import os
import re
import xml.etree.ElementTree as ET

def find_pom_files(repo_path):
    pom_files = []
    for root, dirs, files in os.walk(repo_path):
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['target', 'node_modules']]
        if 'pom.xml' in files:
            pom_files.append(os.path.join(root, 'pom.xml'))
    return pom_files

def extract_version_ranges(pom_path):
    ranges = []
    version_range_pattern = re.compile(r'[\[\(]\s*[\d.]+\s*,\s*[\d.]+\s*[\]\)]')
    
    try:
        tree = ET.parse(pom_path)
        root = tree.getroot()
        ns = {'maven': 'http://maven.apache.org/POM/4.0.0'}
        if not root.tag.startswith('{'):
            ns = {}
        
        for dep in root.findall('.//dependency' if not ns else './/maven:dependency', ns):
            group_elem = dep.find('groupId' if not ns else 'maven:groupId', ns)
            artifact_elem = dep.find('artifactId' if not ns else 'maven:artifactId', ns)
            version_elem = dep.find('version' if not ns else 'maven:version', ns)
            
            if version_elem is not None and version_elem.text:
                version_text = version_elem.text.strip()
                if version_range_pattern.match(version_text):
                    group_id = group_elem.text.strip() if group_elem is not None and group_elem.text else 'unknown'
                    artifact_id = artifact_elem.text.strip() if artifact_elem is not None and artifact_elem.text else 'unknown'
                    print(f"{group_id}:{artifact_id}:{version_text}:{pom_path}")
    except Exception as e:
        pass

repo_path = "$repo_path"
pom_files = find_pom_files(repo_path)
for pom_file in pom_files:
    extract_version_ranges(pom_file)
EOF
}

# =====================================================================================================================
# Update version in pom.xml using sed
# =====================================================================================================================
function updatePomVersion() {
    local pom_file="$1"
    local group_id="$2"
    local artifact_id="$3"
    local old_version="$4"
    local new_version="$5"
    
    echo -e "${BLUE}Updating ${group_id}:${artifact_id} to ${new_version}${RESET}"
    
    # Escape special characters for sed
    local escaped_old=$(echo "$old_version" | sed 's/[]\/$*.^[]/\\&/g')
    local escaped_new=$(echo "$new_version" | sed 's/[\/&]/\\&/g')
    
    # Update the version in pom.xml
    sed -i.bak "/<groupId>${group_id}<\/groupId>/,/<\/dependency>/ s/<version>${escaped_old}<\/version>/<version>${escaped_new}<\/version>/" "$pom_file"
    
    # Remove backup file
    rm -f "${pom_file}.bak"
}

# =====================================================================================================================
# Process a single repository
# =====================================================================================================================
function processRepository() {
    local repo_name="$1"
    local base_dir=$(pwd)
    
    printHeader "Processing Repository: $repo_name"
    
    # Clone repository
    cloneRepo "$repo_name"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Skipping $repo_name due to clone failure${RESET}"
        cd "$base_dir"
        return 1
    fi
    
    local repo_path=$(pwd)
    
    # Find version ranges
    echo -e "${BLUE}Searching for version ranges in pom.xml files...${RESET}"
    local ranges=$(findVersionRanges "$repo_path")
    
    if [ -z "$ranges" ]; then
        echo -e "${GREEN}✓ No version ranges found - skipping${RESET}"
        cd "$base_dir"
        return 0
    fi
    
    # Display found ranges
    echo -e "\n${YELLOW}Found version ranges:${RESET}"
    echo -e "${YELLOW}================================================================${RESET}"
    local count=1
    while IFS=: read -r group_id artifact_id version_range pom_file; do
        echo -e "${count}. ${group_id}:${artifact_id}"
        echo -e "   Current: ${version_range}"
        echo -e "   File: ${pom_file}"
        echo ""
        ((count++))
    done <<< "$ranges"
    echo -e "${YELLOW}================================================================${RESET}\n"
    
    # Get user input for versions
    # Store mappings in a temporary file (bash 3 compatible)
    temp_mappings=$(mktemp)
    
    # Load saved mappings if available
    saved_mappings=""
    if [ "$USE_MAPPINGS" == "y" ] && [ -f "$MAPPINGS_FILE" ]; then
        saved_mappings=$(loadVersionMappings "$MAPPINGS_FILE")
        echo -e "${GREEN}✓ Loaded saved version mappings${RESET}\n"
    fi
    
    # Convert ranges to array to avoid read issues
    IFS=$'\n' read -d '' -r -a ranges_array <<< "$ranges"
    
    count=1
    for range_line in "${ranges_array[@]}"; do
        # Skip empty lines
        if [ -z "$range_line" ]; then
            continue
        fi
        
        # Parse the line
        IFS=: read -r group_id artifact_id version_range pom_file <<< "$range_line"
        
        # Skip if any field is empty
        if [ -z "$group_id" ] || [ -z "$artifact_id" ] || [ -z "$version_range" ]; then
            continue
        fi
        
        # Check if we have a saved mapping for this dependency
        mapping_key="${group_id}:${artifact_id}:${version_range}"
        saved_version=""
        
        if [ -n "$saved_mappings" ] && [ -f "$saved_mappings" ]; then
            saved_version=$(grep "^${mapping_key}=" "$saved_mappings" 2>/dev/null | cut -d'=' -f2)
        fi
        
        echo -e "${BLUE}[$count] ${group_id}:${artifact_id}${RESET}"
        echo -e "Current range: ${version_range}"
        
        if [ -n "$saved_version" ]; then
            echo -e "${GREEN}Found saved version: ${saved_version}${RESET}"
            read -p "Use this version? (y/n/skip) [y]: " use_saved
            use_saved=${use_saved:-y}
            
            if [ "$use_saved" == "y" ] || [ "$use_saved" == "Y" ]; then
                new_version="$saved_version"
            elif [ "$use_saved" == "skip" ]; then
                echo -e "${YELLOW}⚠ Skipping${RESET}\n"
                ((count++))
                continue
            else
                read -p "Enter different version: " new_version
            fi
        else
            read -p "Enter fixed version (or 'skip'): " new_version
        fi
        
        if [ "$new_version" != "skip" ] && [ ! -z "$new_version" ]; then
            echo "${group_id}:${artifact_id}:${version_range}:${pom_file}=${new_version}" >> "$temp_mappings"
            echo -e "${GREEN}✓ Will update to: ${new_version}${RESET}\n"
        else
            echo -e "${YELLOW}⚠ Skipping${RESET}\n"
        fi
        ((count++))
    done
    
    # Cleanup saved mappings temp file
    if [ -n "$saved_mappings" ] && [ -f "$saved_mappings" ]; then
        rm -f "$saved_mappings"
    fi
    
    # Check if any versions were specified
    if [ ! -s "$temp_mappings" ]; then
        echo -e "${YELLOW}No versions specified - skipping repository${RESET}"
        rm -f "$temp_mappings"
        cd "$base_dir"
        return 0
    fi
    
    # Create branch
    echo -e "${BLUE}Creating branch: ${BRANCH_NAME}${RESET}"
    git checkout -b "$BRANCH_NAME"
    
    # Update pom files
    while IFS='=' read -r key new_version; do
        IFS=: read -r group_id artifact_id version_range pom_file <<< "$key"
        updatePomVersion "$pom_file" "$group_id" "$artifact_id" "$version_range" "$new_version"
    done < "$temp_mappings"
    
    # Save version mappings for reuse (only on first successful repo)
    if [ ! -f "version-mappings.txt" ]; then
        saveVersionMappings "$temp_mappings"
    fi
    
    # Cleanup temp file
    rm -f "$temp_mappings"
    
    # Commit changes
    echo -e "${BLUE}Committing changes...${RESET}"
    git add .
    git commit -m "[patch] ${JIRA_ISSUE} Update pom.xml dependency versions from ranges to fixed versions

- Replaced version ranges with specific versions to enable Renovate compatibility
- Part of Renovate enablement initiative"
    
    # Push branch
    echo -e "${BLUE}Pushing branch to remote...${RESET}"
    git push origin "$BRANCH_NAME"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to push branch${RESET}"
        cd "$base_dir"
        return 1
    fi
    
    # Create PR
    createPR "$repo_name"
    
    cd "$base_dir"
    return 0
}

# =====================================================================================================================
# Create a pull request
# =====================================================================================================================
function createPR() {
    local repo_name="$1"
    local base_branch="${2:-master}"
    
    echo -e "${BLUE}Creating pull request...${RESET}"
    
    local PR_TITLE="[patch] ${JIRA_ISSUE} Update pom.xml dependency versions from ranges to fixed versions"
    local PR_BODY="## Description

This PR replaces Maven dependency version ranges with fixed versions to enable Renovate compatibility.

## Changes
- Replaced version ranges with specific versions for internal dependencies
- Updated pom.xml files to use fixed versions instead of ranges

## Testing
- [ ] Build succeeds
- [ ] Unit tests pass
- [ ] Integration tests pass

## Related Issues
- [${JIRA_ISSUE}](https://jsw.ibm.com/browse/${JIRA_ISSUE})
- Part of Renovate enablement initiative"
    
    gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base "$base_branch" --head "$BRANCH_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Pull request created successfully${RESET}"
    else
        echo -e "${RED}Failed to create pull request${RESET}"
        return 1
    fi
}

# =====================================================================================================================
# Check prerequisites
# =====================================================================================================================
function checkPrerequisites() {
    echo -e "${BLUE}Checking prerequisites...${RESET}"
    
    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ Python 3 is not installed${RESET}"
        return 1
    fi
    echo -e "${GREEN}✓ Python 3 found${RESET}"
    
    # Check for Git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git is not installed${RESET}"
        return 1
    fi
    echo -e "${GREEN}✓ Git found${RESET}"
    
    # Check for GitHub CLI
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}✗ GitHub CLI (gh) is not installed${RESET}"
        echo -e "${YELLOW}  Install it from: https://cli.github.com/${RESET}"
        return 1
    fi
    echo -e "${GREEN}✓ GitHub CLI found${RESET}"
    
    # Check for GitHub token
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}⚠ GITHUB_TOKEN environment variable not set${RESET}"
        echo -e "${YELLOW}  You may need to authenticate with 'gh auth login'${RESET}"
    else
        echo -e "${GREEN}✓ GITHUB_TOKEN is set${RESET}"
    fi
    
    echo ""
    return 0
}

# Made with Bob
