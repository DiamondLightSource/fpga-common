# Helper script for interfacing to packed fields in a hardware device

import os
from collections import namedtuple, OrderedDict

from .parse_regs import *


Field = namedtuple('Field', ['register', 'offset', 'width'])


def load_register_defs(device_name):
    if '/' not in device_name:
        # Look for the specified device in the current directory
        here = os.path.dirname(__file__)
        device_name = os.path.join(here, device_name + '.regs')
    return parse_regs(device_name)


# This class is used to map logical packed fields to hardware registers.
class FieldWriter(object):

    # A field definition is either a single field definition:
    #   (register, offset, width, default)
    # or a list of sub-fields:
    #   [(r1, o1, w1, d1), ..., (rn, on, wn, dn)]
    # We normalise this, extracting the default as a single integer value and
    # returning a list of sub-fields in reverse order:
    #   default, [(rn, on, wn), ..., (r1, o1, w1)]
    def __compute_fields(self, field):
        # Convert field into working format: a field value followed by a
        # list of register sub-fields in byte order.  At this point we need to
        # separate single byte and multiple byte definitions.
        if isinstance(field, Register):
            # Simple case: single field
            default = field.value
            fields = (Field(field.register, field.offset, field.width),)
        else:
            # More complicated.
            # First assemble the default value
            field = field.registers
            default = field[0].value
            for f in field[1:]:
                default = (default << f.width) | f.value

            # Next extract the list of field definitions in little endian order
            # for register generation.
            fields = tuple(reversed([
                Field(f.register, f.offset, f.width) for f in field]))
        return fields, default

    # Register definitions will be read from the given file
    def __init__(self, device_name, write, read = None):
        self._write = write     # Write to register
        self._read = read       # Optionall, read from register
        self.__live = False     # Switch between cached and direct access
        self.__registers = {}   # Maps register numbers to values
        self.__dirty = set()    # Set of changed registers
        self.__fields = {}      # Maps names to definitions

        # Walk the register definitions
        for name, rdef in load_register_defs(device_name).items():
            if isinstance(rdef, (Register, Group)):
                fields, default = self.__compute_fields(rdef)
                self.__fields[name] = fields
                self.__write_value(name, default)
            elif isinstance(rdef, Constant):
                # Constants are used to initialise individual registers.  The
                # register name is not saved
                self._write_register(rdef.register, rdef.value)
            else:
                assert False, 'Invalid register definition'

#         # First walk the fields to fill in any register background constant
#         # settings.  This has to be done first.
#         for name, field_def in self._Fields.__dict__.items():
#             if name[0] == '_':
#                 # Field definitions starting with _ (and not __) are constants
#                 # used to initialise individual registers
#                 if not name.startswith("__"):
#                     reg, value = field_def
#                     self._write_register(reg, value)
# 
#         # Gather list of valid field names in format for processing.
#         self.__fields = {}      # Maps names to definitions
#         for name, field_def in self._Fields.__dict__.items():
#             if name[0] != '_':
#                 # Normal fields
#                 assert name not in self.__fields
#                 default, fields = self.__compute_fields(field_def)
#                 self.__fields[name] = fields
# 
#                 # Fill in the initial register values from the default
#                 self.__write_value(name, default)


    # Call this to enable writing to hardware
    def enable_write(self, live = True):
        self.__live = live


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Field and register access, in three tiers of implementation:
    #
    #   _{read,write}_register
    #       Direct accessed to numbered registers when device is live, or to
    #       cached values otherwise.  Cached written values are marked as dirty
    #       so they can be flushed later.
    #
    #   __{read,write}_value
    #       Access to named values by reading and writing the appropriate
    #       registers and assembling fields as appropriate.
    #
    #   __getattr__, __setattr__
    #       Attribute access to named fields, wrappers around the private value
    #       access methods.

    # Writes single register to hardware or to cache if not live
    def _write_register(self, reg, value):
        self.__registers[reg] = value
        if self.__live:
            self._write(reg, value)
            self.__dirty.discard(reg)
        else:
            self.__dirty.add(reg)

    # Reads single register from hardware or from cached value
    # Not currently supported
    def _read_register(self, reg):
        if self.__live:
            value = self._read(reg)
            self.__registers[reg] = value
            self.__dirty.discard(reg)
            return value
        else:
            return self.__registers.setdefault(reg, 0)


    # Updates the registers associated with the given named field.
    def __write_value(self, name, value):
        for reg, offset, width in self.__fields[name]:
            field_mask = ((1 << width) - 1) << offset
            reg_value = self._read_register(reg) & ~field_mask
            field_value = (value << offset) & field_mask
            value >>= width

            self._write_register(reg, reg_value | field_value)
        assert value == 0, 'Value for %s too large for field' % name

    # Reads given value directly from hardware
    def __read_value(self, name):
        value = 0
        for reg, offset, width in reversed(self.__fields[name]):
            reg_value = self._read_register(reg)
            field_mask = ((1 << width) - 1) << offset
            reg_value = (reg_value >> offset) & ((1 << width) - 1)
            value = (value << width) | reg_value
        return value


    # Writes to field, writing to hardware if appropriate.
    def __setattr__(self, name, value):
        if name[0] == '_':
            # Allow local attributes to be set directly
            self.__dict__[name] = value
        elif name in self.__fields:
            # Named registers are written specially
            self.__write_value(name, value)
        else:
            assert False, 'Cannot write to attribute %s' % name

    # Reads specified field from hardware or from cached value if not live
    def __getattr__(self, name):
        if name in self.__fields:
            return self.__read_value(name)
        else:
            raise AttributeError('Cannot read attribute %s' % name)


    # This should be called after creation to write the initial state to
    # hardware in the correct order.  All defined registers in the given range
    # are written in sequence.
    def _write_fields(self, range):
        assert self.__live
        first, last = range
        for reg in sorted(self.__dirty):
            if first <= reg <= last:
                self._write_register(reg, self.__registers[reg])


    # Context manager support
    def __enter__(self):
        self.enable_write(False)

    def __exit__(self, *args):
        self.enable_write(True)

        # Flush all dirty registers
        self._write_fields()
