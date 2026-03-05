# Security Policy

## Reporting a Vulnerability

If you discover a security issue in this repository, please
[open a GitHub issue](https://github.com/pedropombeiro/dotfiles/issues/new).

Since this is a personal dotfiles repository, there is no formal SLA,
but reports are appreciated and will be addressed promptly.

## How Secrets Are Handled

This repository **never** stores secrets directly. Sensitive data is managed through:

- **1Password CLI** (`op`) for credentials, API tokens, and SSH keys
- **YADM alternate files** with the `##class.Work` suffix to isolate
  work-specific configuration from the public repository
- **Global gitignore** (`.config/dotfiles/git/gitignore-global`) to
  prevent accidental commits of sensitive file types
- **GPG** for commit signing

YADM encryption (`yadm encrypt`) is not used; 1Password is the
single source of truth for secrets.

## What Is Excluded

The global gitignore and `.gitignore` exclude patterns such as:

- `.env` and credential files
- Private keys and certificates
- Application caches and local databases
- OS-generated metadata (`.DS_Store`, Thumbs.db)
