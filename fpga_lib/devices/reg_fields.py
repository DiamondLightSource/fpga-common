# Helper script for interfacing to packed fields in a hardware device

import os
from collections import namedtuple, OrderedDict

from .parse_regs import *


Field = namedtuple('Field', ['register', 'offset', 'width', 'read_only'])


def _make_field(reg):
    return Field(reg.register, reg.offset, reg.width, reg.read_only)


# This class is used to map logical packed fields to hardware registers.
# This class should be subclassed and _DeviceName defined
class FieldWriter(object):
    def __load_register_defs(self):
        device_name = self._DeviceName
        if '/' not in device_name:
            # Look for the specified device in the current directory
            here = os.path.dirname(__file__)
            device_name = os.path.join(here, device_name + '.regs')
        return parse_regs(device_name)

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
            fields = (_make_field(field),)
            read_only = field.read_only
        else:
            # More complicated.
            # First assemble the default value
            field = field.registers
            default = field[0].value
            read_only = field[0].read_only
            for f in field[1:]:
                default = (default << f.width) | f.value
                read_only = read_only or f.read_only

            # Next extract the list of field definitions in little endian order
            # for register generation.
            fields = tuple(reversed([_make_field(f) for f in field]))
        return fields, default, read_only

    # Register definitions will be read from the given file
    def __init__(self, writer = None, reader = None):
        if writer is None:
            # Fallback to simple text output
            writer = self.dummy_writer

        self._write = writer    # Write to register
        self._read = reader     # Optional, read from register
        self.__live = False     # Switch between cached and direct access
        self.__registers = {}   # Maps register numbers to values
        self.__dirty = set()    # Set of changed registers
        self.__fields = {}      # Maps names to definitions

        # Walk the register definitions
        for name, rdef in self.__load_register_defs().items():
            if isinstance(rdef, (Register, Group)):
                fields, default, read_only = self.__compute_fields(rdef)
                self.__fields[name] = fields
                if not read_only:
                    self.__write_value(name, default)
            elif isinstance(rdef, Constant):
                # Constants are used to initialise individual registers.  The
                # register name is not saved
                self._write_register(rdef.register, rdef.value)
            else:
                assert False, 'Invalid register definition'

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
        for f in self.__fields[name]:
            assert not f.read_only, \
                'Cannot write to read-only register %s' % name
            field_mask = ((1 << f.width) - 1) << f.offset
            reg_value = self._read_register(f.register) & ~field_mask
            field_value = (value << f.offset) & field_mask
            value >>= f.width

            self._write_register(f.register, reg_value | field_value)
        assert value == 0, 'Value for %s too large for field' % name

    # Reads given value directly from hardware
    def __read_value(self, name):
        value = 0
        for f in reversed(self.__fields[name]):
            reg_value = self._read_register(f.register)
            field_mask = ((1 << f.width) - 1) << f.offset
            reg_value = (reg_value >> f.offset) & ((1 << f.width) - 1)
            value = (value << f.width) | reg_value
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
