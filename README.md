# 🏠 Ansible Homelab Management

[![Ansible Version](https://img.shields.io/badge/ansible-%3E%3D2.9-blue.svg)](https://docs.ansible.com/ansible/latest/index.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automated deployment and management of Docker containers in a homelab environment using Ansible. This repository contains scripts, playbooks, and templates for maintaining a consistent and reproducible infrastructure.

## ✨ Features

- 🐳 Docker container deployment automation
- 📝 Templated service configurations
- 🔄 Lifecycle management with pre/post hooks
- 🔐 Secure secrets management with Ansible Vault
- 📁 Standardized directory structure
- 🧰 Utility scripts for common operations

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/username/ansible-homelab.git
cd ansible-homelab

# Install dependencies
ansible-galaxy install -r requirements.yml

# Deploy a service (example: postgres)
make deploy-postgres
```

## 🚀 Getting Started

- [Deployment Options](#deploy)
  - Makefile Usage
  - Direct Playbook Invocation
  - Vault Password Management

## 🛠️ Scripts & Tools

- [Utility Scripts](#scripts)
  - Makefile Utilities
  - Container Creation Script
  - Container Removal Script

## 📐 Template System

- [System Overview](#overview)
  - Directory Structure Overview
  - File Organization

## 📁 Configuration Components

- [Group Variables](#group_vars)
- [Playbooks](#playbooks)
- [Roles](#roles)
- [Templates](#templates)
- [Variables](#vars)

## ⚙️ Configuration Guide

- [Required Variables](#required-variables)

  - Service Configuration
  - Directory Configuration
  - Template Configuration

- [Optional Variables](#optional-variables)
  - Deployment Control
  - Lifecycle Hooks

## 🔍 Additional Information

- [Example Usage](#example-usage)
- [Debug Output](#debug-output)
- [Best Practices](#best-practices)

## Deploy

- Either use the `Makefile`
  - Convention is `make deploy-{name}`
- Invoke playbook directly
  - `ansible-playbook playbooks/containers/gitea.yml`

For some playbooks, you may need to decrypt vault to access secrets or ensure remote user is root. To avoid asking for your password, there are defaults configured to load secrets:

Inside `ansible.cfg`:

```
vault_password_file = credentials/.vault_pass
become_password_file = credentials/.become_pass
```

These will auto load when Ansible asks for your passwords. (Don't expose these). Without these files, you can deploy manually like:

```
ansible-playbook -i inventory/production playbooks/deploy-postgres.yml --ask-vault-pass -K
```

## Scripts

- [./Makefile](Makefile)

  - Utility scripts I've written to manage deployments (i.e `make deploy-postgres`).

- [./scripts/create-container.sh]('scripts/create-container.sh')

  - Handles creating all the files & directories for templating out the deployment of a new Docker image

- [./scripts/remove-container.sh](scripts/remove-container.sh)
  - Handles easy reversal of the above command

## My Templating System

This template provides a standardized way to deploy Docker-based services with health checking, directory management, and configuration templating. It includes pre-deploy, post-deploy, and post-healthy hooks for customization.

## Overview

For a given deployment like `Grafana`, we can simplify the files needed by running `./scripts/create_container.sh`. From here, a series of files with get generated:

### tl;dr

- `Playbooks` define variables and roles to run a set of tasks
- `Roles` define reusable sets of _tasks_
- `Templates` define some Jinja templated text that are interpolated through `vars`
- `Vars` contain service specific variables & config to inject into templates. Examples could include things like docker-compose.yml templates. Jinja will process expressions and vars before copying the output file.
- `Files` contain static assets that can be easily copied into different nodes or containers. These files are unchanged and unprocessed when copied.
- `Tools` are just playbooks for software installed on the node such as Docker.

### `groups_vars/**/*.yml`

The _group_vars_ dir allows us to define global variables to share across all playbooks/roles/variables.

**Example**:

Env variable on host will be assigned to `home_dir` and fallback to default if undefined.

```
home_dir: "{{ lookup('env', 'REMOTE_HOME_DIR', default='/home/schachte') }}"
```

### `playbooks/containers/*.yml`

The _playbook_ can be thought of as the executable for a particular deployment. It's intentionally minimal and delegates to other files to promote better reusability within the codebase.

For _Docker_, the important thing is `role: docker`. This will automatically locate the [roles/docker](roles/docker/) dir and interpolate any variables into the deploy.yml. You can override all sorts of variables within this block and define lifecycle hooks as well.

### `roles/**/*.yml`

The _roles_ directory is to define reusable tasks that can be used between playbooks. For example, we have a `Docker` role for handling docker deployments very generically. These roles

A typical Ansible role may look like:

```
rolename/
├── defaults/        # Default variables (lowest precedence)
│   └── main.yml
├── files/          # Static files to be transferred
│   └── file.conf
├── handlers/        # Handler definitions
│   └── main.yml
├── meta/           # Role metadata and dependencies
│   └── main.yml
├── tasks/          # Core logic/tasks
│   └── main.yml
├── templates/      # Jinja2 templates
│   └── template.j2
├── tests/          # Role tests
│   ├── inventory
│   └── test.yml
└── vars/           # Role variables (high precedence)
    └── main.yml
```

### `templates/**/*`

The _templates_ directory is really anything that you'd like to parameterize for the role or playbook. These are written using the `Jinja` templating language.

We can add variables into regular files and Ansible with interpolate our variables into the file. This is useful for doing things like specifying a version for a Docker image using a variable or setting different paths for your volumes.

### `vars/**/main.yml`

The _vars_ dir contains all the values and defaults we define for a particular role. These are defined in multiple places and the precedence evaluation looks like:

```
1. Extra vars (`ansible-playbook -e "var=value"`)
2. Task vars (only for the task)
3. Block vars (only for tasks in block)
4. Role and include vars
5. Set_facts / registered vars
```

Check out [vars/postgres/main.yml](vars/postgres/main.yml) to see how we define the docker config block and various templates.

## Required Variables

### Service Configuration

_✏️ Defined in [./vars](./vars)_

- `service_config`: (dictionary) Core service configuration
  - Will be output to CLI if `debug` is true (good for debugging)
  - Contains general variable definitions that can be used within Docker templates.
  - See [./vars/postgres/main.yml](./vars/postgres/main.yml) for an example.

### Directory Configuration

- `service_data_dir`: (string) Base directory for the service data and configuration (i.e. a shared mount for the app you're deploying).
- `service_directories`: (list, optional) List of directories to create on the remote host machine(s) you're deploying to.

### Template Configuration

- `config_templates`: (list, optional) List of Jinja templates that will be interpolated before being created on the remote host(s).
  ```yaml
  config_templates:
    - src: "template.conf.j2"
      dest: "/path/to/output.conf"
      # TODO: mode not supported
      mode: "0644" # optional, defaults to "0644"
  ```

## Optional Variables

### Deployment Control

- `remove_volumes`: (boolean, default: false) Whether to remove volumes when redeploying
- `debug`: (boolean, default: false) Enable verbose debugging output
- `service_timeout`: (integer, default: 30) Timeout for service operations
- `service_host`: (string, default: "localhost") Host where service will run

### Lifecycle Hooks

Lifecycle hooks exists as a `Role`. For example:

```
roles/gitea
└── tasks
    ├── post_deploy.yml
    ├── post_healthy.yml
    └── pre_deploy.yml

1 directory, 3 files
```

The Docker deployment will invoke these at different stages of the deploy. This allows users/different services to inject custom code before and after the deployment happens.

- `pre_deploy_tasks`: (string, optional) Path to tasks file to run before deployment
- `post_deploy_tasks`: (string, optional) Path to tasks file to run after deployment
- `post_healthy_tasks`: (string, optional) Path to tasks file to run after service is healthy

## Example Usage

```yaml
# vars/postgres/main.yml
service_config:
  name: postgres

service_directories:
  - /var/lib/postgresql/data
  - /etc/postgresql/conf.d

config_templates:
  - src: postgresql.conf.j2
    dest: /etc/postgresql/postgresql.conf
    mode: "0644"

directory_mode: "0755"
service_host: "localhost"
service_timeout: 30
remove_volumes: false
```

## Deployment Rollback

You can set `rollback: true` on a playbook to stop and remove a container. Set `remove_volumes: true` to delete the associated volume(s).

## Debug Output

When `debug: true` is set, the template provides:

- Service configuration details
- Volume removal settings
- Container state information
- Health check status
- Container logs (if health checks fail)

## Best Practices

1. Always set `remove_volumes: false` for stateful services like databases
2. Use `directory_mode` to ensure proper permissions
3. Leverage lifecycle hooks for custom setup/teardown
4. Enable debug mode during initial deployment and troubleshooting
