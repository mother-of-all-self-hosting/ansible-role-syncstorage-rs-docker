<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up syncstorage-rs-docker

This is an [Ansible](https://www.ansible.com/) role which installs [*syncstorage-rs*](https://github.com/mozilla-services/syncstorage-rs), Mozilla Sync Storage server in Rust used to power Firefox Sync, with [*syncstorage-rs-docker*](https://codeberg.org/acioustick/syncstorage-rs-docker) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

See the project's [documentation](https://github.com/mozilla-services/syncstorage-rs/blob/master/README.md) to learn what syncstorage-rs does and [*syncstorage-rs-docker*](https://codeberg.org/acioustick/syncstorage-rs-docker)'s documentation about how to set it up.

>[!NOTE]
> Setting up your own Firefox Account server is out of scope of this role. See [this page](https://moz-services-docs.readthedocs.io/en/latest/howtos/run-fxa.html) for details about how to set it up.

## Prerequisites

To run a syncstorage-rs-docker instance it is necessary to prepare a [MySQL](https://www.mysql.com/) compatible database server.

If you are looking for an Ansible role for [MariaDB](https://mariadb.org/), you can check out [this role (ansible-role-mariadb)](https://github.com/mother-of-all-self-hosting/ansible-role-mariadb) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team.

## Adjusting the playbook configuration

To enable syncstorage-rs-docker with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# syncstorage-rs-docker                                                #
#                                                                      #
########################################################################

syncstorage_rs_docker_enabled: true

########################################################################
#                                                                      #
# /syncstorage-rs-docker                                               #
#                                                                      #
########################################################################
```

### Set the hostname

To enable syncstorage-rs-docker you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
syncstorage_rs_docker_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting syncstorage-rs-docker under a subpath (by configuring the `syncstorage_rs_docker_path_prefix` variable) does not seem to be possible due to syncstorage-rs-docker's technical limitations.

### Set values for secrets

You also need to specify values for two secrets by adding the following configuration to your `vars.yml` file:

```yaml
syncstorage_rs_docker_environment_variable_sync_master_secret: YOUR_SECRET_VALUE_FOR_MASTER_SYNC_KEY_HERE

syncstorage_rs_docker_environment_variable_metrics_hash_secret: YOUR_SECRET_VALUE_FOR_METRICS_HASH_HERE
```

As they must be 64 characters long, they can be generated with `pwgen -s 64 1` or in another way.

### Configure a MySQL database

You can set variables for a MySQL database by adjusting the configuration on your `vars.yml` file as below:

```yaml
syncstorage_rs_docker_environment_variable_database_username: sync
syncstorage_rs_docker_environment_variable_database_hostname: localhost
syncstorage_rs_docker_environment_variable_database_host_port: 3306
```

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `syncstorage_rs_docker_environment_variables_additional_variables` variable

See its [environment variables](https://codeberg.org/acioustick/syncstorage-rs-docker/src/branch/main/example.env) for a complete list of syncstorage-rs-docker's config options that you could put in `syncstorage_rs_docker_environment_variables_additional_variables`.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, syncstorage-rs-docker becomes available at the specified hostname such as `example.com`.

See [this section](https://codeberg.org/acioustick/syncstorage-rs-docker/src/branch/main#adjusting-firefox-setting) on the documentation for details about how to configure Firefox to have it use your server for data synchronization.

>[!NOTE]
> Log your Firefox out of Firefox Account server if the browser is already signed in, and re-log in to apply the change.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu syncstorage-rs-docker` (or how you/your playbook named the service, e.g. `mash-syncstorage-rs-docker`).
