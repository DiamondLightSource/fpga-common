# Use register definitions to create API

from __future__ import print_function

import os
import sys
import numpy

from fpga_lib import parse


# Helper function for reading signed values from unsigned field
def to_signed(x, bits):
    # First convert from 2's complement to offset, then add in the offset.
    return (x ^ (1 << (bits - 1))) + (-1 << (bits - 1))


# Reads and writes a bit-field in a register
class Field:
    def __init__(self, field):
        self._name = field.name
        self._range = field.range

    def _read(self, parent):
        offset, length = self._range
        mask = (1 << length) - 1

        reg = parent._read_value()
        return (reg >> offset) & mask

    def _write(self, parent, value):
        offset, length = self._range
        mask = (1 << length) - 1

        assert value == value & mask, \
            'Cannot write %d to field %s' % (value, self._name)
        mask = mask << offset

        reg = parent._read_value()
        parent._write_value((value << offset) | (reg & ~mask))


# Dummy storage for register without hardware.
class DummyBase:
    def __init__(self, value):
        self.value = value

    def _read_value(self, offset, rw):
        return self.value

    def _write_value(self, offset, rw, value):
        self.value = value


# Computes a register class from the given register parse and fields
def make_register(register, fields):
    class Register(object):
        _name = register.name
        __offset = register.offset
        __rw = register.rw

        # This is a dictionary of field accessor methods indexed by field name.
        # We would use property attributes, but they don't play well with
        # __setattr__, in particular we can't block assignment to non-existent
        # fields.
        __fields = {}

        def __init__(self, parent):
            self.__dict__['_Register__parent'] = parent

        def __getattr__(self, name):
            try:
                read, write = self.__fields[name]
            except KeyError:
                # If no support in fields, look for this in the dictionary
                return self.__dict__[name]
            else:
                # Delegate named fields to their associated read method
                return read(self)

        def __setattr__(self, name, value):
            # Only allow existing fields to be updated
            read, write = self.__fields[name]
            write(self, value)


        def _read_value(self):
            return self.__parent._read_value(self.__offset, self.__rw)

        def _write_value(self, value):
            self.__parent._write_value(self.__offset, self.__rw, value)


        def _get_fields(self, read = True):
            value = self._value if read else 0
            return self.__class__(DummyBase(value))

        def __set_fields(self, value):
            self._value = value._value


        @property
        def _fields_wo(self):
            return self._get_fields(False)


        # Single action update of a group of fields
        def __write_fields(self, do_read, fields):
            update = self._get_fields(do_read)
            for field, value in fields.items():
                setattr(update, field, value)
            self.__set_fields(update)

        def _write_fields_wo(self, **fields):
            self.__write_fields(False, fields)

        def _write_fields_rw(self, **fields):
            self.__write_fields(True, fields)

        @classmethod
        def _writer(cls, parent, value):
            register = cls(parent)
            if isinstance(value, (int, numpy.integer)):
                register._write_value(value)
            elif isinstance(value, Register):
                register.__set_fields(value)
            else:
                assert False

        # Populate all the fields including the two special fields
        #
        # _value returns the underlying register value
        __fields['_value'] = (_read_value, _write_value)
        # _fields returns an updatable image of the current register settings as
        # a group of settable fields
        __fields['_fields'] = (_get_fields, __set_fields)
        # Populate the rest of the fields and remember the field names
        _field_names = []
        for field in fields:
            __fields[field._name] = (field._read, field._write)
            _field_names.append(field._name)


        def __repr__(self):
            if self._field_names:
                fields = self._fields
                values = ', '.join(
                    '%s = %d' % (name, getattr(fields, name))
                    for name in self._field_names)
            else:
                values = '%d' % self._value
            return '<Reg %s @%d %s>' % (self._name, self.__offset, values)

    return Register


