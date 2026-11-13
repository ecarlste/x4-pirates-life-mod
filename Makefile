.PHONY: setup deploy deploy-local deploy-dry-run test test-plan release doc-paths doc-names game-test game-test-locked game-test-report worktrees help

# npm for make setup's install of the TypeScript tools' packages; override to use another
NPM ?= npm
# Runs the game test runner on Windows through WSL interop; override to run it another way
GAME_TEST_RUNNER ?= powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$(wslpath -w tools/run-game-tests.ps1)"
# What the report says was tested: the commit, branch, and whether uncommitted changes were deployed too
GAME_TEST_GIT = -Commit $$(git rev-parse HEAD) -Branch $$(git rev-parse --abbrev-ref HEAD) $$(test -z "$$(git status --porcelain)" || echo -Dirty)

help:
	@echo "X4 Foundations - A Pirate's Life Mod"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup          - Create deploy.config from example (main checkout only), turn on the git hooks, npm install the TypeScript tools"
	@echo "  make deploy         - Sync the latest origin/main into the X4 extensions folder"
	@echo "  make deploy-local   - Sync your working tree instead (uncommitted changes included)"
	@echo "  make deploy-dry-run - Show what 'make deploy' would change"
	@echo "  make test           - Run the test suites your changes need (ALL=1: every suite)"
	@echo "  make test-plan      - Regenerate the readable test plan in docs/test-plan/ from the feature files"
	@echo "  make release        - Build dist/apirateslife-<version>.zip from the latest origin/main (TAG=v<version>:"
	@echo "                       from that tag) once every test passes there, with the release checklist"
	@echo "  make doc-paths      - Check the docs name only repo paths that exist (make test runs it too)"
	@echo "  make doc-names      - Check the docs and tools name no removed mod global or game test (make test runs it too)"
	@echo "  make game-test      - Deploy your working tree and run the in-game tests in the X4 8.00 copy (Windows),"
	@echo "                       holding the game lock so no other run uses the game meanwhile"
	@echo "  make game-test-report - Post the last game-test report to this branch's PR (comment and check)"
	@echo "  make worktrees      - List worktrees; flag uncommitted or unpushed work not yet on main"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "Other refs: ./deploy.sh --ref <branch>  (PowerShell: .\\deploy.ps1 -Ref <branch>)"
	@echo "Extra options: make deploy-local ARGS=\"--set CaptureFloorHull=20\"  (also deploy, deploy-dry-run, game-test)"
	@echo "               make game-test RUNNER_ARGS=-PrepareProfile  (options for tools/run-game-tests.ps1)"

setup:
	@git config core.hooksPath .githooks && echo "Git hooks on (.githooks: no commits on main, no attribution lines in commit messages)"
	@if command -v $(NPM) >/dev/null; then \
		$(NPM) install --no-fund --no-audit; \
	else \
		echo "npm not found: install Node.js 22.18 or later for the TypeScript tools (make test runs them)"; \
	fi
	@main=$$(bash -c '. tools/deploy-config.sh && deploy_config_main "$$PWD"'); \
	if [ -f deploy.config ]; then \
		echo "deploy.config already exists"; \
		echo "Edit it to update your X4 installation path"; \
	elif [ -n "$$main" ] && [ -f "$$main/deploy.config" ]; then \
		echo "Using the main checkout's deploy.config: $$main/deploy.config"; \
		echo "A deploy.config here would override it, setting by setting"; \
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
	@tests/run.sh $(if $(ALL),--all)

test-plan:
	@python3 tools/test_plan_docs.py

release:
	@tools/release.sh $(if $(TAG),--tag $(TAG))

doc-paths:
	@node tools/check-doc-paths.ts

doc-names:
	@node tools/check-doc-names.ts

# One game lock (tools/game-lock.sh) around both, so no other run deploys between them
game-test:
	@tools/game-lock.sh --what game-test -- $(MAKE) --no-print-directory game-test-locked

# The X4 settings in the environment reach the Windows runner: WSL passes Windows programs only the
# variables WSLENV names
game-test-locked: export WSLENV := $(if $(WSLENV),$(WSLENV):)X4_PATH:X4_EXE:X4_PROFILE_ID:X4_PROFILE_ROOT

# make game-test's steps, run while it holds the game lock: the runner's setup checks first, so a
# bad setup stops before the deploy changes the game folder
game-test-locked:
	@$(GAME_TEST_RUNNER) -PreflightOnly $(RUNNER_ARGS)
	@./deploy.sh --working-tree $(ARGS)
	@$(GAME_TEST_RUNNER) $(GAME_TEST_GIT) $(RUNNER_ARGS)

game-test-report:
	@tools/post-game-test-report.sh $(ARGS)

worktrees:
	@tools/worktree-status.sh
