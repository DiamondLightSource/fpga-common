# Device support for LMK04616

from .reg_fields import FieldWriter

def dummy_write(offset, value):
    print('PLL[%03X] <= %02X' % (offset, value))

class LMK04616(FieldWriter):
    def __init__(self, lmk = None):
        if lmk:
            writer = lmk.write
        else:
            writer = dummy_write
        self.__write = writer
        FieldWriter.__init__(self, 'LMK04616', writer)

    # Writes PLL configuration as described on Page 49 9.5.1
    def write_config(self):
        # Write all the fields in sequence
        self.enable_write()
        self._write_fields((0, 0x153))

        # Enable start; this is a register bypass
        self.__write(0x11, 1)
