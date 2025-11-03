<!--
SPDX-FileCopyrightText: 2023 Slavi Pantaleev
SPDX-FileCopyrightText: 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# syncstorage-rs-docker Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [*syncstorage-rs*](https://github.com/mozilla-services/syncstorage-rs), Mozilla Sync Storage server in Rust used to power Firefox Sync, with [*syncstorage-rs-docker*](https://app.radicle.xyz/nodes/seed.radicle.garden/rad%3Az4J84n7U8ea9A91oD1WjAVY6ybU7g) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

>[!NOTE]
> This role is configured to build the Docker image by default, as it is not provided by the upstream project. Before proceeding, make sure that the machine which you are going to run the Ansible commands against has sufficient computing power to build it.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [defaults/main.yml](defaults/main.yml) for the full list of supported options.

💡 See this [document](docs/configuring-syncstorage-rs-docker.md) for details about setting up the service with this role.

## Development

You can optionally install [pre-commit](https://pre-commit.com/) so that simple mistakes are checked and noticed before changes are pushed to a remote branch. See [`.pre-commit-config.yaml`](./.pre-commit-config.yaml) for which hooks are to be executed.

See [this section](https://pre-commit.com/#usage) on the official documentation for usage.
