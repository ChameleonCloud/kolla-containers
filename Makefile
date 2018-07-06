KOLLA_CONFIG := $(abspath kolla-build.conf)
KOLLA_VENV := cd kolla && source .tox/py27/bin/activate
KOLLA_BUILD := $(KOLLA_VENV) && python tools/build.py --config-file=$(KOLLA_CONFIG)

kolla: kolla/.tox/py27/bin/activate
	touch $@

kolla/.tox/py27/bin/activate:
	cd kolla && tox -e py27

horizon: kolla
	$(KOLLA_BUILD) $@
