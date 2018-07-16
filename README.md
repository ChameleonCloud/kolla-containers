# service-containers

## Adding a service definition

Each service requires at minimum a folder tree in this repository beneath the
[`runtime_configs`][./runtime_configs] path with a `config.json` file.
This file is used to instruct the Kolla runtime wrapper
script how to run the underlying service when the container starts. It mostly
consists of a "command" (what process actually want to start) and then a
"config_files" section, which provides a way to move around and change ownership
of configuration files relevant for the service.

### Templating configuration

The runtime configs use Jinja2 templates. There are some [global variables][./runtime_configs/globals.yaml]
that are available for all templates.

## Building a container

The supported services can be build using a `make` task suffixed with "-build".
For example:

```
# Build container for Horizon
$> make horizon-build

# Build container for Nova Compute
$> make nova-compute-build
```

## Generating configuration

The runtime configuration for services is not packaged in the container.
Instead, the configuration is assumed to be located in a pre-defined location
on the host system, currently `/etc/kolla` (to play nice with Kolla builds).

To generate these configuration files, run a `make` task suffixed with "-genconfig".

```
# Will output tar file in current directory with name of service
$> make horizon-genconfig
```

The tarball can then be uploaded and installed on the host machine. An example
extraction command might be:

```
# Safely extracts to /etc/kolla instead of /
$> tar -C /etc/kolla --strip-components=2 -xvf horizon.tar
```

## Running a container

To run a container locally, run a `make` task suffixed with "-run".

```
$> make horizon-run
```

This uses the [`start_container`][./bin/start_container] helper script under the
hood. This script is responsible for setting up the container's environment
properly, ensuring it has all volume mounts and environment variables set.

**Note**: Because Kolla likes to use `--net=host`, which isn't really compatible
with Docker for Mac, port binding will not work. This is an open issue to solve,
probably with a `docker-compose` environment for running containers locally, or
else explicitly broadcasting ports when running the container.
