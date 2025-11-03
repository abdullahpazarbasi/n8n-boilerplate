# n8n Boilerplate

[n8n](https://n8n.io/) platform with [Cloudflare](https://one.dash.cloudflare.com/) Tunnel in [minikube](https://github.com/kubernetes/minikube)

## Supported Operating Systems

- Linux (Debian based with bash)
- macOS (Darwin with bash & brew)

## Installation

```sh
make setup
```

## Extras

### Additional Postgres DB Creation

> **Usage:**
>
> ```sh
> ./scripts/create-db-in-postgres.sh -n <DB_NAME> -u <DB_USER> -p <DB_PASS> [-P <profile>] [-s <namespace>] [-l <pod_regex>] [-x <superuser>] [-W <superpass>] [--debug]
> ```
>
> **Example:**
>
> ```sh
> ./scripts/create-db-in-postgres.sh -n authn -u authn -p '12345678' -P n8n
> ```
