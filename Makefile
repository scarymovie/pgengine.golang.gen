# Development tasks. Requirements: docker, go, git.
# Dhall runs in a container (dhallhaskell/dhall), pGenie CLI in its own
# image (e2e/pgn.Dockerfile) — no local installs needed.

DHALL_IMAGE := dhallhaskell/dhall:1.42.2
DHALL := docker run --rm -v "$(CURDIR):/work" -w /work \
  -u "$(shell id -u):$(shell id -g)" -e XDG_CACHE_HOME=/work/.dhall-cache \
  $(DHALL_IMAGE) dhall

DHALL_SOURCES := gen/Gen.dhall gen/Config.dhall gen/compile.dhall \
  gen/Algebras/Interpreter.dhall $(wildcard gen/Interpreters/*.dhall) \
  tests/Demo.dhall tests/GoType.test.dhall tests/Fixtures/Demo.dhall

.PHONY: check demo e2e fmt clean

## Type-check the generator and run the type-mapping unit tests.
check:
	$(DHALL) type --file gen/Gen.dhall > /dev/null
	$(DHALL) --file tests/GoType.test.dhall > /dev/null
	@echo "check: OK"

## Generate tests/output from the local fixture and verify it compiles.
demo:
	rm -rf tests/output
	$(DHALL) to-directory-tree --file tests/Demo.dhall \
	  --output tests/output --allow-path-separators
	cd tests/output && go mod tidy && go vet ./...
	@echo "demo: OK"

## Full e2e: run the generator through the real pGenie CLI against the
## official demo project, compile the artifact and query a live database.
e2e:
	e2e/run.sh

## Format all Dhall sources in place.
fmt:
	$(DHALL) format --inplace $(DHALL_SOURCES)

clean:
	rm -rf tests/output .dhall-cache
