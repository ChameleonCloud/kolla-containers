#!python3


import sys
from os import environ

from kolla.image import build as kolla_build

PROFILES= [
    "base",
    "blazar",
    "cinder",
    "doni",
    "glance",
    "gnocchi",
    "heat",
    "horizon",
    "ironic",
    "keystone",
    "manila",
    "neutron",
    "nova",
    "placement",
    "tunelo",
    "zun",
]


def main():
    kolla_argv = []

    kolla_argv.extend( ["--config-file", "kolla-build.conf"] )
    kolla_argv.extend( ["--template-override", "kolla-template-overrides.j2"])

    if environ.get("KOLLA_CACHE", None):
        kolla_argv.append("--cache")

    if environ.get("PULL", None) == "1":
        kolla_argv.append("--pull")

    if environ.get("SHOULD_PUSH", None) == "1":
        kolla_argv.append("--push")

    build_tag = environ.get("DOCKER_TAG", None)
    if build_tag:
        kolla_argv.extend( ["--tag", build_tag])

    # allow selecting images to build via profile or pattern.
    # If unset, build all images with a known profile
    build_profile = environ.get("KOLLA_BUILD_PROFILE", None)
    build_pattern = environ.get("KOLLA_BUILD_PATTERN", None)
    if build_profile:
        kolla_argv.extend( ["--profile", build_profile])
    elif build_pattern:
        kolla_argv.append(build_pattern)
    else:
        for profile in PROFILES:
            kolla_argv.extend( ["--profile", profile])


    print("kolla-build \\")
    print("  " + " \\\n  ".join(kolla_argv))
    print()

    # Kolla reads its input straight from sys.argv
    sys.argv = [""] + kolla_argv
    bad, good, unmatched, skipped, unbuildable, fail_allowed  = kolla_build.run_build()
    if bad:
        sys.exit(1)

    for img in good:
        print(f"built {img}")


if __name__ == "__main__":
    main()
