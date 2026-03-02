GEN_SRCS     = Sources/XMPParser.swift Sources/WebPReader.swift Sources/PNGReader.swift Sources/TIFFReader.swift Sources/HTMLRenderer.swift Sources/Generator.swift Sources/GeneratorPlugin.c
EXT_SRCS     = Sources/XMPParser.swift Sources/WebPReader.swift Sources/PNGReader.swift Sources/TIFFReader.swift Sources/HTMLRenderer.swift Sources/PreviewViewController.swift
APP_SRCS     = Sources/main.swift Sources/AppMain.swift Sources/XMPParser.swift Sources/WebPReader.swift Sources/PNGReader.swift Sources/TIFFReader.swift Sources/HTMLRenderer.swift
APP          = ComfyQL.app
APP_MACOS    = $(APP)/Contents/MacOS
APP_QLDIR    = $(APP)/Contents/Library/QuickLook
APP_PLUGINS  = $(APP)/Contents/PlugIns
GEN          = ComfyQL.qlgenerator
GEN_MACOS    = $(GEN)/Contents/MacOS
GEN_BIN      = $(GEN_MACOS)/ComfyQL
APP_BIN      = $(APP_MACOS)/ComfyQL
EXT          = ComfyQLExt.appex
EXT_MACOS    = $(EXT)/Contents/MacOS
EXT_BIN      = $(EXT_MACOS)/ComfyQLExt
TARGET       = arm64-apple-macosx13.0
SIGN_ID      = Developer ID Application: Conner Ward (N4YGB5B92K)
INSTALL_DIR  = /Applications
COMFY_OUT    = $(HOME)/dev/ComfyUI-Desktop/output
LSREGISTER   = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

NOTARY_PROFILE = comfyql

.PHONY: all notarize install uninstall test clean

all: $(GEN_BIN) $(EXT_BIN) $(APP_BIN) assemble
	codesign --force --sign "$(SIGN_ID)" --options runtime --entitlements entitlements-ext.plist $(APP_QLDIR)/$(GEN)
	codesign --force --sign "$(SIGN_ID)" --options runtime --entitlements entitlements-ext.plist $(APP_PLUGINS)/$(EXT)
	codesign --force --sign "$(SIGN_ID)" --options runtime $(APP)

$(GEN_BIN): $(GEN_SRCS)
	@mkdir -p $(GEN_MACOS)
	swiftc $(GEN_SRCS) \
		-module-name ComfyQL \
		-parse-as-library \
		-o $(GEN_BIN) \
		-Xlinker -bundle \
		-framework QuickLook \
		-framework Foundation \
		-framework AppKit \
		-framework ImageIO \
		-target $(TARGET)

$(EXT_BIN): $(EXT_SRCS)
	@mkdir -p $(EXT_MACOS)
	swiftc $(EXT_SRCS) \
		-module-name ComfyQLExt \
		-parse-as-library \
		-o $(EXT_BIN) \
		-Xlinker -e -Xlinker _NSExtensionMain \
		-framework Quartz \
		-framework WebKit \
		-framework Foundation \
		-framework AppKit \
		-framework ImageIO \
		-target $(TARGET)

$(APP_BIN): $(APP_SRCS)
	@mkdir -p $(APP_MACOS)
	swiftc $(APP_SRCS) \
		-o $(APP_BIN) \
		-framework AppKit \
		-framework WebKit \
		-framework Foundation \
		-framework ImageIO \
		-target $(TARGET)

assemble:
	@mkdir -p $(APP_QLDIR) $(APP_PLUGINS)
	cp -R $(GEN) $(APP_QLDIR)/
	cp -R $(EXT) $(APP_PLUGINS)/

notarize: all
	@echo "Zipping for notarization..."
	ditto -c -k --keepParent $(APP) /tmp/ComfyQL_notarize.zip
	@echo "Submitting to Apple Notary (this takes ~1-2 min)..."
	xcrun notarytool submit /tmp/ComfyQL_notarize.zip \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	@echo "Stapling notarization ticket..."
	xcrun stapler staple $(APP)
	rm -f /tmp/ComfyQL_notarize.zip
	@echo "Notarized. Now run: make install"

install:
	sudo rm -rf $(INSTALL_DIR)/$(APP)
	sudo cp -R $(APP) $(INSTALL_DIR)/
	$(LSREGISTER) -f $(INSTALL_DIR)/$(APP)
	qlmanage -r
	@sleep 2
	qlmanage -r cache
	@echo ""
	@echo "Installed. Verify with: qlmanage -m plugins | grep png"

uninstall:
	rm -rf $(INSTALL_DIR)/$(APP)
	$(LSREGISTER) -u $(INSTALL_DIR)/$(APP) 2>/dev/null || true
	qlmanage -r && qlmanage -r cache
	@echo "Uninstalled."

test:
	@PNG=$$(ls $(COMFY_OUT)/*.png 2>/dev/null | head -1); \
	if [ -z "$$PNG" ]; then echo "No PNG found in $(COMFY_OUT)"; exit 1; fi; \
	echo "Testing with: $$PNG"; \
	qlmanage -p "$$PNG"

clean:
	rm -f $(GEN_BIN) $(EXT_BIN) $(APP_BIN)
	rm -rf $(APP_QLDIR)/$(GEN) $(APP_PLUGINS)/$(EXT)
