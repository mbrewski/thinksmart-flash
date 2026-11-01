#!/usr/bin/env python3
import sys, time
import usb.core

for i in range(180):
    ids = [(d.idVendor, d.idProduct) for d in usb.core.find(find_all=True)]
    if (0x05C6, 0x9008) in ids:
        print("DONE: EDL 9008 present", flush=True)
        sys.exit(0)
    if (0x18D1, 0xD00D) in ids:
        print("ACTION_REQUIRED: fastboot present", flush=True)
        sys.exit(1)
    time.sleep(2)
print("FAILED: no EDL after 6 minutes", flush=True)
sys.exit(1)
