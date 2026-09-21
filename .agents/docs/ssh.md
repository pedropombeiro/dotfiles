# SSH Configuration

## NAS Session Persistence

`ssh_persist` reconnects an SSH session after a transport failure. The NAS iTerm2
profile runs `zsh -ic 'ssh_persist nas'` so that the function is available in its
new shell.

The function retries only when `ssh` exits with status `255`, which OpenSSH uses
for a local transport failure. It returns all other statuses so that an explicit
remote logout closes the iTerm2 tab. Reconnection uses an exponential delay from
one second to a maximum of 15 seconds. Interrupt the wrapper with `Ctrl-C` to
stop reconnecting.

The NAS starts or reconnects to tmux through
`~/.shellrc/zshrc.d/configs/tmux.platform.zsh##distro.qts`. A successful SSH
reconnection therefore returns to the existing tmux session.

## Keepalive settings

The default SSH configuration sends a server-alive request every 15 seconds.
The `nas` host has `ServerAliveCountMax 2`, so OpenSSH treats an unresponsive
connection as failed after about 30 seconds. The global count remains 20 for
other hosts.

macOS sleep can leave an SSH TCP connection half-open. The NAS can receive and
act on keystrokes while replies do not reach the terminal, which looks like a
frozen session. SSH cannot resume such a TCP connection. The keepalive detects
the failed transport and `ssh_persist` establishes a new one.

## Alternatives

Entware provides `mosh-server` for the NAS. Mosh can resume across network
changes, but it can alter terminal escape-sequence behavior. Keep plain SSH for
the NAS because the tmux setup relies on OSC 52 clipboard, OSC 133 prompt
markers, and iTerm2 sequences.
