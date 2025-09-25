.DEFAULT_GOAL := help
ENV ?= default
VERSION ?= 1.6.3

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
	@echo "Ansible Tarantool Enterprise Deployment Tool v$(VERSION)"
	@echo "======================================================"
	@echo ""
	@echo "Available environments:"
	@ls -1 .env.* 2>/dev/null | sed 's/\.env\.\(.*\)/  \1/' || echo "  (no environment files found)"
    @echo "\nTargets:"
    @awk 'BEGIN {FS = ":.*?## "} /^[0-9a-zA-Z_-]+:.*?## / { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
    @echo
endef

# Флаг для дополнительного файла переменных
EXTRA_VARS_FILE_FLAG := $(if $(EXTRA_VARS_FILE),--extra-vars "@/ansible/extra_vars.json",)

# Полный набор EXTRA_VARS
define EXTRA_VARS
$(BASE_EXTRA_VARS) $(EXTRA_VARS_FILE_FLAG)
endef

.PHONY: deploy help etcd_3_0 install_3_0 uninstall check-env variables env_prepare environments env-template

version: ## Show current version
	@echo "Ansible Tarantool Enterprise Deployment Tool v$(VERSION)"

env_prepare: TARANTOOL_BECOME_USER = root
env_prepare: ## Prepare hosts before install
	@echo "Starting env preparation for [$(ENV)] environment with root privileges..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/env_prepare.yml
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		-v ./custom_steps:/ansible/playbooks/custom_steps:Z \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/custom_steps/set-bashrc.yml


etcd_3_0: ## Store cluster config in ETCD (etcd_3_0.yml)
	@echo "Starting ETCD preparation for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/etcd_3_0.yml

install_3_0: ## Install Tarantool 3.x (install_3_0.yml)
	@echo "Starting install Tarantool 3.x deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/install_3_0.yml

install_cart: ## Install Cartridge app (deploy.yml)
	@echo "Starting install Tarantool Cartridge deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/deploy.yml

install_tcm: ## Install Tarantool Cluster Manager (tcm/install.yml)
	@echo "Starting Tarantool Cluster Manager deployment for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/tcm/install.yml

uninstall-tarantool: ## Uninstall Tarantool (uninstall.yml)
uninstall-tarantool: check-env
	@echo "Starting uninstall Tarantool for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/uninstall.yml

uninstall-tcm: ## Uninstall Tarantool Cluster Manager (uninstall.yml --tags tcm)
uninstall-tcm: check-env
	@echo "Starting uninstall Tarantool Cluster Manager for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/uninstall.yml  --tags tcm

help: ## Print help
	$(PRINT_HELP)

check-env: ## Verify required files exist
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
	@if [ -n "$(VAULT_PASSWORD_FILE)" ]; then \
		echo "Vault password file: $(if $(wildcard $(VAULT_PASSWORD_FILE)),found [$(VAULT_PASSWORD_FILE)],not found)"; \
		if [ ! -f "$(VAULT_PASSWORD_FILE)" ]; then \
			echo "Error: Vault password file not found at $(VAULT_PASSWORD_FILE)"; \
			exit 1; \
		fi; \
	else \
		echo "Vault password file: not specified"; \
	fi
	@echo "All required files found."
variables: ## Show current variables configuration
	@echo "Environment: [$(ENV)]"
	@echo "Using file: $(ENV_FILE)"
	@echo "\nVariables:"
	@cat $(ENV_FILE) | grep -v '#'
vars: ## Same as variables
vars: variables

environments: ## List available environments
	@echo "Available environments:"
	@ls -1 .env.* 2>/dev/null | sed 's/\.env\.\(.*\)/  \1/' || echo "  (no environment files found)"
envs: ## Same as environments
envs: environments

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
	@echo "# VAULT_PASSWORD_FILE=/path/to/vault_password_file" >> .env.example
	@echo "# BACKUP_LIMIT=storage-1-1" >> .env.example
	@echo "# RESTORE_LIMIT=storage-1-1" >> .env.example
	@echo "# EXTRA_VOLUMES=-v ./centos.yml:/ansible/playbooks/prepare/os/centos.yml:Z" >> .env.example
	@echo "# EXTRA_VARS_FILE=/path/to/extra_vars.json" >> .env.example
	@echo "# Example extra_vars.json content" >> .env.example
	@echo "# {\"custom_option\": \"value\"}" >> .env.example
	@echo "" >> .env.example
	@echo "# For encrypting strings with ansible-vault:" >> .env.example
	@echo "# sudo make encrypt-string ENV=env_name STRING_TO_ENCRYPT='your string'" >> .env.example

