# GitHub Copilot CLI Sandbox

A Docker sandbox that lets GitHub Copilot CLI run `az` and `aws` commands safely — destructive operations are intercepted, logged, and blocked before they reach the cloud.

## How it works

`az` and `aws` in `PATH` are wrapper scripts. When Copilot invokes a CLI command, the wrapper checks it against a blocklist. If it matches, the command is rejected and logged. Otherwise it is forwarded to the real binary.

```
Copilot → /usr/local/bin/az (wrapper) → blocklist check → /opt/az/bin/az-real
                                       ↓ blocked
                                  logs/sandbox-blocked.log
```

Cloud credentials (`~/.aws`, `~/.azure`) are mounted **read-only** — even if a command slips through, write operations require IAM permissions that a read-only credential set will not have.

## Requirements

- Docker Desktop (macOS / Windows / Linux)
- GitHub Copilot CLI access

## Getting started

```bash
# 1. Build the image
make build

# 2. Authenticate (one time)
#    Launches a bash shell — run `copilot auth login` inside
make shell

# 3. Run Copilot in your project
cd /path/to/your/project
copilot-sandbox          # or: bash sandbox.sh
```

After `make install`, `copilot-sandbox` is available globally:

```bash
make install             # symlinks sandbox.sh → /usr/local/bin/copilot-sandbox
copilot-sandbox          # copilot --allow-all-tools in the current directory
copilot-sandbox bash     # debug shell
```

### Windows

```powershell
# Build
docker compose build

# Run (from your project directory)
& "C:\path\to\sandbox-copilot\sandbox.ps1"
& "C:\path\to\sandbox-copilot\sandbox.ps1" bash
```

Requires Docker Desktop with WSL2 backend.

## Customising the blocklist

Edit the config files — no rebuild needed (they are read at runtime inside the container):

| File | Applies to |
|------|-----------|
| `config/az-blocklist.conf` | Azure CLI (`az`) |
| `config/aws-blocklist.conf` | AWS CLI (`aws`) |

One pattern per line. Lines starting with `#` are comments.

```
# config/az-blocklist.conf
delete
purge
remove
deallocate
```

Patterns are matched as substrings against the **subcommand** (positional args only — flag values like `--tags "env=delete-me"` are never checked).

Hard-coded special cases that are always blocked regardless of the config:
- `az rest --method DELETE`
- `aws s3 rm`, `s3 rb`, `s3 mv`, `s3 sync --delete`

## Viewing blocked commands

```bash
make logs                     # on the host
# or inside the container:
cat /sandbox-logs/sandbox-blocked.log
```

## Project layout

```
.
├── Dockerfile                # Container definition
├── docker-compose.yml        # Used by `make build`
├── sandbox.sh                # Launcher (macOS / Linux)
├── sandbox.ps1               # Launcher (Windows / PowerShell)
├── Makefile                  # build / run / install helpers
├── config/
│   ├── az-blocklist.conf     # Editable Azure blocklist
│   └── aws-blocklist.conf    # Editable AWS blocklist
├── scripts/
│   ├── entrypoint.sh         # Container startup (keyring, banner)
│   ├── az-wrapper.sh         # Azure CLI interceptor
│   └── aws-wrapper.sh        # AWS CLI interceptor
└── logs/
    └── sandbox-blocked.log   # Blocked command log (gitignored)
```

## Make targets

| Target | Description |
|--------|-------------|
| `make build` | Build the Docker image |
| `make run` | Run Copilot in the current directory |
| `make shell` | Open a bash shell in the container |
| `make install` | Install `copilot-sandbox` globally |
| `make logs` | Print the blocked command log |
| `make clean` | Stop running sandbox sessions |
| `make clean-all` | Stop + remove image and auth volume |

## Security notes

- Wrappers can be bypassed by calling the real binary directly (`/opt/az/bin/az-real`). This sandbox is a **usability-layer guard**, not a hard security boundary.
- The real guarantee against accidental cloud writes is using **read-only IAM credentials** (e.g. Azure `Reader` role, AWS `ReadOnlyAccess` policy) on the account whose credentials you mount.
- Running as root inside the container is a known limitation. For stricter isolation, add a non-root `USER` to the Dockerfile and adjust volume permissions accordingly.
