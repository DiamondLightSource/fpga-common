# Device support for LMK04828

from .reg_fields import FieldWriter

def dummy_write(offset, value):
    print('PLL[%03X] <= %02X' % (offset, value))

class LMK04828(FieldWriter):
    def __init__(self, lmk = None):
        if lmk:
            writer = lmk.write
        else:
            writer = dummy_write
        self.__write = writer
        FieldWriter.__init__(self, 'LMK04828', writer)

    # Writes PLL configuration
    def write_config(self):
        pass
