PYTHON_VERSION := py27

KOLLA_REGISTRY ?= docker.chameleoncloud.org
KOLLA_VENV := cd kolla && source .tox/$(PYTHON_VERSION)/bin/activate
KOLLA_BUILD := $(KOLLA_VENV) && python tools/build.py \
	--config-file=$(abspath kolla-build.conf) \
	--template-override=$(abspath kolla-template-overrides.j2) \
	--push --registry=$(KOLLA_REGISTRY) \
	--skip-parents

VENV := source venv/bin/activate &&

STAMPS := .stamps

%-build: kolla
	$(KOLLA_BUILD) $*

%-genconfig: venv
	$(VENV) bin/gen_config $*

%-run: %-genconfig
	tar -xvf $*.tar
	CONF_PATH=$(abspath etc/kolla) \
		LOG_PATH=$(abspath log) \
		bin/start_container $* $(KOLLA_TAG)

# Kolla build dependencies

.PHONY: kolla
kolla: $(STAMPS)/kolla

$(STAMPS)/kolla: kolla/.tox/$(PYTHON_VERSION)/bin/activate
	mkdir -p $(dir $@)
	touch $@

kolla/.tox/$(PYTHON_VERSION)/bin/activate: kolla/tox.ini
	cd kolla && tox -e $(PYTHON_VERSION) --notest

# Virtualenv

.PHONY: venv
venv: $(STAMPS)/venv

$(STAMPS)/venv: requirements.txt
	mkdir -p $(dir $@)
	virtualenv $(notdir $@)
	$(VENV) pip install -r $<
	touch $@
