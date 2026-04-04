.DEFAULT_GOAL := help

ACTIVATE := source .venv/bin/activate
PLAYBOOK := $(ACTIVATE) && ansible-playbook -i inventory/hosts.yml --ask-become-pass

.PHONY: help install setup deploy_openclaw deploy_claude deploy check lint encrypt decrypt start_helios start_athena

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install Ansible and dependencies
	python3 -m venv .venv
	$(ACTIVATE) && pip install -r requirements.txt
	$(ACTIVATE) && ansible-galaxy collection install -r collections/requirements.yml -p collections

setup_helios: ## Create helios VM
	./scripts/setup-vm.sh "helios" --memory "4GB" --disk-size "60GB"

setup_athena: ## Create athena VM
	./scripts/setup-vm.sh "athena"

deploy_openclaw: ## Deploy OpenClaw to server
	$(PLAYBOOK) playbooks/deploy-openclaw.yml

deploy_claude: ## Deploy Claude server
	$(PLAYBOOK) playbooks/deploy-claude.yml

deploy: deploy_openclaw deploy_claude

check: ## Dry-run to preview changes
	$(PLAYBOOK) playbooks/deploy-openclaw.yml --check --diff

lint: ## Lint playbook and roles
	$(ACTIVATE) && ansible-lint playbooks/*.yml

encrypt: ## Encrypt the vault file
	$(ACTIVATE) && ansible-vault encrypt vars/vault.yml

decrypt: ## Decrypt the vault file
	$(ACTIVATE) && ansible-vault decrypt vars/vault.yml

start_helios: ## Start Helios VM
	lume run helios --no-display

start_athena: ## Start Athena VM
	lume run athena --no-display

connect_athena:
	ssh -t athena "sudo -iu claude tmux new-session -s claude-session"