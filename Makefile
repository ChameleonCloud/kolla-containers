include .env

VENV := source venv/bin/activate &&
STAMPS := .stamps

%-build: kolla
	./kolla-build $*

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
