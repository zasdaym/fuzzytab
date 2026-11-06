APP := build/FuzzyTab.app

.PHONY: app run test clean install

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/FuzzyTab $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign - $(APP)

run: app
	open $(APP)

# The Command Line Tools keep the swift-testing macro plugin outside the default search path.
TESTING_PLUGINS := $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing

test:
	swift test -Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS)

install: app
	rm -rf /Applications/FuzzyTab.app
	cp -R $(APP) /Applications/

clean:
	rm -rf .build build
