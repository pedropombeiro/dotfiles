.PHONY: pull
pull:
	@/usr/bin/git --git-dir=$(HOME)/.cfg/ --work-tree=$(HOME) fetch origin && \
	 /usr/bin/git --git-dir=$(HOME)/.cfg/ --work-tree=$(HOME) reset --hard origin/master

.PHONY: install
install:
	@if [ "$(shell uname -s)" = "Linux" ]; then \
		.install/linux/install.sh; \
	else \
		.install/osx/install.sh; \
	fi

.PHONY: update
update:
	@if [ "$(shell uname -s)" = "Linux" ]; then \
		.install/linux/update.sh; \
	else \
		.install/osx/update.sh; \
	fi
