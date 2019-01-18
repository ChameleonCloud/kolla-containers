include .env

VENV := source venv/bin/activate &&
STAMPS := .stamps

ifeq ($(KOLLA_PUSH), yes)
	KOLLA_FLAGS := --push
else
	KOLLA_FLAGS :=
endif

base-release: kolla
	./kolla-build --profile base --push

%-build: kolla
	./kolla-build $*

%-build-with-locals: kolla
	./kolla-build \
		--work-dir=$(abspath build) \
		--config-file=$(abspath $*/kolla-build.local-sources.conf) \
		--locals-base=$(abspath sources) \
		$(KOLLA_FLAGS) $*

# Kolla doesn't have a way to publish via kolla-build as a separate step,
# so we have to replicate the way it constructs image names.
KOLLA_IMAGE_NAME = $(DOCKER_REGISTRY)/$(KOLLA_NAMESPACE)/$(KOLLA_BASE)-$(KOLLA_INSTALL_TYPE)-$*:$(VERSION)
%-publish: kolla
	docker push $(KOLLA_IMAGE_NAME)

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
