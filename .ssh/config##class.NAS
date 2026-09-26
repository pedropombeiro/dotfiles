# https://gitlab.com/-/snippets/2153849
Include config.d/*

Host *
  ServerAliveInterval=15
  ServerAliveCountMax=20
  IgnoreUnknown UseKeychain
Host *.repo.borgbase.com
  IdentityFile /etc/config/ssh/id_ed25519
Host nas nas.home.pombei.ro
  HostName nas
  User admin
  RequestTTY yes
Host monitor monitor.home.pombei.ro
  HostName monitor
  User pi
  RemoteCommand cd /etc && exec zsh --login
  RequestTTY yes
Host unifi unifi.infra.pombei.ro gateway gateway.infra.pombei.ro
  User root
Host switch switch.infra.pombei.ro
  User pombeiro_admin
Host ap ap.infra.pombei.ro
  HostName ap-nanohd
  User pombeiro_admin

Host gitlab.com
  UseKeychain yes
  # Workaround UniFi Traffic inspector blocking SSH connections to GitLab
  # as ET SCAN Potential SSH Scan OUTBOUND: https://about.gitlab.com/blog/2016/02/18/gitlab-dot-com-now-supports-an-alternate-git-plus-ssh-port/
  Hostname altssh.gitlab.com
  User git
  Port 443
  PreferredAuthentications publickey
Host github.com
  UseKeychain yes
