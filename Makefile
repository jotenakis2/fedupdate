BIN_DIR=/usr/local/bin
MAN_DIR=/usr/local/share/man/man1
SYSTEMD_USER_DIR=$(HOME)/.config/systemd/user
SCRIPTS=fedupdate post-upgrade-message.sh
SYSTEMD_UNITS=checkupdate.service checkupdate.timer postupgrade.service
MAN_PAGE=fedupdate.1

# Install scripts and systemd units
install: install_scripts install_man install_systemd

install_scripts:
	@echo "Installing scripts to $(BIN_DIR)..."
	@sudo install -m 755 $(SCRIPTS) $(BIN_DIR)

install_man:
	@echo "Installing man page to $(MAN_DIR)..."
	@sudo install -m 644 $(MAN_PAGE) $(MAN_DIR)
	@sudo mandb >/dev/null 2>&1

install_systemd:
	@echo "Installing systemd user units..."
	@mkdir -p $(SYSTEMD_USER_DIR)
	@install -m 644 $(SYSTEMD_UNITS) $(SYSTEMD_USER_DIR)
	@systemctl --user daemon-reload
	@systemctl --user enable checkupdate.service
	@systemctl --user --now enable checkupdate.timer
	@systemctl --user enable postupgrade.service

# Uninstall scripts and systemd units
uninstall: uninstall_scripts uninstall_man uninstall_systemd

uninstall_scripts:
	@echo "Removing scripts from $(BIN_DIR)..."
	@for script in $(SCRIPTS); do \
		if [ -f $(BIN_DIR)/$$script ]; then \
			sudo rm -f $(BIN_DIR)/$$script && echo "$$script removed." || echo "Failed to remove $$script."; \
		else \
			echo "No script $$script to remove in $(BIN_DIR)."; \
		fi; \
	done

uninstall_man:
	@echo "Removing man page from $(MAN_DIR)..."
	@if [ -f $(MAN_DIR)/$(MAN_PAGE) ]; then \
		sudo rm -f $(MAN_DIR)/$(MAN_PAGE) && echo "$(MAN_PAGE) removed." || echo "Failed to remove $(MAN_PAGE)."; \
	else \
		echo "No man page to remove in $(MAN_DIR)."; \
	fi
	@sudo mandb >/dev/null 2>&1

uninstall_systemd:
	@echo "Removing systemd user units..."
	@for unit in $(SYSTEMD_UNITS); do \
		if systemctl --user list-units --full --all | grep -q "$$unit"; then \
			echo "Stopping $$unit..."; \
			systemctl --user stop $$unit 2>/dev/null || echo "$$unit was not active."; \
			systemctl --user disable $$unit 2>/dev/null || echo "Failed to disable $$unit."; \
		fi; \
		echo "Removing $$unit..."; \
		sudo rm -f $(SYSTEMD_USER_DIR)/$$unit && echo "$$unit removed." || echo "Failed to remove $$unit."; \
	done
	@systemctl --user daemon-reload

.PHONY: install uninstall install_scripts install_man install_systemd uninstall_scripts uninstall_man uninstall_systemd
