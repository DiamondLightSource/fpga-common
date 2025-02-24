# Device support for LMK04828

from .reg_fields import FieldWriter

class LMK04828(FieldWriter):
    _DeviceName = 'LMK04828'

    def dummy_writer(self, offset, value):
        print('PLL[%03X] <= %02X' % (offset, value))

    # Writes PLL configuration
    def write_config(self):
        assert False, 'Not implemented yet'