deploy-tdb: ## Deploy TarantoolDB cluster
deploy-tdb: check-env\
			etcd_3_0 \
			install_3_0

deploy-tdg: ## Deploy Tarantool Data Grid cluster
deploy-tdg: check-env\
			install_cart

deploy-tcm: ## Deploy Tarantool Cluster Manager
deploy-tcm: check-env\
			install_tcm

gen-prometheus: ## Run custom_steps/generate-prometheus-config.yaml playbook
gen-prometheus: check-env
	@echo "Generate prometheus config for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps:Z \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/custom_steps/generate-prometheus-config.yaml
	@mv prometheus_tarantool.yml prometheus-tarantool-$(ENV).yml 

get-endpoints: ## Run custom_steps/get-endpoints.yaml playbook
get-endpoints: check-env
	@echo "Get instance endpoints for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(MOUNT_PACKAGE) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps:Z \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/custom_steps/get-endpoints.yaml
	@mv endpoints.txt endpoints-$(ENV).txt

monitoring-install: ##Deploy monitoring example
monitoring-install: 
	@sudo docker compose --project-directory monitoring up -d

monitoring-remove: ##Deploy monitoring example
monitoring-remove: 
	@sudo docker compose --project-directory monitoring down -v --remove-orphans

install-etcd: ## Run custom_steps/etcd-playbook.yml playbook
install-etcd: check-env
	@echo "Starting ETCD install for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps:Z \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/custom_steps/etcd-playbook.yml -b

uninstall-etcd: ## Run custom_steps/etcd-playbook.yml playbook
uninstall-etcd: check-env
	@echo "Starting ETCD uninstall for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		-v ./custom_steps:/ansible/playbooks/custom_steps:Z \
		-v $(shell pwd):/tmp/get:Z \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/custom_steps/etcd-playbook.yml -b -e etcd_uninstall=true

backup-tarantool: ## Run Ansible backup.yml playbook
	@echo "Starting backup for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/backup_stop.yml $(if $(BACKUP_LIMIT),--limit $(BACKUP_LIMIT), --limit STORAGES,ROUTERS,cores,routers)
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/backup.yml $(if $(BACKUP_LIMIT),--limit $(BACKUP_LIMIT), --limit STORAGES,ROUTERS,cores,routers)

restore-tarantool: ## Run Ansible restore.yml playbook
	@echo "Starting restoring for [$(ENV)] environment..."
	@echo "Using extra volumes: $(EXTRA_VOLUMES)"
	@echo "Using extra vars file: $(EXTRA_VARS_FILE)"
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/stop.yml $(if $(RESTORE_LIMIT),--limit $(RESTORE_LIMIT), --limit STORAGES,ROUTERS,cores,routers)
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/restore.yml $(if $(RESTORE_LIMIT),--limit $(RESTORE_LIMIT), --limit STORAGES,ROUTERS,cores,routers)
	$(DOCKER_CMD) \
		$(VOLUMES) \
		$(if $(EXTRA_VARS_FILE),-v $(EXTRA_VARS_FILE):/ansible/extra_vars.json:Z,) \
		$(if $(VAULT_PASSWORD_FILE),-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z,) \
		$(EXTRA_VOLUMES) \
		$(ENV_VARS) \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		$(PLAYBOOK_CMD) $(EXTRA_VARS) $(if $(VAULT_PASSWORD_FILE), --vault-password-file /ansible/vault) playbooks/start.yml $(if $(RESTORE_LIMIT),--limit $(RESTORE_LIMIT), --limit STORAGES,ROUTERS,cores,routers)

encrypt-string: ## Encrypt a string with Ansible Vault. Requires VAULT_PASSWORD_FILE in .env file
encrypt-string: check-env
	$(DOCKER_CMD) \
		-v $(VAULT_PASSWORD_FILE):/ansible/vault:Z \
		$(IMAGE_NAME):$(DEPLOY_TOOL_VERSION_TAG) \
		ansible-vault encrypt_string --vault-password-file /ansible/vault $(STRING_TO_ENCRYPT)