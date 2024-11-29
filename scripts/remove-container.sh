#!/bin/bash

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to confirm deletion
confirm_deletion() {
    read -p "Are you sure you want to remove $1? (y/N) " response
    case "$response" in
    [yY][eE][sS] | [yY])
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

# Get container name from user if not provided
if [ -z "$1" ]; then
    read -p "Enter container name to remove: " container_name
else
    container_name=$1
fi

# Convert to lowercase
container_name=$(echo "$container_name" | tr '[:upper:]' '[:lower:]')

# Capitalize first letter for matching in site.yml
container_name_cap="$(tr '[:lower:]' '[:upper:]' <<<${container_name:0:1})${container_name:1}"

# Define files and directories to remove
playbook_file="playbooks/containers/${container_name}.yml"
vars_dir="vars/${container_name}"
templates_dir="templates/${container_name}"
roles_dir="roles/${container_name}"
site_yml="playbooks/site.yml"

# List all files and directories that will be removed
echo "The following files and directories will be removed:"
echo "- $playbook_file"
echo "- $vars_dir/"
echo "- $templates_dir/"
echo "- $roles_dir/"
echo "- Entry from $site_yml"

# Confirm deletion
if ! confirm_deletion "these files and directories"; then
    echo "Operation cancelled"
    exit 1
fi

# Create backup
backup_dir="backups/containers/${container_name}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"
cp -r "$playbook_file" "$vars_dir" "$templates_dir" "$roles_dir" "$backup_dir/" 2>/dev/null
echo "Backup created in $backup_dir"

# Remove from site.yml
if [ -f "$site_yml" ]; then
    # Create temp file
    temp_file=$(mktemp)
    # Remove the import playbook lines and maintain formatting
    sed "/- name: Deploy ${container_name_cap}/,/\.yml/d" "$site_yml" >"$temp_file"
    # Remove any duplicate blank lines
    awk 'NF > 0 { blank = 0 } NF == 0 { blank++ } blank <= 2' "$temp_file" >"$site_yml"
fi

# Remove files and directories
rm -f "$playbook_file" 2>/dev/null
rm -rf "$vars_dir" 2>/dev/null
rm -rf "$templates_dir" 2>/dev/null
rm -rf "$roles_dir" 2>/dev/null

# Check if any of the removals failed
if [ $? -eq 0 ]; then
    echo "Successfully removed container structure for ${container_name}"
    echo "Backup available at: $backup_dir"
else
    echo "Error: Some files or directories could not be removed"
    exit 1
fi

# Print summary of removed files and directories
echo -e "\nRemoved Files and Directories:"
echo "--------------------------------"
echo -e "${YELLOW}Directories:${NC}"
echo -e "  🗑️ ${YELLOW}${vars_dir}${NC}"
echo -e "  🗑️ ${YELLOW}${templates_dir}${NC}"
echo -e "  🗑️ ${YELLOW}${roles_dir}${NC}"
echo ""
echo -e "${CYAN}Files:${NC}"
echo -e "  🗑️ ${CYAN}${playbook_file}${NC}"
echo -e "  🗑️ ${CYAN}${vars_dir}/main.yml${NC}"
echo -e "  🗑️ ${CYAN}${templates_dir}/docker-compose.yml${NC}"
echo -e "  🗑️ ${CYAN}${roles_dir}/pre_deploy.yml${NC}"
echo -e "  🗑️ ${CYAN}${roles_dir}/post_deploy.yml${NC}"
echo -e "  🗑️ ${CYAN}${roles_dir}/post_healthy.yml${NC}"
echo ""
echo "❗ Container structure removed for ${container_name} ❗"
echo ""
echo -e "${GREEN}🚧Don't forget to:${NC}"
echo -e "${GREEN}1. Update the site.yml file${NC}"
echo -e "${GREEN}2. Update the inventory file with relevant hosts${NC}"
echo ""
echo "Backup available at: ${backup_dir}"
