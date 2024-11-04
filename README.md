# kolla-containers

A central repository of build customizations for [Kolla](https://docs.openstack.org/kolla/latest/) containers specific to Chameleon, and automated triggers for rebuilding pieces of Kolla's image tree when sources change.

To build images, we invoke kolla's `kolla-build` tool, with config files and arguments packaged in this repo.

## Installation


1. Using the build utilities requires having Python 3 and the `venv` module installed:
   ```
   apt-get install python3-venv
   ```
1. Create the virtualenv:
   ```
   python3 -m venv .venv
   ```
1. Ensure the kolla version is present under `src/kolla`:
   ```
   git submodule update --init`
   ```
1. Finally, install into the venv:
   ```
   .venv/bin/pip install src/kolla
   ```

## Configuration

The kolla-build tool's documentation can be found here: https://docs.openstack.org/kolla/latest/admin/image-building.html#building-kolla-images

Fundamentally, kolla can take 3 different sources of configuration: arguments passed to the commandline, 1 or more configuration file, and 1 or more template files.

Commandline arguments can also be entered in the `[Default]` section of the kolla-build.conf file, which also supports overrides for specific services, such as `--registry` becoming `registry`.

### Profiles

Specifying a profile in the config file allows a specific list of containers to be built, by matching a regex against the container names. For example if we add `ironic = ^ironic(?!-neutron),dnsmasq`, invoking `kolla-build --profile ironic` will build all containers starting with `ironic`, excluding `ironic-neutron-agent`, and finally also include `dnsmasq`. 

This is most often useful to rebuild just the containers needed to support one service, without wasting time rebuilding all the others.

### Specifying a service fork

By default all Kolla images build from tarballs published by OpenStack. Many of Chameleon's forks are by contrast built via local Git clones. When forking a service, add an entry for the service's base image in the `kolla-build.conf` and have it use Git as the source; there are several examples in the configuration already.

Additional notes:

- Kolla supports adding [additions](https://docs.openstack.org/kolla/latest/admin/image-building.html#additions-functionality) to images at build time, which can be a useful
  tool when trying to add in additional sources into a specific image (we do this
  to add a custom Horizon theme, for example.)

- The `kolla-template-overrides.j2` Jinja file is used to override or customize the templating of the
  Dockerfile(s) written out by Kolla. See an [example Dockerfile (horizon)](https://github.com/openstack/kolla/blob/master/docker/horizon/Dockerfile.j2) in Kolla
  for more context in to how this works.

## Building a container

Containers can be built by invoking the `run.sh` script. This is a simple wrapper around kolla-build, specifying our default `kolla-build.conf` and `kolla-template-overrides.j2` files, and otherwise passing all remaining arguments directly to `kolla-build.`

```
# Build container for Horizon
./run.sh  --profile horizon

# Build containers for Nova
./run.sh  --profile nova
```

By default, all containers will be tagged with the git short-sha of this repo. If there are un-committed modifications, the tag will include `-dirty`.

Assuming the git-sha for HEAD is `ee83055d89bf48a920723881c4ce2d007d41c1d8`, 
Building with a clean repo will tag containers with: `ee83055`, from `git rev-parse --short HEAD`. If you have local changes, it will instead tag with `ee83055-dirty`.

If you push the containers, this will allow deploying them at a site for testing without overriding `latest` and so on.

CI in github-actions is responsible for tagging containers with more human-readable names, such as `stable/2023.1`, `latest`, and so on.


### Bypassing cache

If you wish to force a rebuild of all parent images, you can do so by passing in the `--no-use-cache` flag:

```
# Force a rebuild of all parent images
./run.sh python build.py --config-set horizon --no-use-cache
```

### Automatically pushing images to a Docker Registry

The `--push` flag can be used to instruct Kolla to push the images up to a registry once they are built:

```
./run.sh --profile horizon --push
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
