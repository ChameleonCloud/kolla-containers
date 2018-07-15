# service-containers

## Adding a service definition

Each service requires at minimum a folder tree in this repository with a
`config.json` file. This file is used to instruct the Kolla runtime wrapper
script how to run the underlying service when the container starts. It mostly
consists of a "command" (what process actually want to start) and then a
"config_files" section, which provides a way to move around and change ownership
of configuration files relevant for the service.

## Building a container

The supported services can be build using a `make` task prefixed with "build-".
For example:

```
# Build container for Horizon
$> make build-horizon

# Build container for Nova Compute
$> make build-nova-compute
```

## Running a container

The `start_container` script is provided as a convenience for operators and
sets up the container with the necessary environment and volume mounts for the
Kolla wrapper script to start the process. This script can be copied to the
target machine or run locally.

```
$> bin/start_container horizon
```
