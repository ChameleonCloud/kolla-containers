#!/usr/bin/env python
# Copyright 2021 University of Chicago
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import os
import pathlib
import shutil
import tarfile
import sys

import click
from jinja2 import Environment, FileSystemLoader, select_autoescape
from kolla.image import build as kolla_build
import yaml


@click.command("build")
@click.option(
    "--config-file",
    metavar="FILE",
    default="build_config.yaml",
    help=("The YAML configuration file that holds the configuration sets."),
)
@click.option(
    "--config-set",
    metavar="NAME",
    help=("Which configuration set defined in the configuration file to use."),
)
@click.option(
    "--build-dir",
    metavar="DIR",
    default="build",
    help=(
        "The build directory to use as the build context for this build. "
        "If you are runnning multiple builds in parallel, use different "
        "build directories for each to avoid cross-contamination of build "
        "sources and configuration."
    ),
)
@click.option(
    "--push/--no-push",
    default=False,
    help=("Whether to push the images to a Docker registry on successful build."),
)
@click.option(
    "--use-cache/--no-use-cache",
    default=True,
    help=(
        "Whether to attempt to use cached images in the build chain. There are two "
        "layers of cache: the first will not even attempt to re-build an image's "
        "parent if the parent image/tag is detected on the host system, the second "
        "will instruct Docker to use cached Dockerfile build steps w/in a single "
        "build invocation."
    ),
)
def cli(config_file=None, config_set=None, build_dir=None, push=None, use_cache=None):
    build_config = {}
    with open(config_file, "r") as f:
        build_config = yaml.safe_load(f)

    build_dir = pathlib.Path(build_dir)
    build_dir.mkdir(exist_ok=True)
    source_dir = pathlib.Path("./sources")
    source_dir.mkdir(exist_ok=True)

    kolla_config = {
        # We will chdir into the build directory before invoking Kolla
        "work_dir": ".",
        "config_file": "kolla-build.conf",
        "template_override": "kolla-template-overrides.j2",
        "locals_base": "../sources",
    }

    default_config_set = build_config.get("defaults", {})
    # Extract build conf extras; they are not a "real" kolla config
    # option and can't be passed to Kolla.
    build_conf_extras = default_config_set.pop("build_conf_extras", {})
    if default_config_set:
        kolla_config.update(default_config_set)

    if config_set:
        config_set = build_config.get("config_sets", {}).get(config_set)
        if not config_set:
            raise ValueError(f"No config set found for '{config_set}'")
        cfgset_build_conf_extras = config_set.pop("build_conf_extras", {})
        kolla_config.update(config_set)
        build_conf_extras.update(cfgset_build_conf_extras)

    kolla_namespace = os.getenv("KOLLA_NAMESPACE")
    if kolla_namespace:
        kolla_config["namespace"] = kolla_namespace

    docker_tag = os.getenv("DOCKER_TAG")
    if docker_tag:
        kolla_config["tag"] = docker_tag
    openstack_release = os.getenv("OPENSTACK_BASE_RELEASE")
    if openstack_release:
        kolla_config["openstack_release"] = openstack_release
    profile = os.getenv("KOLLA_BUILD_PROFILE")
    if profile:
        kolla_config["profile"] = profile

    kolla_argv = []
    for arg, value in kolla_config.items():
        if arg == "profiles":
            for profile in value:
                kolla_argv.append(f"--profile={profile}")
        elif value is not None:
            kolla_argv.append(f"--{arg.replace('_', '-')}={value}")

    if push:
        kolla_argv.append("--push")
    if use_cache:
        # Always skip ancestors; we want to explicitly build the ancestor
        # images instead of automagically doing this.
        kolla_argv.append("--skip-parents")
        kolla_argv.append("--cache")
    else:
        kolla_argv.append("--nocache")

    def add_tar_path(additions_dir: pathlib.Path):
        if additions_dir.exists():
            with tarfile.open(source_dir.joinpath("additions.tar"), "w") as tar:
                tar.add(additions_dir, arcname=os.path.sep)

    if "profiles" in kolla_config:
        for profile in kolla_config["profiles"]:
            additions_dir = pathlib.Path(profile, "additions")
            add_tar_path(additions_dir)
    elif "profile" in kolla_config:
        additions_dir = pathlib.Path(kolla_config["profile"], "additions")
        add_tar_path(additions_dir)

    shutil.copy(
        "./kolla-template-overrides.j2",
        build_dir.joinpath("kolla-template-overrides.j2"),
    )

    env = Environment(loader=FileSystemLoader("."), autoescape=select_autoescape())
    kolla_build_conf_tmpl = env.get_template("kolla-build.conf.j2")
    with open(pathlib.Path(build_dir, "kolla-build.conf"), "w") as f:
        tmpl_vars = kolla_config.copy()
        tmpl_vars.update(build_conf_extras)
        f.write(kolla_build_conf_tmpl.render(**tmpl_vars))

    os.chdir(build_dir.absolute())

    print("kolla-build \\")
    print("  " + " \\\n  ".join(kolla_argv))
    print()

    # Kolla reads its input straight from sys.argv
    sys.argv = [""] + kolla_argv
    bad, good, unmatched, skipped, unbuildable = kolla_build.run_build()
    if bad:
        sys.exit(1)


if __name__ == "__main__":
    cli()
