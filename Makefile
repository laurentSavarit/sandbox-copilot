IMAGE   := sandbox-copilot:latest
COMPOSE := docker compose
RUN_FLAGS := --rm -it
SANDBOX := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))sandbox.sh

.PHONY: help build run shell logs install clean clean-all

## help: Show this help message
help:
	@echo ""
	@echo "  GitHub Copilot CLI Sandbox"
	@echo ""
	@echo "  Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /    /'
	@echo ""

## build: Build the sandbox Docker image
build:
	$(COMPOSE) build

## run: Start Copilot in the CURRENT directory (yolo mode)
##      The folder you run make from is mounted as /workspace.
run:
	$(SANDBOX)

## shell: Open a bash shell in the CURRENT directory (for debugging)
shell:
	$(SANDBOX) bash

## install: Symlink sandbox.sh to /usr/local/bin/copilot-sandbox
##           After install: run `copilot-sandbox` from any folder
install:
	sudo ln -sf "$(SANDBOX)" /usr/local/bin/copilot-sandbox
	@echo "Installed: copilot-sandbox → $(SANDBOX)"

## logs: Show the sandbox block log (commands that were intercepted)
logs:
	@cat logs/sandbox-blocked.log 2>/dev/null || echo '(no blocked commands logged yet)'

## clean: Kill all running sandbox sessions
clean:
	docker ps -a --filter ancestor=$(IMAGE) -q | xargs -r docker rm -f

## clean-all: Kill all sandbox sessions and delete auth volume (forces re-login)
clean-all:
	docker ps -a --filter ancestor=$(IMAGE) -q | xargs -r docker rm -f
	docker volume rm copilot-auth 2>/dev/null || true
