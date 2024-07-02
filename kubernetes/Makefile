TERRAFORM := terraform

.PHONY: format
format:
	@$(TERRAFORM) fmt --recursive

.PHONY: init
init:
	@$(TERRAFORM) init -backend=false -input=false

.PHONY: test
test: init
	@$(TERRAFORM) validate

.PHONY: deploy
deploy:
	@. .env && $(TERRAFORM) init -upgrade && $(TERRAFORM) apply

.PHONY: destroy
destroy:
	@. .env && $(TERRAFORM) init -upgrade && $(TERRAFORM) destroy

.PHONY: cluster
cluster: test
	@$(TERRAFORM) apply -var-file="example.tfvars"
