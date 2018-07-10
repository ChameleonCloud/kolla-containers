OPENSTACK_RELEASE := stable/ocata

PYTHON_VERSION := py27

KOLLA_CONFIG := $(abspath kolla-build.conf)
KOLLA_VENV := cd kolla && source .tox/$(PYTHON_VERSION)/bin/activate
KOLLA_REGISTRY ?=
KOLLA_BUILD := $(KOLLA_VENV) && python tools/build.py \
	--config-file=$(KOLLA_CONFIG)

SERVICES := horizon

STAMPS := .stamps

kolla: $(STAMPS)/kolla
	touch $@

$(SERVICES:%=build-%): build-%: kolla
	$(KOLLA_BUILD) --squash --nopush $*

$(SERVICES:%=push-%): push-%: kolla
	$(KOLLA_BUILD) --push --registry=$(KOLLA_REGISTRY) $*

# Kolla build dependencies

$(STAMPS)/kolla: kolla/.tox/$(PYTHON_VERSION)/bin/activate
	mkdir -p $(dir $@)
	touch $@

kolla/.tox/$(PYTHON_VERSION)/bin/activate: kolla/tox.ini
	cd kolla && tox -e $(PYTHON_VERSION)
