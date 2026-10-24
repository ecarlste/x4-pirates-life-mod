.PHONY: setup deploy deploy-local deploy-dry-run test test-plan game-test game-test-report help

# Runs the game test runner on Windows through WSL interop; override to run it another way
GAME_TEST_RUNNER ?= powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$(wslpath -w tools/run-game-tests.ps1)"
# What the report says was tested: the commit, branch, and whether uncommitted changes were deployed too
GAME_TEST_GIT = -Commit $$(git rev-parse HEAD) -Branch $$(git rev-parse --abbrev-ref HEAD) $$(test -z "$$(git status --porcelain)" || echo -Dirty)

help:
	@echo "X4 Foundations - A Pirate's Life Mod"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup          - Create deploy.config from example"
	@echo "  make deploy         - Sync the latest origin/main into the X4 extensions folder"
	@echo "  make deploy-local   - Sync your working tree instead (uncommitted changes included)"
	@echo "  make deploy-dry-run - Show what 'make deploy' would change"
	@echo "  make test           - Run the bats and Pester test suites"
	@echo "  make test-plan      - Regenerate the readable test plan in docs/test-plan/ from the feature files"
	@echo "  make game-test      - Deploy your working tree and run the in-game tests in X4 (Windows)"
	@echo "  make game-test-report - Post the last game-test report to this branch's PR (comment and check)"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "Other refs: ./deploy.sh --ref <branch>  (PowerShell: .\\deploy.ps1 -Ref <branch>)"
	@echo "Extra options: make deploy-local ARGS=\"--set IntactOnEject=0\"  (also deploy, deploy-dry-run, game-test)"

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
	@./deploy.sh $(ARGS)

deploy-local:
	@./deploy.sh --working-tree $(ARGS)

deploy-dry-run:
	@./deploy.sh --dry-run $(ARGS)

test:
	@tests/run.sh

test-plan:
	@python3 tools/test_plan_docs.py

game-test:
	@./deploy.sh --working-tree $(ARGS)
	@$(GAME_TEST_RUNNER) $(GAME_TEST_GIT)

game-test-report:
	@tools/post-game-test-report.sh $(ARGS)
