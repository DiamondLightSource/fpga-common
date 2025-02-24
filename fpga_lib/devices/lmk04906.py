# Device support for LMK04906

from .reg_fields import FieldWriter

class LMK04906(FieldWriter):
    _DeviceName = 'LMK04906'
    _WriteFieldRange = (0, 31)

    def dummy_writer(self, offset, value):
        print('PLL[%02d] <= %08X' % (offset, value | offset))

    # Writes PLL configuration as described on Page 49 9.5.1
    def write_config(self):
        # Start by triggering a reset of the LMK.  We bypass the register
        # interface for this special operation.
        self._write(0, 1 << 17)

        # Now write all the fields in sequence
        self.enable_write()
        self._write_fields()
