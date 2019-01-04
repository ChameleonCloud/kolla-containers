include .env

KOLLA_VENV := cd kolla && source .tox/$(PYTHON_VERSION)/bin/activate
KOLLA_BUILD := $(KOLLA_VENV) && python tools/build.py \
	--config-file=$(abspath kolla-build.conf) \
	--template-override=$(abspath kolla-template-overrides.j2) \
	--type=$(KOLLA_INSTALL_TYPE) \
	--base=$(KOLLA_BASE) --base-tag=$(KOLLA_BASE_TAG) --base-arch=$(KOLLA_BASE_ARCH) \
	--registry=$(DOCKER_REGISTRY) --namespace=$(KOLLA_NAMESPACE) \
	--skip-existing \
	--tag=$(VERSION)

VENV := source venv/bin/activate &&
STAMPS := .stamps

%-build: kolla
	$(KOLLA_BUILD) $*

# Kolla doesn't have a way to publish via kolla-build as a separate step,
# so we have to replicate the way it constructs image names.
KOLLA_IMAGE_NAME = $(DOCKER_REGISTRY)/$(KOLLA_NAMESPACE)/$(KOLLA_BASE)-$(KOLLA_INSTALL_TYPE)-$*:$(VERSION)
%-publish: kolla
	docker push $(KOLLA_IMAGE_NAME)

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
