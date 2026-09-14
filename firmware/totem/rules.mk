# split-forge firmware additions for the Totem Vial keymap.
# Merge these lines into your Totem Vial keymap's rules.mk.

# Enable Raw HID so the keymap can broadcast the active layer to the host.
# (Vial already uses the Raw HID interface; this just ensures raw_hid_send is available.)
RAW_ENABLE = yes

# Only needed if you use option (B) from keymap_broadcast.c (drop-in file instead of
# pasting the functions into keymap.c). Uncomment if so:
# SRC += keymap_broadcast.c
