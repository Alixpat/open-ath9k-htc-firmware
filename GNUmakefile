# Makefile — AR9271 custom firmware build wrapper
#
# Usage:
#   make                  # Build MCS0 firmware (max range)
#   make MCS=3            # Build MCS3 firmware (26 Mbit/s)
#   make install          # Install last built firmware
#   make install MCS=0    # Build + install MCS0
#   make clean-fw         # Clean firmware build (keep toolchain)
#   make clean-all        # Clean everything including toolchain

MCS ?= 0

.PHONY: all firmware install clean-fw clean-all

all: firmware

firmware:
	@bash build.sh $(MCS)

install: firmware
	@sudo bash install.sh firmware/htc_9271-MCS$(MCS).fw

clean-fw:
	make -f Makefile -C target_firmware clean 2>/dev/null || true
	rm -rf firmware/

clean-all: clean-fw
	rm -rf toolchain/build/ toolchain/inst/ toolchain/dl/
