# Justfile Configuration

Location: `~/.justfile`

## Available Targets

| Target         | Description                                             |
| -------------- | ------------------------------------------------------- |
| `default`      | Runs `pull` then `update`                               |
| `pull`         | Fetches and resets to origin/master, reloads oh-my-zsh  |
| `install`      | Runs yadm bootstrap                                     |
| `update`       | Runs update script (`~/.config/yadm/scripts/update.sh`) |
| `checkhealth`  | Runs health check script                                |
| `brew-dump`    | Dumps Homebrew bundle to global Brewfile                |
| `brew-cleanup` | Cleans up packages not in Brewfile                      |
| `fix [FILES]`  | Runs pre-commit hooks in manual stage                   |
| `lint [FILES]` | Runs pre-commit hooks                                   |

## Usage

```bash
just          # runs default (pull + update)
just pull     # fetch and reset to origin/master
just lint     # lint all files
just fix foo.sh bar.zsh  # fix specific files
```
