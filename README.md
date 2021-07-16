# kolla-containers

A central repository of build customizations for [Kolla](https://docs.openstack.org/kolla/latest/) containers specific to Chameleon, and automated triggers for rebuilding pieces of Kolla's image tree when sources change.

## Setup

Using the build utilities requires having Python 3 and the `venv` module installed:

```
# e.g., for Ubuntu/Debian
apt-get install python3-venv
```

## Adding a service definition

Each Kolla service requires at minimum a folder tree in this repository named after
the service. This folder should contain at minimum a `kolla-build.conf` and a
`Jenkinsfile`. This is called the "build profile" in some of the tooling.

> **Note**: the folder must be named with alphanumeric characters. This is because the folder name will be used as a "profile" name in Kolla, and those are Python configuration keys, which don't like e.g. hyphens.

### `kolla-build.conf`

The `kolla-build.conf` file is where Kolla looks to find sources for OpenStack
services. For our purposes, it's where we link our forks of OpenStack components
and also where we pin components to a specific OpenStack release. In addition to
the service-specific build configuration in the service folder, the root level
`kolla-build.conf` file is used for all service builds as a default
configuration.

Importantly, the build configuration must include a `[profiles]` section with
an entry named after the folder containing the build profile, e.g. for "horizon":

```
# Maps profile names to a regex of what images should be built for this profile
[profiles]
horizon = ^horizon
```

Kolla supports adding [additions](https://docs.openstack.org/kolla/latest/admin/image-building.html#additions-functionality) to images at build time, which can be a useful
tool when trying to add in additional sources into a specific image (we do this
to add a custom Horizon theme, for example.)

### `kolla-build.local-sources.conf`

If present, this file will be used by the special `build-with-locals` make
targets. This file will override the `kolla-build.conf` file for the service,
allowing you to specify pulling source distributions from local disk as opposed
to pulling them in dynamically via Git or a tarball. Pulling from local sources
is an optimization that can speed up subsequent builds as the Docker layer cache
is more effectively utilized.

### `kolla-template-overrides.j2`

This Jinja file is used to override or customize the templating of the
Dockerfile written out by Kolla. See an [example Dockerfile (horizon)](https://github.com/openstack/kolla/blob/master/docker/horizon/Dockerfile.j2) in Kolla
for more context in to how this works.

### `.env`

This is an optional env file that can override the options in the default `.env`
file located at the root of this directory. This is most useful for when you would
like to build from a different OpenStack base release just for your build profile.
In this case you can override the `OPENSTACK_BASE_RELEASE` env variable like so:

```shell
# Use Tran release for this build
OPENSTACK_BASE_RELEASE=train
```

See the `.env` file at the root of the directory to see what else can be overridden.

## Building a container

The supported services can be build using a `make` task and specifying a build profile with the `KOLLA_BUILD_PROFILE` environment variable. The value of this variable should have a corresponding directory in the root of this repository.

```
# Build container for Horizon
KOLLA_BUILD_PROFILE=horizon ./run.sh python build.py --push --use-cache

# Build containers for Nova
KOLLA_BUILD_PROFILE=nova ./run.sh python build.py --push --use-cache
```

### Building with local sources

If you are utilizing the `kolla-build.local-sources.conf` functionality, the
container can be built with a second, special make target which invokes Kolla
with these overrides in place:

```
# Build container for Horizon, using local sources
KOLLA_BUILD_PROFILE=horizon ./run.sh python build.py --push --use-cache
```

### Bypassing cache

If you wish to force a rebuild of all parent images, you can do so by passing in the `KOLLA_USE_CACHE` environment variable:

```
# Force a rebuild of all parent images
KOLLA_BUILD_PROFILE=horizon KOLLA_USE_CACHE=no ./run.sh python build.py --push --use-cache
```

### Automatically pushing images to a Docker Registry

The `KOLLA_PUSH` environment variable can be used to instruct Kolla to push the images up to a registry once they are built:

```
# When done building, push Docker images to registry
KOLLA_BUILD_PROFILE=horizon KOLLA_PUSH=yes ./run.sh python build.py --push --use-cache
```

### Cross-compiling

It is possible to cross-compile Docker images in order to, e.g., build an ARM image on an x86 machine. Docker BuildKit has support built-in for this, but `docker-py` does not yet have support for BuildKit. Fortunately, [it is possible to configure Docker in a more general way for cross-compiling](https://www.stereolabs.com/docs/docker/building-arm-container-on-x86/).

```shell
sudo apt-get install qemu binfmt-support qemu-user-static # Install the qemu packages
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Once the above is complete, you can set the platform by specifying `DOCKER_DEFAULT_PLATFORM` to, e.g. "linux/arm64".

```shell
DOCKER_DEFAULT_PLATFORM=linux/arm64 KOLLA_BASE_ARCH=aarch64 KOLLA_BUILD_PROFILE=base ./run.sh python build.py --push --use-cache
```
