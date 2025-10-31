.PHONY: setup deploy help

help:
	@echo "X4 Foundations - A Pirate's Life Mod"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup  - Create deploy.config from example"
	@echo "  make deploy - Deploy mod to X4 extensions directory"
	@echo "  make help   - Show this help message"

setup:
	@if [ -f deploy.config ]; then \
		echo "deploy.config already exists"; \
		echo "Edit it to update your X4 installation path"; \
	else \
		cp deploy.config.example deploy.config; \
		echo "Created deploy.config"; \
		echo "Please edit deploy.config with your X4 installation path"; \
	fi

deploy:
	@chmod +x deploy.sh
	@./deploy.sh