class Delegator(object):
    def __init__(self, parent):
        self.__dict__['_Delegator__parent'] = parent

    def _read_value(self, offset, rw):
        return self.__parent._read_value(offset, rw)

    def _write_value(self, offset, rw, value):
        self.__parent._write_value(offset, rw, value)

    @classmethod
    def _inject_methods(cls, **methods):
        for name, method in methods.items():
            setattr(cls, name, method)

    def __setattr__(self, name, value):
        # Block accidential assignment to non-existent fields
        assert False, 'Cannot assign to field %s' % name


def make_array(array, fields):
    class RegisterArray(Delegator):
        _name = array.name
        __range = array.range
        __rw = array.rw

        def __getitem__(self, index):
            base, length = self.__range
            assert 0 <= index < length, 'Index out of range'

            # Build a temporary register to wrap this entry
            register = parse.register_defines.Register(
                self._name, base + index, self.__rw, fields, None, [])
            return make_register(register, fields)(self)
            return self._read_value(base + index, self.__rw)

        def __repr__(self):
            base, length = self.__range
            return '<RegArray %s @%d [%d]>' % (self._name, base, length)

    return RegisterArray


def add_attributes(target, attributes):
    for attribute in attributes:
        if isinstance(attribute, list):
            # When we parsed an overlay we were returned a list of attributes
            add_attributes(target, attribute)
        else:
            setattr(target, attribute._name,
                property(attribute, getattr(attribute, '_writer', None)))


# An ordinary group just delegates its attributes
def make_group(group, attributes):
    class Group(Delegator):
        _name = group.name

        def __repr__(self):
            return '<Group %s: %s>' % (
                self._name,
                ', '.join(field for field in dir(self) if field[0] != '_'))

    add_attributes(Group, attributes)

    return Group


def make_top(group, attributes):
    class Top:
        _name = group.name

        def __init__(self, hardware):
            self.__hardware = hardware
            # Cached values for write only registers
            self.__values = {}

        def _read_value(self, offset, rw):
            if rw == 'W':
                # Write only register, return cached value
                return self.__values.get(offset, 0)
            elif rw == 'WP':
                # Pulse register, only ever reads as zero
                return 0
            else:
                return self.__hardware._read_value(offset)

        def _write_value(self, offset, rw, value):
            assert rw != 'R', 'Writing to read only register'
            if rw == 'W':
                # Cache value written to write-only register
                self.__values[offset] = value
            self.__hardware._write_value(offset, value)

        def __repr__(self):
            return '<Top %s: %s>' % (
                self._name,
                ', '.join(field for field in dir(self) if field[0] != '_'))

    add_attributes(Top, attributes)

    return Top


class GenerateMethods(parse.register_defines.WalkParse):
    def walk_field(self, context, field):
        return Field(field)

    def walk_register_array(self, context, array):
        return make_array(array, self.walk_fields(context, array))

    def walk_register(self, context, register):
        return make_register(register, self.walk_fields(context, register))

    def walk_group(self, context, group):
        subgroups = self.walk_subgroups(context, group)
        if group.hidden:
            return subgroups
        else:
            return make_group(group, subgroups)

    def walk_rw_pair(self, context, rw_pair):
        return [
            self.walk_register(context, register)
            for register in rw_pair.registers]

    def walk_overlay(self, context, overlay):
        # Overlay registers are a bit tricky: the register number is the overlay
        # index, not the register offset, so fix this as we walk each register
        registers = [
            self.walk_register(
                context, register._replace(offset = overlay.offset))
            for register in overlay.registers]
        return make_group(overlay, registers)

    def walk_union(self, context, union):
        return self.walk_subgroups(context, union)

    def walk_top(self, group):
        return make_top(group, self.walk_subgroups(None, group))


generate = GenerateMethods()


def load_register_defs(defs_path):
    # Read the definitions in parsed form
    defs = parse.parsed_defs(defs_path, flatten = True)

    groups = {}
    for group in defs.groups:
        groups[group.name] = generate.walk_top(group)

    class Constants:
        def __init__(self):
            for constant in defs.constants.values():
                setattr(self, constant.name, constant.value)
    constants = Constants()

    return (groups, constants)
