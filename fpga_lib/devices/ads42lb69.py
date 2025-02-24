# Device support for ADS42LB69

from .reg_fields import FieldWriter

class ADS42LB69(FieldWriter):
    _DeviceName = 'ADS42LB69'
    _WriteFieldRange = (0, 32)

    def dummy_writer(self, offset, value):
        print('ADC[%2d] <= %02X' % (offset, value))

    def write_config(self):
        # Software reset of ADC
        self._write(0x08, 0x01)

        self.enable_write()
        self._write_fields()
