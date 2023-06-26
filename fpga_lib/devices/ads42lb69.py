# Device support for ADS42LB69

from .reg_fields import FieldWriter

def dummy_write(offset, value):
    print('ADC[%2d] <= %02X' % (offset, value))

class ADS42LB69(FieldWriter):
    def __init__(self, lmk = None):
        if lmk:
            writer = lmk.write
        else:
            writer = dummy_write
        self.__write = writer
        FieldWriter.__init__(self, 'ADS42LB69', writer)

    # Writes PLL configuration
    def write_config(self):
        pass
