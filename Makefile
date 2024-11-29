.PHONY: ping setup install-roles lint test install-docker deploy-postgres deploy-gitea create-container remove-container multipass-create multipass-stop multipass-delete multipass-purge

ping:
	ansible all -m ping

setup:
	ansible-playbook playbooks/site.yml

install-roles:
	ansible-galaxy install -r requirements.yml

lint:
	ansible-lint playbooks/*.yml roles/*

install-docker:
	ansible-playbook playbooks/tools/install-docker.yml

deploy-postgres:
	ansible-playbook playbooks/containers/postgres.yml

deploy-gitea:
	ansible-playbook playbooks/containers/gitea.yml

create-container:
	@scripts/create-container.sh

remove-container:
	@scripts/remove-container.sh

# Dynamic targets
deploy-%:
	@if [ -f "playbooks/containers/$*.yml" ]; then \
		ansible-playbook playbooks/containers/$*.yml; \
	else \
		echo "No playbook found for $*"; \
		exit 1; \
	fi

# Multipass VM Management
multipass-create:
	@scripts/create-multipass-vms.sh

multipass-stop:
	@echo "Stopping all Multipass VMs..."
	@multipass list --format csv | tail -n +2 | cut -d',' -f1 | xargs -I {} multipass stop {}
	@echo "✅ All VMs stopped"

multipass-delete:
	@echo "Deleting all Multipass VMs..."
	@multipass list --format csv | tail -n +2 | cut -d',' -f1 | xargs -I {} multipass delete {}
	@echo "✅ All VMs deleted"

multipass-purge:
	@echo "Purging deleted Multipass VMs..."
	@multipass purge
	@echo "✅ Deleted VMs purged"

# Clean up everything
multipass-cleanup: multipass-stop multipass-delete multipass-purge
	@echo "🧹 Complete cleanup finished"