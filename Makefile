.DEFAULT_GOAL := help

ACTIVATE := source .venv/bin/activate
PLAYBOOK := $(ACTIVATE) && ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml --ask-become-pass

.PHONY: help install deploy check lint encrypt decrypt start

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install Ansible and dependencies
	python3 -m venv .venv
	$(ACTIVATE) && pip install -r requirements.txt
	$(ACTIVATE) && ansible-galaxy collection install -r collections/requirements.yml -p collections

deploy: ## Deploy OpenClaw to server
	$(PLAYBOOK)

check: ## Dry-run to preview changes
	$(PLAYBOOK) --check --diff

lint: ## Lint playbook and roles
	$(ACTIVATE) && ansible-lint playbooks/*.yml

encrypt: ## Encrypt the vault file
	$(ACTIVATE) && ansible-vault encrypt vars/vault.yml

decrypt: ## Decrypt the vault file
	$(ACTIVATE) && ansible-vault decrypt vars/vault.yml

start: ## Start Eros VM
	lume run eros --no-display