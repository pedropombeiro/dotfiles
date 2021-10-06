.PHONY: pull
pull:
	@yadm fetch && \
	 yadm reset --hard origin/master

.PHONY: install
install:
	@yadm bootstrap

.PHONY: update
update:
	@if [ "$(shell uname -s)" = "Linux" ]; then \
		.install/linux/update.sh; \
	else \
		.install/osx/update.sh; \
	fi

.PHONY: brew-dump
brew-dump:
	@brew bundle dump -f --global --describe
