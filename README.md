# service-containers

## Adding a service definition

Each service requires at minimum a folder tree in this repository named after
the service. This folder should contain at minimum a `kolla-build.conf` and a
`Jenkinsfile`.

### `kolla-build.conf`

The `kolla-build.conf` file is where Kolla looks to find sources for OpenStack
services. For our purposes, it's where we link our forks of OpenStack components
and also where we pin components to a specific OpenStack release. In addition to
the service-specific build configuration in the service folder, the root level
`kolla-build.conf` file is used for all service builds as a default
configuration.

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

## Building a container

The supported services can be build using a `make` task suffixed with "-build".
For example:

```
# Build container for Horizon
make horizon-build

# Build container for Nova Compute
make nova-compute-build
```

### Building with local sources

If you are utilizing the `kolla-build.local-sources.conf` functionality, the
container can be built with a second, special make target which invokes Kolla
with these overrides in place:

```
# Build container for Horizon, using local sources
make horizon-build-with-locals
```

## Rocky upgrade notes

### Neutron

There is a `networking-baremetal` project added in the Pike release that adds a new `ironic-neutron-agent` system. We may want to start building and using that.
