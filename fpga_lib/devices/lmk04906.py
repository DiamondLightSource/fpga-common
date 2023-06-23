# Device support for LMK04906

from .reg_fields import FieldWriter

def dummy_write(offset, value):
    print('PLL[%02d] <= %08X' % (offset, value | offset))

class LMK04906(FieldWriter):
    def __init__(self, lmk):
        if lmk:
            writer = lmk.write
        else:
            writer = dummy_write
        self.__write = writer
        FieldWriter.__init__(self, 'LMK04906', writer)

    # Writes PLL configuration as described on Page 49 9.5.1
    def write_config(self):
        # Start by triggering a reset of the LMK.  We bypass the register
        # interface for this special operation.
        self.__write(0, 1 << 17)

        # Now write all the fields in sequence
        self.enable_write()
        self._write_fields((0, 31))
