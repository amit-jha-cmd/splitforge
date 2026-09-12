# split-forge firmware additions for the Totem Vial keymap.
# Merge these lines into your Totem Vial keymap's rules.mk.

# Enable Raw HID so the keymap can broadcast the active layer to the host.
# (Vial already uses the Raw HID interface; this just ensures raw_hid_send is available.)
RAW_ENABLE = yes

# Only needed if you use option (B) from keymap_broadcast.c (drop-in file instead of
# pasting the functions into keymap.c). Uncomment if so:
# SRC += keymap_broadcast.c

# Cirque 40 mm trackpad on the right half — see plan/cirque-trackpad.md
# This also sets I2C_DRIVER_REQUIRED = yes, which emits -DHAL_USE_I2C=TRUE and
# pulls in i2c_master.c — which is why no halconf.h is needed.
POINTING_DEVICE_ENABLE = yes
POINTING_DEVICE_DRIVER = cirque_pinnacle_i2c
