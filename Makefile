.PHONY: install
install:
	@if [ "$(shell uname -s)" = "Linux" ]; then \
		.install/linux/install.sh; \
	else \
		.install/osx/install.sh; \
	fi

.PHONY: upgrade
upgrade:
	@if [ "$(shell uname -s)" = "Linux" ]; then \
		.install/linux/upgrade.sh; \
	else \
		.install/osx/upgrade.sh; \
	fi
