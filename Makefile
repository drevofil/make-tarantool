.DEFAULT_GOAL := help
ENV ?= default

# Load environment variables
ENV_FILE := .env.$(ENV)
ifneq (,$(wildcard $(ENV_FILE)))
include $(ENV_FILE)
export $(shell sed 's/=.*//' $(ENV_FILE))
else
$(warning Environment file $(ENV_FILE) not found! Using default variables)
endif

# Variables with fallback defaults
IMAGE_NAME 				?= ansible-tarantool-enterprise
DEPLOY_TOOL_VERSION_TAG ?= latest
SUPER_USER_NAME         ?= admin
PACKAGE_NAME            ?= package.rpm
PATH_TO_PRIVATE_KEY     ?= $(HOME)/.ssh/id_rsa
PATH_TO_INVENTORY       ?= $(CURDIR)/inventories/hosts.yml
PATH_TO_PACKAGE         ?= $(CURDIR)/packages/$(PACKAGE_NAME)

# Переменная для управления become_user (по умолчанию: tarantool)
TARANTOOL_BECOME_USER   ?= tarantool

# Дополнительные параметры (могут быть пустыми)
EXTRA_VOLUMES           ?=
EXTRA_VARS_FILE         ?=  # Путь к JSON-файлу с дополнительными переменными

## Helpers
DOCKER_CMD := docker run --net=host -it --rm
VOLUMES     := -v $(PATH_TO_PRIVATE_KEY):/ansible/.ssh/id_private_key:Z \
                -v $(PATH_TO_INVENTORY):/ansible/inventories/hosts.yml:Z 
MOUNT_PACKAGE     := -v $(PATH_TO_PACKAGE):/ansible/packages/$(PACKAGE_NAME):Z
ENV_VARS    := -e SUPER_USER_NAME=$(SUPER_USER_NAME) \
                -e PACKAGE_NAME=$(PACKAGE_NAME)
PLAYBOOK_CMD:= ansible-playbook -i /ansible/inventories/hosts.yml

# Базовый блок EXTRA_VARS
define BASE_EXTRA_VARS
--extra-vars '{ \
    "cartridge_package_path":"/ansible/packages/$(PACKAGE_NAME)", \
	"tcm_package_path":"/ansible/packages/$(PACKAGE_NAME)", \
    "ansible_ssh_private_key_file":"/ansible/.ssh/id_private_key", \
    "super_user":"$(SUPER_USER_NAME)", \
	"ansible_user":"$(SUPER_USER_NAME)", \
    "tarantool_shared_become_user":"$(TARANTOOL_BECOME_USER)" \
}'
endef

define PRINT_HELP
	@echo "Available environments:"
	@ls -1 .env.* 2>/dev/null | sed 's/\.env\.\(.*\)/  \1/' || echo "  (no environment files found)"
    @echo "\nTargets:"
    @awk 'BEGIN {FS = ":.*?## "} /^[0-9a-zA-Z_-]+:.*?## / { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
    @echo
endef

# Флаг для дополнительного файла переменных
EXTRA_VARS_FILE_FLAG := $(if $(EXTRA_VARS_FILE),--extra-vars "@/ansible/extra_vars.json",)

# Полный набор EXTRA_VARS
define EXTRA_VARS
$(BASE_EXTRA_VARS) $(EXTRA_VARS_FILE_FLAG)
endef

.PHONY: deploy help etcd_3_0 install_3_0 uninstall check-env variables env_prepare environments env-template

env_prepare: TARANTOOL_BECOME_USER = root
env_prepare: ## Run Ansible env preperation playbook
	@echo "Starting env preparation for [$(ENV)] environment with root privileges..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/env_prepare.yml
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		-v ./custom_steps:/ansible/playbooks/custom_steps \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/custom_steps/set-bashrc.yml


etcd_3_0: ## Run Ansible etcd_3_0.yml playbook
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/etcd_3_0.yml

install_3_0: ## Run Ansible install_3_0.yml playbook
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/install_3_0.yml

install_tcm: ## Run Ansible tcm/install.yml playbook
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/tcm/install.yml

uninstall-tarantool: ## Run Ansible uninstall.yml playbook
uninstall-tarantool: check-env
	@echo "Starting uninstall for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/uninstall.yml

uninstall-tcm: ## Run Ansible uninstall.yml playbook with --tags tcm
uninstall-tcm: check-env
	@echo "Starting uninstall for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/uninstall.yml  --tags tcm

help: ## Print help
	$(PRINT_HELP)

check-env: ## Verify required files exist
	@echo "Checking required files for environment [$(ENV)]..."
	@echo "Environment file: $(if $(wildcard $(ENV_FILE)),found [$(ENV_FILE)],not found - using defaults)"
	@echo "Private key: $(if $(wildcard $(PATH_TO_PRIVATE_KEY)),found [$(PATH_TO_PRIVATE_KEY)],not found)"
	@if [ ! -f "$(PATH_TO_PRIVATE_KEY)" ]; then \
		echo "Error: Private key not found at $(PATH_TO_PRIVATE_KEY)"; \
		exit 1; \
	fi
	@echo "Inventory file: $(if $(wildcard $(PATH_TO_INVENTORY)),found [$(PATH_TO_INVENTORY)],not found)"
	@if [ ! -f "$(PATH_TO_INVENTORY)" ]; then \
		echo "Error: Inventory file not found at $(PATH_TO_INVENTORY)"; \
		exit 1; \
	fi
	@if [ -n "$(PATH_TO_PACKAGE)" ]; then \
		echo "Package file: $(if $(wildcard $(PATH_TO_PACKAGE)),found [$(PATH_TO_PACKAGE)],not found)"; \
		if [ ! -f "$(PATH_TO_PACKAGE)" ]; then \
			echo "Error: Package file not found at $(PATH_TO_PACKAGE)"; \
			exit 1; \
		fi; \
	else \
		echo "Package not provided"; \
	fi
	@if [ -n "$(EXTRA_VARS_FILE)" ]; then \
		echo "Extra vars file: $(if $(wildcard $(EXTRA_VARS_FILE)),found [$(EXTRA_VARS_FILE)],not found)"; \
		if [ ! -f "$(EXTRA_VARS_FILE)" ]; then \
			echo "Error: Extra vars file not found at $(EXTRA_VARS_FILE)"; \
			exit 1; \
		fi; \
	else \
		echo "Extra vars file: not specified"; \
	fi
	@echo "All required files found."

