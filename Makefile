.DEFAULT_GOAL := help

ACTIVATE := source .venv/bin/activate
ANSIBLE_CFG := ANSIBLE_CONFIG=configuration/ansible.cfg
PLAYBOOK := $(ACTIVATE) && $(ANSIBLE_CFG) ansible-playbook configuration/deploy.yml --ask-become-pass

.PHONY: help install init setup deploy check lint encrypt decrypt start connect_hermes

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install Ansible and dependencies
	brew bundle
	python3 -m venv .venv
	$(ACTIVATE) && pip install -r requirements.txt
	$(ACTIVATE) && $(ANSIBLE_CFG) ansible-galaxy collection install -r configuration/requirements.yml -p collections

init: ## Initialize configuration (usage: make init BACKEND=orbstack)
	$(ACTIVATE) && python3 scripts/init.py --backend "$(BACKEND)"

setup_orbstack_vm: ## Create an orbstack VM (usage: make setup HOST=XXXX)
	./scripts/setup.sh "$(HOST)" --backend "orbstack"

setup_lume_vm: ## Create a lume VM (usage: make setup HOST=XXXX)
	./scripts/setup.sh "$(HOST)" --backend "lume" --memory "8GB" --disk-size "110GB" --iso "./ubuntu-24.04.4-live-server-amd64.iso"

deploy: ## Deploy to a host (usage: make deploy HOST=XXXX)
	$(PLAYBOOK) --limit $(HOST)

check: ## Dry-run deploy (usage: make check HOST=XXXX)
	$(PLAYBOOK) --limit $(HOST) --check --diff

lint: ## Lint playbooks
	$(ACTIVATE) && $(ANSIBLE_CFG) ansible-lint configuration/deploy.yml

encrypt: ## Encrypt the vault file
	$(ACTIVATE) && $(ANSIBLE_CFG) ansible-vault encrypt configuration/vault.yml

decrypt: ## Decrypt the vault file
	$(ACTIVATE) && $(ANSIBLE_CFG) ansible-vault decrypt configuration/vault.yml

start: ## Start a VM (usage: make start HOST=XXXX BACKEND=lume)
ifeq ($(BACKEND),orbstack)
	orb start $(HOST)
else
	lume run $(HOST) --no-display
endif

connect_claude: ## SSH into a host in tmux (usage: make connect_claude HOST=XXXX)
	ssh -t $(HOST) "sudo -iu claude tmux new-session -s remote-$(HOST)-session"

connect_openclaw: ## SSH into a host in tmux (usage: make connect_openclaw HOST=XXXX)
	ssh -t $(HOST) "sudo -iu openclaw tmux new-session -s remote-$(HOST)-session"

connect_hermes: ## SSH into a host in tmux (usage: make connect_hermes HOST=XXXX)
	ssh -t $(HOST) "sudo -iu hermes tmux new-session -s remote-$(HOST)-session"
