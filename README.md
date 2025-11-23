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

### AI-Related Services

- [Ollama](https://ollama.com/): Cross-platform LLM platform to install and run the latest local LLMs
- [Qdrant](https://qdrant.tech/): Open-source, high performance vector store with a comprehensive API

### Ollama Model Pulling

First, you should access the shell of ollama

```sh
make ollama-shell-connected
```

After that,

you can pull `GPT-OSS LLM`

```sh
ollama pull gpt-oss
```

you can pull `BGE M3 Embedding Model`

```sh
ollama pull bge-m3
```

### Suggested n8n Community Nodes

- [n8n-nodes-globals](https://www.npmjs.com/package/n8n-nodes-globals)
- [n8n-nodes-base64](https://www.npmjs.com/package/n8n-nodes-base64)
