.PHONY: help install uninstall test clean

INSTALL_DIR ?= $(HOME)/.local/bin
SCRIPT_NAME = kfinalizer

help:
	@echo "kfinalizer - Kubernetes Finalizer Removal Tool"
	@echo ""
	@echo "Available targets:"
	@echo "  install     Install kfinalizer to $(INSTALL_DIR)"
	@echo "  uninstall   Remove kfinalizer from $(INSTALL_DIR)"
	@echo "  test        Run basic tests"
	@echo "  clean       Clean temporary files"
	@echo ""
	@echo "Environment variables:"
	@echo "  INSTALL_DIR   Installation directory (default: ~/.local/bin)"

install:
	@echo "Installing $(SCRIPT_NAME) to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@cp $(SCRIPT_NAME) $(INSTALL_DIR)/$(SCRIPT_NAME)
	@chmod +x $(INSTALL_DIR)/$(SCRIPT_NAME)
	@echo "✓ Installed to $(INSTALL_DIR)/$(SCRIPT_NAME)"
	@if ! echo "$$PATH" | grep -q "$(INSTALL_DIR)"; then \
		echo ""; \
		echo "Note: $(INSTALL_DIR) is not in your PATH"; \
		echo "Add this to your ~/.bashrc or ~/.zshrc:"; \
		echo ""; \
		echo "    export PATH=\"\$$PATH:$(INSTALL_DIR)\""; \
		echo ""; \
	fi

uninstall:
	@echo "Removing $(SCRIPT_NAME) from $(INSTALL_DIR)..."
	@rm -f $(INSTALL_DIR)/$(SCRIPT_NAME)
	@echo "✓ Uninstalled"

test:
	@echo "Running basic tests..."
	@./$(SCRIPT_NAME) --version
	@./$(SCRIPT_NAME) --help > /dev/null
	@echo "✓ Basic tests passed"

clean:
	@echo "Cleaning temporary files..."
	@rm -f *.tmp
	@echo "✓ Clean"
