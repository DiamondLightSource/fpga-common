#!/usr/bin/env python

from __future__ import print_function

from collections import namedtuple, OrderedDict

__all__ = ['parse_regs', 'Register', 'Constant', 'Group']


# Types of register definition
Constant = namedtuple('Constant', ['register', 'value'])
Register = namedtuple('Register',
    ['register', 'offset', 'width', 'value', 'read_only'])
# A group is a list of registers
Group = namedtuple('Group', ['registers'])


# Returns an iterator over all of the lines in the source file.  Continuation
# lines are gathered into a list, each entry is a tuple of the fields on each
# line.
def parse_lines(input_file):
    line_parse = []

    with open(input_file, 'r') as input:
        for line_no, line in enumerate(input.readlines()):
            assert line[-1] == '\n', 'Missing newline on line %d' % line_no
            line = line[:-1]

            # Remove comments from line and ignore empty lines
            hash = line.find('#')
            if hash >= 0:
                line = line[:hash].rstrip()

            if line:
                split = tuple(line.split())
                if line[0] == ' ':
                    # Treat this as a continuation for the previous line, ensure
                    # we have a line to append to
                    assert len(line_parse) >= 1, \
                        'No line to continue on line %d' % line_no
                else:
                    # Yield any previous parse and reset the parse
                    if line_parse:
                        yield (line_no, name, line_parse)
                    line_parse = []
                    name = split[0]
                    split = split[1:]

                line_parse.append(split)

    # Ensure we emit the last line
    if line_parse:
        yield (line_no, name, line_parse)


def int0(string):
    return int(string, 0)

def parse_register(register, range, default, read_only = False):
    register = int0(register)
    range = range.split(':', 1)
    default = int0(default)
    if read_only:
        assert read_only == 'R', 'Invalid register marker'
        read_only = True
    if len(range) == 1:
        offset = int0(range[0])
        width = 1
    else:
        offset = int0(range[1])
        width = int0(range[0]) - offset + 1
    assert width > 0, 'Invalid register width: %d' % width
    return Register(register, offset, width, default, read_only)

def parse_group(defs):
    return Group([parse_register(*d) for d in defs])

def parse_constant(register, value):
    register = int0(register)
    value = int0(value)
    return Constant(register, value)


def parse_regs(reg_file):
    reg_map = OrderedDict()
    for line_no, name, defs in parse_lines(reg_file):
        try:
            assert name not in reg_map, 'Duplicate name %r' % name

            if len(defs) == 1:
                defs = defs[0]
                if len(defs) == 2:
                    result = parse_constant(*defs)
                elif len(defs) >= 3:
                    result = parse_register(*defs)
                else:
                    assert False, 'Malformed register definition'
            else:
                result = parse_group(defs)
            reg_map[name] = result
        except Exception as e:
            print('Line %d: %s' % (line_no, e))
            raise
    return reg_map


def format_Constant(constant):
    print('0x%02X 0x%08X' % (constant.register, constant.value))

def format_Register(register):
    offset = register.offset
    width = register.width
    if width > 1:
        span = '%d:%d' % (offset + width - 1, offset)
    else:
        span = '%d' % offset
    print('0x%02X %s 0x%X' % (register.register, span, register.value))

def format_Group(group):
    registers = group.registers
    format_Register(registers[0])
    for register in registers[1:]:
        print('%-36s' % '', end = '')
        format_Register(register)

format_methods = dict(
    Constant = format_Constant,
    Register = format_Register,
    Group = format_Group)

def emit_registers(reg_map):
    for name, register in reg_map.items():
        print('%-36s' % name, end = '')
        format_methods[register.__class__.__name__](register)


if __name__ == '__main__':
    import sys
    emit_registers(parse_regs(sys.argv[1]))
