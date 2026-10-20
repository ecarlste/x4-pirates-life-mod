.PHONY: setup deploy deploy-local deploy-dry-run test game-test help

# Runs the game test runner on Windows through WSL interop; override to run it another way
GAME_TEST_RUNNER ?= powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$(wslpath -w tools/run-game-tests.ps1)"

help:
	@echo "X4 Foundations - A Pirate's Life Mod"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup          - Create deploy.config from example"
	@echo "  make deploy         - Sync the latest origin/main into the X4 extensions folder"
	@echo "  make deploy-local   - Sync your working tree instead (uncommitted changes included)"
	@echo "  make deploy-dry-run - Show what 'make deploy' would change"
	@echo "  make test           - Run the bats and Pester test suites"
	@echo "  make game-test      - Deploy your working tree and run the in-game tests in X4 (Windows)"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "Other refs: ./deploy.sh --ref <branch>  (PowerShell: .\\deploy.ps1 -Ref <branch>)"

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
	@./deploy.sh

deploy-local:
	@./deploy.sh --working-tree

deploy-dry-run:
	@./deploy.sh --dry-run

test:
	@tests/run.sh

game-test:
	@./deploy.sh --working-tree
	@$(GAME_TEST_RUNNER)