variables: ## Show current variables configuration
	@echo "Environment: [$(ENV)]"
	@echo "Using file: $(ENV_FILE)"
	@echo "\nVariables:"
	@echo "  IMAGE_NAME              = $(IMAGE_NAME)"
	@echo "  DEPLOY_TOOL_VERSION_TAG = $(DEPLOY_TOOL_VERSION_TAG)"
	@echo "  SUPER_USER_NAME         = $(SUPER_USER_NAME)"
	@echo "  PACKAGE_NAME            = $(PACKAGE_NAME)"
	@echo "  PATH_TO_PRIVATE_KEY     = $(PATH_TO_PRIVATE_KEY)"
	@echo "  PATH_TO_INVENTORY       = $(PATH_TO_INVENTORY)"
	@echo "  PATH_TO_PACKAGE         = $(PATH_TO_PACKAGE)"
	@echo "  TARANTOOL_BECOME_USER   = $(TARANTOOL_BECOME_USER)"
	@echo "  EXTRA_VOLUMES           = $(EXTRA_VOLUMES)"
	@echo "  EXTRA_VARS_FILE         = $(EXTRA_VARS_FILE)"
vars: ## Same as variables
vars: variables

environments: ## List available environments
	@echo "Available environments:"
	@ls -1 .env.* 2>/dev/null | sed 's/\.env\.\(.*\)/  \1/' || echo "  (no environment files found)"
envs: ## Same as environments
envs: environments

# Example file creation
env-template: ## Create template environment file
	@echo "Creating template: .env.example"
	@echo "# Deployment configuration for example environment" > .env.example
	@echo "IMAGE_NAME=ansible-tarantool-enterprise" >> .env.example
	@echo "DEPLOY_TOOL_VERSION_TAG=1.10.2" >> .env.example
	@echo "SUPER_USER_NAME=admin" >> .env.example
	@echo "PACKAGE_NAME=./tarantooldb-2.2.1.linux.x86_64.tar.gz" >> .env.example
	@echo "PATH_TO_PRIVATE_KEY=/home/.ssh/id_rsa" >> .env.example
	@echo "PATH_TO_INVENTORY=/opt/inventories/hosts.yml" >> .env.example
	@echo "PATH_TO_PACKAGE=/opt/packages/\$${PACKAGE_NAME}" >> .env.example
	@echo "" >> .env.example
	@echo "# Optional extra parameters" >> .env.example
	@echo "# BACKUP_LIMIT=storage-1-1" >> .env.example
	@echo "# RESTORE_LIMIT=storage-1-1" >> .env.example
	@echo "# EXTRA_VOLUMES=-v ./centos.yml:/ansible/playbooks/prepare/os/centos.yml:Z" >> .env.example
	@echo "# EXTRA_VARS_FILE=/path/to/extra_vars.json" >> .env.example
	@echo "# Example extra_vars.json content" >> .env.example
	@echo "# {\"custom_option\": \"value\"}" >> .env.example

deploy-tdb: ## Deploy TarantoolDB cluster
deploy-tdb: check-env\
			etcd_3_0 \
			install_3_0

deploy-tcm: ## Deploy Tarantool Cluster Manager
deploy-tcm: check-env\
			install_tcm

gen-prometheus: ## Run custom_steps/generate-prometheus-config.yaml playbook
gen-prometheus: check-env
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/custom_steps/generate-prometheus-config.yaml
	@mv prometheus_tarantool.yml prometheus-tarantool-$(ENV).yml 

get-endpoints: ## Run custom_steps/get-endpoints.yaml playbook
get-endpoints: check-env
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/custom_steps/get-endpoints.yaml
	@mv endpoints.txt endpoints-$(ENV).txt

monitoring-install: ##Deploy monitoring example
monitoring-install: 
	@sudo docker compose --project-directory monitoring up -d

monitoring-remove: ##Deploy monitoring example
monitoring-remove: 
	@sudo docker compose --project-directory monitoring down -v --remove-orphans

install-etcd: ## Run custom_steps/etcd-playbook.yml playbook
install-etcd: check-env
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/custom_steps/etcd-playbook.yml -b

uninstall-etcd: ## Run custom_steps/etcd-playbook.yml playbook
uninstall-etcd: check-env
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/custom_steps/etcd-playbook.yml -b -e etcd_uninstall=true

backup-tarantool: ## Run Ansible backup.yml playbook
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/backup.yml $(if $(BACKUP_LIMIT),--limit $(BACKUP_LIMIT), --limit STORAGES,ROUTERS)

restore-tarantool: ## Run Ansible restore.yml playbook
	@echo "Starting deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) playbooks/restore.yml $(if $(RESTORE_LIMIT),--limit $(RESTORE_LIMIT), --limit STORAGES,ROUTERS)