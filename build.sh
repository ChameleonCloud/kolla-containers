#!/bin/bash

kolla-build \
    --config-file kolla-build.conf \
    --template-override kolla-template-overrides.j2 \
    $@
