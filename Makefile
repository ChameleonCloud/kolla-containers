OPENSTACK_RELEASE := stable/ocata

PYTHON_VERSION := py27

KOLLA_VENV := cd kolla && source .tox/$(PYTHON_VERSION)/bin/activate
KOLLA_REGISTRY ?= 192.5.87.68:5000
KOLLA_BUILD := $(KOLLA_VENV) && python tools/build.py \
	--config-file=$(abspath kolla-build.conf) \
	--template-override=$(abspath kolla-template-overrides.j2) \
	--push --registry=$(KOLLA_REGISTRY)

SERVICES := horizon

STAMPS := .stamps

.PHONY: $(SERVICES:%=build-%)
$(SERVICES:%=build-%): build-%: kolla
	$(KOLLA_BUILD) $*

.PHONY: $(SERVICES:%=run-%)
$(SERVICES:%=run-%): run-%:
	bin/start_container $*

# Kolla build dependencies

.PHONY: kolla
kolla: $(STAMPS)/kolla
	touch $@

# TODO: this only rebuilds if the tox venv is not found.
# Should make this dependent on other contents of the kolla directory.
$(STAMPS)/kolla: kolla/.tox/$(PYTHON_VERSION)/bin/activate
	mkdir -p $(dir $@)
	touch $@

kolla/.tox/$(PYTHON_VERSION)/bin/activate: kolla/tox.ini
	cd kolla && tox -e $(PYTHON_VERSION)
