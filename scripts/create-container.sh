#!/bin/bash

# Default values
DEFAULT_CONTAINER="default"
DEFAULT_SUBNET="172.22.0.0/24"

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to validate IPv4 address
validate_ip() {
  local ip=$1
  if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 1
  fi

  IFS='.' read -r -a octets <<<"$ip"
  for octet in "${octets[@]}"; do
    if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
      return 1
    fi
  done

  return 0
}

# Function to validate IPv4 subnet
validate_subnet() {
  local subnet=$1
  if [[ ! $subnet =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    return 1
  fi

  IFS='/' read -r ip_part cidr <<<"$subnet"
  IFS='.' read -r -a octets <<<"$ip_part"

  if [ "$cidr" -lt 0 ] || [ "$cidr" -gt 32 ]; then
    return 1
  fi

  for octet in "${octets[@]}"; do
    if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
      return 1
    fi
  done

  return 0
}

# Get container name from user (with default)
read -p "Enter container name [$DEFAULT_CONTAINER]: " container_name
container_name=${container_name:-$DEFAULT_CONTAINER}

# Convert to lowercase
container_name=$(echo "$container_name" | tr '[:upper:]' '[:lower:]')

# Capitalize first letter for consistent naming
container_name_cap="$(tr '[:lower:]' '[:upper:]' <<<${container_name:0:1})${container_name:1}"

# Get and validate subnet (with default)
while true; do
  read -p "Enter subnet (e.g., 172.22.0.0/24) [$DEFAULT_SUBNET]: " subnet
  subnet=${subnet:-$DEFAULT_SUBNET}
  if validate_subnet "$subnet"; then
    break
  else
    echo "Invalid subnet format. Please use IPv4 CIDR notation (e.g., 172.22.0.0/24)"
  fi
done

# Define directories to create
playbook_dir="playbooks/containers"
vars_dir="vars/${container_name}"
templates_dir="templates/${container_name}"
roles_dir="roles/${container_name}/tasks"

# Create directories
mkdir -p "$playbook_dir"
mkdir -p "$vars_dir"
mkdir -p "$templates_dir"
mkdir -p "$roles_dir"

# Create playbook file
cat >"${playbook_dir}/${container_name}.yml" <<EOF
---
- name: Deploy ${container_name_cap}
  hosts: ${hosts_alias}
  become: true
  vars_files:
    - ../../vars/${container_name}/main.yml
  roles:
    - role: docker
      vars:
        pre_deploy_tasks: "../../roles/${container_name}/tasks/pre_deploy.yml"
        post_deploy_tasks: "../../roles/${container_name}/tasks/post_deploy.yml"
        post_healthy_tasks: "../../roles/${container_name}/tasks/post_healthy.yml"
EOF

# Create vars file
cat >"${vars_dir}/main.yml" <<EOF
---
# ansible vars
${container_name}_data_dir: "/data/${container_name}"
${container_name}_backup_dir: "/backup/${container_name}"
${container_name}_version: "latest"

# directories
service_data_dir: "\${{ ${container_name}_data_dir }}"
service_directories:
  - "\${{ ${container_name}_data_dir }}"

# docker config
service_config:
  name: ${container_name}
  port: 8080
  environment:
    USER_UID: 1000
    USER_GID: 1000
  ip_address: "${container_ip}"

# templates
config_templates:
  - src: "../../templates/${container_name}/docker-compose.yml"
    dest: "\${{ ${container_name}_data_dir }}/docker-compose.yml"
EOF

# Create docker-compose template
cat >"${templates_dir}/docker-compose.yml" <<EOF
services:
  server:
    image: ${container_name}:\${{ ${container_name}_version }}
    container_name: "\${{ service_config.name }}"
    environment:
      - USER_UID=\${{ service_config.environment.USER_UID }}
      - USER_GID=\${{ service_config.environment.USER_GID }}
    restart: always
    networks:
      ${container_name}_net:
        ipv4_address: "\${{ service_config.ip_address }}"
    ports:
      - "\${{ service_config.port }}:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  ${container_name}_net:
    name: ${container_name}_net
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: "${subnet}"
EOF

# Create task files
for task in pre_deploy post_deploy post_healthy; do
  # Capitalize first word of task name for display
  task_cap=$(echo "$task" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1')

  cat >"${roles_dir}/${task}.yml" <<EOF
---
- name: Demo ${task_cap} Task
  debug:
    msg: "This is ${task} task"
EOF
done

# Extract network part for container IP
network_part=$(echo "$subnet" | cut -d'/' -f1 | rev | cut -d'.' -f2- | rev)
container_ip="${network_part}.2"

# Print summary of created files and directories
echo -e "\nCreated Files and Directories:"
echo "--------------------------------"
echo -e "${YELLOW}Directories:${NC}"
echo -e "  ${GREEN}✅${NC} ${YELLOW}${playbook_dir}${NC}"
echo -e "  ${GREEN}✅${NC} ${YELLOW}${vars_dir}${NC}"
echo -e "  ${GREEN}✅${NC} ${YELLOW}${templates_dir}${NC}"
echo -e "  ${GREEN}✅${NC} ${YELLOW}${roles_dir}${NC}"
echo ""
echo -e "${CYAN}Files:${NC}"
echo -e "  ${GREEN}✅${NC} ${CYAN}${playbook_dir}/${container_name}.yml${NC}"
echo -e "  ${GREEN}✅${NC} ${CYAN}${vars_dir}/main.yml${NC}"
echo -e "  ${GREEN}✅${NC} ${CYAN}${templates_dir}/docker-compose.yml${NC}"
echo -e "  ${GREEN}✅${NC} ${CYAN}${roles_dir}/pre_deploy.yml${NC}"
echo -e "  ${GREEN}✅${NC} ${CYAN}${roles_dir}/post_deploy.yml${NC}"
echo -e "  ${GREEN}✅${NC} ${CYAN}${roles_dir}/post_healthy.yml${NC}"
echo ""
echo -e "${MAGENTA}Network Configuration:${NC}"
echo -e "  ${GREEN}✅${NC} ${MAGENTA}Subnet: ${subnet}${NC}"
echo -e "  ${GREEN}✅${NC} ${MAGENTA}Container IP: ${container_ip}${NC}"
echo ""
echo "❗ Container structure created for ${container_name} ❗"
echo ""
echo -e "${GREEN}🚧Next Steps:${NC}"
echo -e "${GREEN}1. Update the container image and version${NC}"
echo -e "${GREEN}2. Configure the correct ports${NC}"
echo -e "${GREEN}3. Add appropriate healthcheck${NC}"
echo -e "${GREEN}4. Update the site.yml file${NC}"
echo -e "${GREEN}5. Update the inventory file with relevant hosts${NC}"
