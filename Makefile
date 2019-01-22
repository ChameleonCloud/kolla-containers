include .env

VENV := source venv/bin/activate &&
STAMPS := .stamps

ifeq ($(KOLLA_PUSH), yes)
	KOLLA_FLAGS := --push
else
	KOLLA_FLAGS :=
endif

build: kolla
	./kolla-build $(KOLLA_FLAGS)

build-with-locals: kolla
	./kolla-build \
		--work-dir=$(abspath build) \
		--config-file=$(abspath $(KOLLA_BUILD_PROFILE)/kolla-build.local-sources.conf) \
		--locals-base=$(abspath sources) \
		$(KOLLA_FLAGS)

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
