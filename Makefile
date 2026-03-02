SRCS         = Sources/PNGReader.swift Sources/HTMLRenderer.swift Sources/AppMain.swift
APP          = ComfyQL.app
APP_MACOS    = $(APP)/Contents/MacOS
APP_BIN      = $(APP_MACOS)/ComfyQL
TARGET       = arm64-apple-macosx13.0
INSTALL_DIR  = $(HOME)/Applications
COMFY_OUT    = $(HOME)/dev/ComfyUI-Desktop/output
LSREGISTER   = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all install uninstall test clean

all: $(APP_BIN)
	codesign --force --sign - $(APP)

$(APP_BIN): $(SRCS)
	@mkdir -p $(APP_MACOS)
	swiftc $(SRCS) \
		-module-name ComfyQL \
		-o $(APP_BIN) \
		-framework AppKit \
		-framework WebKit \
		-framework Foundation \
		-target $(TARGET)

install: all
	@mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP)
	cp -R $(APP) $(INSTALL_DIR)/
	$(LSREGISTER) -f $(INSTALL_DIR)/$(APP)
	@echo ""
	@echo "Installed. Right-click a ComfyUI PNG → Open With → ComfyQL"
	@echo "Or from terminal: open -a ComfyQL /path/to/image.png"

uninstall:
	rm -rf $(INSTALL_DIR)/$(APP)
	$(LSREGISTER) -u $(INSTALL_DIR)/$(APP) 2>/dev/null || true
	@echo "Uninstalled."

test:
	@PNG=$$(ls $(COMFY_OUT)/*.png 2>/dev/null | head -1); \
	if [ -z "$$PNG" ]; then echo "No PNG found in $(COMFY_OUT)"; exit 1; fi; \
	echo "Testing with: $$PNG"; \
	open -a $(INSTALL_DIR)/$(APP) "$$PNG"

clean:
	rm -f $(APP_BIN)
