MUSTANG_VERSION ?= 2.23.0
MUSTANG_JAR     := vendor/Mustang-CLI-$(MUSTANG_VERSION).jar
MUSTANG_URL     := https://github.com/ZUGFeRD/mustangproject/releases/download/core-$(MUSTANG_VERSION)/Mustang-CLI-$(MUSTANG_VERSION).jar

.PHONY: test test-integration

test:
	crystal spec

vendor/mustang: $(MUSTANG_JAR)

$(MUSTANG_JAR):
	mkdir -p vendor
	curl -fL -o $@ $(MUSTANG_URL)

test-integration: $(MUSTANG_JAR)
	MUSTANG_JAR=$(MUSTANG_JAR) crystal spec spec/zugpferd/mustang_spec.cr
