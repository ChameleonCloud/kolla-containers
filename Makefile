OPENSTACK_RELEASE := stable/ocata

PYTHON_VERSION := py27

KOLLA_CONFIG := $(abspath kolla-build.conf)
KOLLA_VENV := cd kolla && source .tox/$(PYTHON_VERSION)/bin/activate
KOLLA_BUILD := $(KOLLA_VENV) && python tools/build.py --config-file=$(KOLLA_CONFIG)

STAMPS := .stamps

kolla: $(STAMPS)/kolla
	touch $@

.PHONY: horizon
horizon: kolla
	$(KOLLA_BUILD) $@

# Kolla build dependencies

$(STAMPS)/kolla: kolla/.tox/$(PYTHON_VERSION)/bin/activate
	mkdir -p $(dir $@)
	touch $@

kolla/.tox/$(PYTHON_VERSION)/bin/activate: kolla/tox.ini
	cd kolla && tox -e $(PYTHON_VERSION)
