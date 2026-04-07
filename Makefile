.DEFAULT_GOAL := help

ACTIVATE := source .venv/bin/activate
PLAYBOOK := $(ACTIVATE) && ansible-playbook -i inventory/hosts.yml --ask-become-pass

.PHONY: help install setup deploy check lint encrypt decrypt start connect

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install Ansible and dependencies
	brew bundle
	python3 -m venv .venv
	$(ACTIVATE) && pip install -r requirements.txt
	$(ACTIVATE) && ansible-galaxy collection install -r collections/requirements.yml -p collections

setup_rosie: ## Create the rosie VM
	./scripts/setup-vm.sh "rosie" --memory "4GB" --disk-size "60GB" --iso "./ubuntu-24.04.4-live-server-amd64.iso"

setup_athena: ## Create the athena VM
	./scripts/setup-vm.sh "athena" --memory "8GB" --disk-size "110GB" --iso "./ubuntu-24.04.4-live-server-amd64.iso"

setup: ## Create a VM (usage: make setup HOST=some-host)
	./scripts/setup-vm.sh "$(HOST)" --memory "8GB" --disk-size "110GB" --iso "./ubuntu-24.04.4-live-server-amd64.iso"

deploy: ## Deploy to a host (usage: make deploy HOST=rosie)
	$(PLAYBOOK) playbooks/deploy.yml --limit $(HOST)

check: ## Dry-run deploy (usage: make check HOST=rosie)
	$(PLAYBOOK) playbooks/deploy.yml --limit $(HOST) --check --diff

lint: ## Lint playbooks and roles
	$(ACTIVATE) && ansible-lint playbooks/*.yml

encrypt: ## Encrypt the vault file
	$(ACTIVATE) && ansible-vault encrypt vars/vault.yml

decrypt: ## Decrypt the vault file
	$(ACTIVATE) && ansible-vault decrypt vars/vault.yml

start: ## Start a VM (usage: make start HOST=rosie)
	lume run $(HOST) --no-display

connect_hermes: ## SSH into a host in tmux (usage: make connect_hermes HOST=rosie)
	ssh -t $(HOST) "sudo -iu hermes tmux new-session -s remote-$(HOST)-session"
