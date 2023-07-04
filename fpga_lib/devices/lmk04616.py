# Device support for LMK04616

import time

from .reg_fields import FieldWriter

class LMK04616(FieldWriter):
    _DeviceName = 'LMK04616'

    def dummy_writer(self, offset, value):
        print('PLL[%03X] <= %02X' % (offset, value))

    # Writes PLL configuration as described in section 9.5.1 of the reference
    # SNAS663B.
    def write_config(self):
        # Trigger soft reset
        self._write(0x000, 0x81)

        # Write all the fields in sequence
        self.enable_write()
        self._write_fields((0, 0x153))

        # Enable start; this is a register bypass
        self._write(0x011, 1)

        # Enable PLL2 digital lock detect
        self._write(0xAD, 0x30)
        time.sleep(0.1)
        self._write(0xAD, 0)
