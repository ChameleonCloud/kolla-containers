KOLLA_FLAGS ?=

ifeq ($(KOLLA_PUSH), true)
  KOLLA_FLAGS := $(KOLLA_FLAGS) --push
endif
ifeq ($(KOLLA_PUSH), yes)
  KOLLA_FLAGS := $(KOLLA_FLAGS) --push
endif
ifneq ($(KOLLA_USE_CACHE), no)
  # Always skip ancestors; we want to explicitly build the ancestor
  # images instead of automagically doing this.
  KOLLA_FLAGS := $(KOLLA_FLAGS) --skip-parents --cache
endif

.PHONY: build
build:
	./kolla-build $(KOLLA_FLAGS)

# Kept for backwards compatibility
.PHONY: build-with-locals
build-with-locals: build

.PHONY: clean
clean:
	rm -rf build
