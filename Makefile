.PHONY: pull
pull:
	@yadm fetch && \
	 yadm reset --hard origin/master

.PHONY: install
install:
	@yadm bootstrap

.PHONY: update
update:
	@~/.config/yadm/scripts/update.sh

.PHONY: brew-dump
brew-dump:
	@brew bundle dump -f --global --describe
