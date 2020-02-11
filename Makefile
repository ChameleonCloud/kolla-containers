include .env

# Allow .env overrides to have effect here as well
ifneq (,$(wildcard $(KOLLA_BUILD_PROFILE)/.env))
	include $(KOLLA_BUILD_PROFILE)/.env
endif

VENV := source venv/bin/activate &&
STAMPS := .stamps
KOLLA_CHECKOUT := kolla/$(OPENSTACK_BASE_RELEASE)

KOLLA_FLAGS ?=
# Always skip ancestors; we want to explicitly build the ancestor
# images instead of automagically doing this.
KOLLA_FLAGS := $(KOLLA_FLAGS) --skip-parents

ifeq ($(KOLLA_PUSH), yes)
	KOLLA_FLAGS := $(KOLLA_FLAGS) --push
endif
ifneq ($(KOLLA_USE_CACHE), no)
	KOLLA_FLAGS := $(KOLLA_FLAGS) --cache 
endif

.PHONY: print_env
print_env:
	@echo Build profile: $(KOLLA_BUILD_PROFILE)
	@echo OpenStack release: $(OPENSTACK_BASE_RELEASE)
	@echo Kolla checkout: $(KOLLA_CHECKOUT)
	@echo Kolla build flags: $(KOLLA_FLAGS)
	@echo Docker tag: $(DOCKER_TAG)

.PHONY: build
build: kolla
	./kolla-build $(KOLLA_FLAGS)

.PHONY: build-with-locals
build-with-locals: kolla
	./kolla-build \
		--work-dir=$(abspath build) \
		--config-dir=$(abspath $(KOLLA_BUILD_PROFILE)) \
		--locals-base=$(abspath sources) \
		$(KOLLA_FLAGS)

.PHONY: clean
clean:
	rm -rf build kolla

# Kolla build dependencies
.PHONY: kolla
kolla: $(STAMPS)/$(KOLLA_CHECKOUT)

$(STAMPS)/$(KOLLA_CHECKOUT): $(KOLLA_CHECKOUT)/.tox/$(PYTHON_VERSION)/bin/activate
	@ # Clean up pre-existing kolla stamp for when we had just one checkout
	@ [[ -f $(STAMPS)/kolla ]] && rm -f $(STAMPS)/kolla || true 
	mkdir -p $(dir $@)
	touch $@

$(KOLLA_CHECKOUT)/.tox/$(PYTHON_VERSION)/bin/activate: venv $(KOLLA_CHECKOUT)/tox.ini
	$(VENV) cd $(KOLLA_CHECKOUT) && tox -e $(PYTHON_VERSION) --notest
	touch $@

$(KOLLA_CHECKOUT)/%:
	git clone --single-branch --branch=chameleoncloud/$(OPENSTACK_BASE_RELEASE) \
		https://github.com/chameleoncloud/kolla.git $(KOLLA_CHECKOUT)

# Virtualenv

venv: $(STAMPS)/venv

$(STAMPS)/venv: requirements.txt
	mkdir -p $(dir $@)
	virtualenv $(notdir $@)
	$(VENV) pip install -r $<
	touch $@
