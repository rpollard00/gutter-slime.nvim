NVIM ?= nvim
NVIM_DATA_DIR ?= $(HOME)/.local/share/nvim
PLENARY_DIR ?= $(NVIM_DATA_DIR)/lazy/plenary.nvim

.PHONY: test

test:
	@test -d "$(PLENARY_DIR)" || { echo "plenary.nvim not found at $(PLENARY_DIR)"; echo "Install it there or override PLENARY_DIR=/path/to/plenary.nvim"; exit 1; }
	$(NVIM) --headless --clean -u NONE \
		-c "set rtp+=$(PLENARY_DIR) | set rtp+=$(CURDIR) | runtime plugin/plenary.vim" \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/init.lua' }" \
		-c qa
