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

import pydot #needed to load graphvis dependency from kolla-build
import networkx as nx #traverse dependency graph
from jinja2 import Environment, FileSystemLoader, select_autoescape  # template docker bakefile
from python_on_whales import docker  # docker cli wrapper, has buildx support

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
    "--profile",
    metavar="NAME",
    help=(
        "Which build profile to use (this affects which set(s) of containers are built."
    ),
    multiple=True,
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
def cli(
    config_file=None,
    config_set=None,
    profile=None,
    build_dir=None,
    push=None,
    use_cache=None,
):
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

    profile = profile or os.getenv("KOLLA_BUILD_PROFILE")
    if profile:
        kolla_config["profile"] = profile

    kolla_argv = []
    for arg, value in kolla_config.items():
        if arg == "profile":
            for entry in value:
                kolla_argv.append(f"--{arg.replace('_', '-')}={entry}")
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

    if "profile" in kolla_config:
        for profile in kolla_config["profile"]:
            additions_dir = pathlib.Path(profile, "additions")
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

    templates_dir = pathlib.Path("templates").absolute()

    os.chdir(build_dir.absolute())

    dep_path = pathlib.Path("./kolla_deps.DOT").absolute()

    kolla_argv.append("--save-dependency")
    kolla_argv.append(str(dep_path))

    print("kolla-build \\")
    print("  " + " \\\n  ".join(kolla_argv))
    print()

    # Kolla reads its input straight from sys.argv
    sys.argv = [""] + kolla_argv
    try:
        result = kolla_build.run_build()
    except Exception as ex:
        print(ex.args)
        sys.exit(1)


    targets = get_docker_contexts(dep_graph_path=dep_path,
                        docker_base_path=pathlib.Path("docker"),
                        docker_registry=kolla_config.get("registry"),
                        namespace=kolla_config.get("namespace"))

    bakefile = template_bakefile(pathlib.Path("."), targets, templates_dir)
    run_buildx_bake(bakefile=bakefile)

def get_docker_contexts(dep_graph_path, docker_base_path, docker_registry, namespace):
    graphs = pydot.graph_from_dot_file(str(dep_graph_path))
    print("Loaded dependency graph from:", str(dep_graph_path))

    pydot_graph = graphs[0]
    G = nx.nx_pydot.from_pydot(pydot_graph)
    openstack_dep_order = nx.dfs_preorder_nodes(G,"openstack-base")

    #TODO this shouldn't be static
    src_tags = [
        "latest",
        "92384459237",
    ]

    targets = []
    for node in openstack_dep_order:
        tags = [f"{docker_registry}/{namespace}/{node}:{tag}" for tag in src_tags]
        prefix = str(node).split("-")[0]

        node_path = pathlib.Path(docker_base_path, node)
        if not node_path.exists():
            node_path = pathlib.Path(docker_base_path, prefix, node)
        target_dict = {
            "name": node,
            "context": str(node_path),
            "tags": tags
        }

        print(node, node_path, node_path.exists())
        if node_path.exists():
            targets.append(target_dict)

    return targets

def template_bakefile(build_path, targets, templates_dir):
    env = Environment(
        loader=FileSystemLoader(templates_dir),
        autoescape=select_autoescape()
    )
    template = env.get_template("docker-bake.hcl.j2")

    target_names = [target['name'] for target in targets]

    bakefile_text = template.render(target_names=target_names, targets=targets)
    bakefile = pathlib.Path(build_path, "docker-bake.hcl")

    with open(bakefile, 'w+',) as f:
        f.write(bakefile_text)

    return bakefile


def run_buildx_bake(bakefile):
    docker.buildx.bake(
       files=[bakefile]
)

if __name__ == "__main__":
    cli()
