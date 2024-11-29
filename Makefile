.PHONY: ping setup install-roles lint test install-docker deploy-postgres deploy-gitea create-container remove-container

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