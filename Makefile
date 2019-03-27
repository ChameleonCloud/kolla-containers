include .env

VENV := source venv/bin/activate &&
STAMPS := .stamps

KOLLA_FLAGS :=

ifeq ($(KOLLA_PUSH), yes)
	KOLLA_FLAGS := $(KOLLA_FLAGS) --push
endif
ifneq ($(KOLLA_USE_CACHE), no)
	KOLLA_FLAGS := $(KOLLA_FLAGS) --cache --skip-existing
endif

.PHONY: build
build: kolla
	./kolla-build $(KOLLA_FLAGS)

.PHONY: build-with-locals
build-with-locals: kolla
	./kolla-build \
		--work-dir=$(abspath build) \
		--config-file=$(abspath $(KOLLA_BUILD_PROFILE)/kolla-build.local-sources.conf) \
		--locals-base=$(abspath sources) \
		$(KOLLA_FLAGS)

# Untags any -base images to ensure they get rebuilt with the child images.
.PHONY: clean
clean: kolla
	docker images --format '{{.Repository}}:{{.Tag}}' \
		| grep '$(KOLLA_BUILD_PROFILE)-base:$(VERSION)' \
		| xargs -r docker rmi

# Kolla build dependencies

kolla: $(STAMPS)/kolla

$(STAMPS)/kolla: kolla/.tox/$(PYTHON_VERSION)/bin/activate
	mkdir -p $(dir $@)
	touch $@

kolla/.tox/$(PYTHON_VERSION)/bin/activate: venv kolla/tox.ini
	$(VENV) cd kolla && tox -e $(PYTHON_VERSION) --notest
	touch $@

kolla/%:
	git submodule update --init

# Virtualenv

venv: $(STAMPS)/venv

$(STAMPS)/venv: requirements.txt
	mkdir -p $(dir $@)
	virtualenv $(notdir $@)
	$(VENV) pip install -r $<
	touch $@
