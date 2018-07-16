PYTHON_VERSION := py27

# TODO: point to production registry
KOLLA_REGISTRY ?= 192.5.87.68:5000
KOLLA_VENV := cd kolla && source .tox/$(PYTHON_VERSION)/bin/activate
KOLLA_BUILD := $(KOLLA_VENV) && python tools/build.py \
	--config-file=$(abspath kolla-build.conf) \
	--template-override=$(abspath kolla-template-overrides.j2) \
	--push --registry=$(KOLLA_REGISTRY)

VENV := source venv/bin/activate &&

STAMPS := .stamps

%-build: kolla
	$(KOLLA_BUILD) $*

%-genconfig: venv
	$(VENV) bin/gen_config $*

%-run: %-genconfig
	tar -xvf $*.tar
	REGISTRY=$(KOLLA_REGISTRY) \
		CONF_PATH=$(abspath etc/kolla) \
		LOG_PATH=$(abspath log) \
		bin/start_container $*

# Kolla build dependencies

.PHONY: kolla
kolla: $(STAMPS)/kolla

$(STAMPS)/kolla: kolla/.tox/$(PYTHON_VERSION)/bin/activate
	mkdir -p $(dir $@)
	touch $@

kolla/.tox/$(PYTHON_VERSION)/bin/activate: kolla/tox.ini
	cd kolla && tox -e $(PYTHON_VERSION)

# Virtualenv

.PHONY: venv
venv: $(STAMPS)/venv

$(STAMPS)/venv: requirements.txt
	mkdir -p $(dir $@)
	virtualenv $@
	$(VENV) pip install -r $<
	touch $@
