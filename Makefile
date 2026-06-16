MUSTANG_VERSION ?= 2.23.0
MUSTANG_JAR     := vendor/Mustang-CLI-$(MUSTANG_VERSION).jar
MUSTANG_URL     := https://github.com/ZUGFeRD/mustangproject/releases/download/core-$(MUSTANG_VERSION)/Mustang-CLI-$(MUSTANG_VERSION).jar

.PHONY: all clean fmt fmtcheck lint fix docs spec spec-integration version tag

all: clean fmt lint docs spec

fmt:
	crystal tool format

fmtcheck:
	crystal tool format --check

spec:
	crystal spec -v

lib/ameba/bin/ameba:
	shards install

lint: lib/ameba/bin/ameba
	lib/ameba/bin/ameba

fix: lib/ameba/bin/ameba
	lib/ameba/bin/ameba --fix

docs:
	crystal docs

clean:
	rm -rf docs/

# Sync the VERSION constant in src/ to match shard.yml's version field.
# Bump shard.yml's version first, then run `make version`.
version:
	@V=$$(grep '^version:' shard.yml | sed -E 's/^version:[[:space:]]*//'); \
	for f in $$(grep -rl '^[[:space:]]*VERSION[[:space:]]*=[[:space:]]*"[^"]*"' src/ 2>/dev/null); do \
		sed -E "s/^([[:space:]]*VERSION[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\\1\"$$V\"/" "$$f" > "$$f.tmp" && mv "$$f.tmp" "$$f"; \
		echo "updated $$f to $$V"; \
	done

# Create an annotated git tag "vX.Y.Z" from shard.yml's version field.
tag:
	@V=$$(grep '^version:' shard.yml | sed -E 's/^version:[[:space:]]*//'); \
	git tag -a "v$$V" -m "Release v$$V"; \
	echo "tagged v$$V"

vendor/mustang: $(MUSTANG_JAR)

$(MUSTANG_JAR):
	mkdir -p vendor
	curl -fL -o $@ $(MUSTANG_URL)

spec-integration: $(MUSTANG_JAR)
	MUSTANG_JAR=$(MUSTANG_JAR) crystal spec spec/zugpferd/mustang_spec.cr -v
