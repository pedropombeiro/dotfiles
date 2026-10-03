# Security Policy

## Reporting a Vulnerability

If you discover a security issue in this repository, please
[open a GitHub issue](https://github.com/pedropombeiro/dotfiles/issues/new).

Since this is a personal dotfiles repository, there is no formal SLA,
but reports are appreciated and will be addressed promptly.

## How Secrets Are Handled

This repository **never** stores secrets directly. Sensitive data is managed through:

- **1Password CLI** (`op`) for credentials, API tokens, and SSH keys
- **A private repository** for internal Work files, such as internal hosts and
  access scripts. YADM alternates such as `##class.Work` only select which file
  a machine uses; they are tracked in this public repository like any other
  file. See [the public repository rules](../.agents/docs/yadm-layout.md#public-repository).
- **gitleaks** in the hk hooks and CI to catch committed credentials
- **Global gitignore** (`.config/git/ignore`) to
  prevent accidental commits of sensitive file types
- **SSH commit signing** through the 1Password SSH agent

YADM encryption (`yadm encrypt`) is not used; 1Password is the
single source of truth for secrets.

## What Is Excluded

The global gitignore and `.gitignore` exclude patterns such as:

- `.env` and credential files
- Private keys and certificates
- Application caches and local databases
- OS-generated metadata (`.DS_Store`, Thumbs.db)
