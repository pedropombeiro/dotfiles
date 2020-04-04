# Better completion for killall.
zstyle ':completion:*:killall:*' command 'ps -u $USER -o cmd'
