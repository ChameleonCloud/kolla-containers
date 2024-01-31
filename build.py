#!python3


import sys
from os import environ
from pathlib import Path

from kolla.image import build as kolla_build

PROFILES= [
    "base",
    # "blazar",
    # "cinder",
    # "doni",
    # "glance",
    # "gnocchi",
    # "heat",
    # "horizon",
    # "ironic",
    # "keystone",
    # "manila",
    # "neutron",
    # "nova",
    # "placement",
    # "tunelo",
    # "zun",
]

LOCALS_BASE=Path.cwd().joinpath("sources")
WORKDIR=Path.cwd().joinpath("build")

def main():
    kolla_argv = []

    kolla_argv.extend( ["--config-file", "kolla-build.conf"] )
    kolla_argv.extend( ["--template-override", "kolla-template-overrides.j2"])

    kolla_argv.extend( ["--locals-base", LOCALS_BASE.as_posix()])
    kolla_argv.extend( ["--work-dir", WORKDIR.as_posix()])
    kolla_argv.extend( ["--threads", "1"] )

    # don't re-pull our custom base image if present
    # kolla_argv.extend( ["--nopull"] )


    for profile in PROFILES:
        kolla_argv.extend( ["--profile", profile])

    # kolla_argv.extend( ["^base$"] )
    # kolla_argv.extend( ["--profile", "base"] )

    print("kolla-build \\")
    print("  ".join(kolla_argv))
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
