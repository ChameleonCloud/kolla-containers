# kolla-containers

A central repository of build customizations for [Kolla](https://docs.openstack.org/kolla/latest/) containers specific to Chameleon, and automated triggers for rebuilding pieces of Kolla's image tree when sources change.

## Setup

Using the build utilities requires having Python 3 and the `venv` module installed:

```
# e.g., for Ubuntu/Debian
apt-get install python3-venv
```

## Configuration sets

Each Kolla service requires at minimum either its own configuration set defined in the `build_config.yaml`, or being added to an existing configuration set.
To add a service's images to the list of images that will be built for a given configuration set, update the regex in the `[profiles]` section of the `kolla-build.conf`; one or more configuration sets will reference one of these build profiles.

Configuration sets can also be used to override specific Kolla build flags, such as the target base distro, tag, or architecture/platform.

### Adding support for a new service fork

By default all Kolla images build from tarballs published by OpenStack. Many of Chameleon's forks are by contrast built via local Git clones. When forking a service, add an entry for the service's base image in the `kolla-build.conf` and have it use Git as the source; there are several examples in the configuration already.

Additional notes:

- Kolla supports adding [additions](https://docs.openstack.org/kolla/latest/admin/image-building.html#additions-functionality) to images at build time, which can be a useful
  tool when trying to add in additional sources into a specific image (we do this
  to add a custom Horizon theme, for example.)

- The `kolla-template-overrides.j2` Jinja file is used to override or customize the templating of the
  Dockerfile(s) written out by Kolla. See an [example Dockerfile (horizon)](https://github.com/openstack/kolla/blob/master/docker/horizon/Dockerfile.j2) in Kolla
  for more context in to how this works.

## Building a container

The supported services can be build using the `build.py` script and passing the name of a configuration set
and a profile name. The configuration sets are defined in the `build_config.yaml` file and set things
like the platform/architecture and base distro for the build.

```
# Build container for Horizon
./run.sh python build.py --config-set x86_ubuntu --profile horizon

# Build containers for Nova
./run.sh python build.py --config-set x86_ubuntu --profile nova
```

### Bypassing cache

If you wish to force a rebuild of all parent images, you can do so by passing in the `--no-use-cache` flag:

```
# Force a rebuild of all parent images
./run.sh python build.py --config-set horizon --no-use-cache
```

### Automatically pushing images to a Docker Registry

The `--push` flag can be used to instruct Kolla to push the images up to a registry once they are built:

```
./run.sh python build.py --config-set x86_ubuntu --profile horizon --push
```

### Cross-compiling

It is possible to cross-compile Docker images in order to, e.g., build an ARM image on an x86 machine. Docker BuildKit has support built-in for this, but `docker-py` does not yet have support for BuildKit. Fortunately, [it is possible to configure Docker in a more general way for cross-compiling](https://www.stereolabs.com/docs/docker/building-arm-container-on-x86/).

**Ubuntu**

```shell
# Install additional QEMU support packages
sudo apt-get install qemu binfmt-support qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

**RHEL**

```shell
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Once the above is complete, you can set the `platform` in a config set to the target platform, e.g.:

```yaml
config_sets:
  base_aarch64:
    platform: linux/arm64
```

```shell
./run.sh python build.py --config-set base_aarch64
```
