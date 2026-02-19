# Parses register definition file into an abstract syntax.

# Syntax of register_defines.in as parsed by parse_register_defs.py
#
#   register_defs = { register_def_entry }*
#   register_def_entry = group_def | shared_def | constant_def
#
#   constant_def = name "=" value
#
#   shared_def = shared_reg_def | shared_group_def
#
#   group_def = "!"["!"]name { group_entry }*
#   group_entry =
#       group_def | reg_def | reg_pair | reg_array | shared_name | reg_overlay
#
#   reg_def = name rw { field_def | field_skip }*
#   field_def = "."name [ width ] [ "@"offset ] [ rw ]
#   field_skip = "-" [ width ]
#
#   reg_pair = "*RW" { reg_def_or_name }2
#   reg_array = name rw count { field_def | field_skip }*
#
#   reg_overlay = "*OVERLAY" name rw { reg_def_or_name }
#   reg_union = "*UNION" { group_entry }
#
#   shared_reg_def = ":"reg_def
#   shared_group_def = ":"group_def
#
#   reg_def_or_name = reg_def | shared_name
#   shared_name = ":"saved_name [{ new_name | - } [rw]]
#
#   rw = "R" | "W" | "RW" | "WP"
#
#   name and new_name are any valid VHDL identifier
#   saved_name is a previously defined shared_reg_def or shared_group_def name
#   count, offset, width are all integers
#   in reg_def_or_name the shared_name must name a register, not a group
#
# The syntax {...}* denotes a list of parses at the indented level, {...}2
# specifies precisely two sub-parses, {...}+ denotes one or more sub-parses.
#
# This concrete syntax is flattened somewhat to generate register groups,
# registers, and field.  Note: we could record the two lists of sub-values as
# separate lists, but then we'd lose the ordering, in particular keeping the
# ordering of fields and bits is important for documentation.
#
#   group = (name, range, [group | register | register_array], definition, doc)
#   register = (name, offset, rw, [field], definition, doc)
#   field = (name, range, is_bit, rw, doc)
#   register_array = (name, range, rw, doc)

from __future__ import print_function

import sys
from collections import namedtuple, OrderedDict
import re

from . import indent


# ------------------------------------------------------------------------------
# The following structures are used to return the results of a parse.

Group = namedtuple('Group',
    ['name', 'range', 'hidden', 'content', 'definition', 'doc'])
Register = namedtuple('Register',
    ['name', 'offset', 'rw', 'fields', 'definition', 'doc'])
RegisterArray = namedtuple('RegisterArray',
    ['name', 'range', 'rw', 'fields', 'doc'])
Field = namedtuple('Field',
    ['name', 'range', 'is_bit', 'rw', 'doc'])
RwPair = namedtuple('RwPair',
    ['registers'])
Overlay = namedtuple('Overlay',
    ['name', 'offset', 'rw', 'registers', 'doc'])
Union = namedtuple('Union',
    ['name', 'range', 'content', 'doc'])
Constant = namedtuple('Constant',
    ['name', 'value', 'doc'])

Parse = namedtuple('Parse',
    ['group_defs', 'register_defs', 'groups', 'constants'])


# ------------------------------------------------------------------------------
# Helper functions for walking the parse.

class WalkParse:
    '''This class should be subclassed and the following methods need to be
    defined, then .walk_parse(), .walk_subgroups() and walk_fields() can be
    called to walk the parse:

        def walk_register_array(self, context, array):
        def walk_field(self, context, field):
        def walk_group(self, context, group):
        def walk_register(self, context, reg):
        def walk_rw_pair(self, context, rw_pair):
        def walk_overlay(self, context, overlay):
        def walk_union(self, context, union):
        def walk_constant(self, context, constant):

    '''

    def walk_subgroup(self, context, entry):
        if isinstance(entry, Group):
            return self.walk_group(context, entry)
        elif isinstance(entry, Register):
            return self.walk_register(context, entry)
        elif isinstance(entry, RegisterArray):
            return self.walk_register_array(context, entry)
        elif isinstance(entry, RwPair):
            return self.walk_rw_pair(context, entry)
        elif isinstance(entry, Overlay):
            return self.walk_overlay(context, entry)
        elif isinstance(entry, Union):
            return self.walk_union(context, entry)
        else:
            assert False

    def walk_subgroups(self, context, group):
        return [
            self.walk_subgroup(context, entry)
            for entry in group.content]

    def walk_fields(self, context, register):
        return [
            self.walk_field(context, field)
            for field in register.fields]

    def walk_constant(self, context, constant):
        pass


# ------------------------------------------------------------------------------
# Debug function for printing result of parse

class PrintMethods(WalkParse):
    def __init__(self, name_prefix = ''):
        self.__name_prefix = name_prefix

    def __print_prefix(self, n, prefix):
        sys.stdout.write(n * '    ')
        print(prefix, end = ' ')

    def __print_doc(self, n, doc):
        for d in doc:
            self.__print_prefix(n, '#')
            print(d)

    def __do_print(self, n, prefix, value, *fields):
        self.__print_doc(n, value.doc)
        self.__print_prefix(n, prefix)
        print('%s%s' % (self.__name_prefix, value.name), end = ' ')
        for field in fields:
            print(field, end = ' ')


    # WalkParse interface methods

    def walk_register_array(self, n, array):
        self.__do_print(n, 'A', array, array.range, array.rw)
        print()

    def walk_field(self, n, field):
        self.__do_print(n, 'F', field, field.range, field.is_bit, field.rw)
        print()

    def walk_group(self, n, group):
        self.__do_print(n, 'G', group, group.range)
        if group.definition:
            print(':', group.definition.name, end = ' ')
        print()
        self.walk_subgroups(n + 1, group)

    def walk_register(self, n, reg):
        self.__do_print(n, 'R', reg, reg.offset, reg.rw)
        if reg.definition:
            print(':', reg.definition.name, end = ' ')
        print()
        self.walk_fields(n + 1, reg)

    def walk_rw_pair(self, n, rw_pair):
        self.__print_prefix(n, 'P')
        print()
        for reg in rw_pair.registers:
            self.walk_register(n + 1, reg)

    def walk_overlay(self, n, overlay):
        self.__do_print(n, 'O', overlay, overlay.offset, overlay.rw)
        print()
        for reg in overlay.registers:
            self.walk_register(n + 1, reg)

    def walk_union(self, n, union):
        self.__do_print(n, 'U', union, union.range)
        print()
        self.walk_subgroups(n + 1, union)

    def walk_constant(self, n, constant):
        self.__do_print(n, 'K', constant, constant.value)


def print_parse(parse):
    methods = PrintMethods(':')
    for g in parse.group_defs:
        methods.walk_group(0, g)
    for r in parse.register_defs:
        methods.walk_register(0, r)

    methods = PrintMethods()
    for g in parse.groups:
        methods.walk_group(0, g)
    for k in parse.constants:
        methods.walk_constant(0, k)


# ------------------------------------------------------------------------------
# Parse implementation

def fail_parse(message, line_no):
    from . import FailParse
    raise FailParse('Parse error: %s at line %d' % (message, line_no))

def parse_int(value, line_no):
    try:
        return int(value, 0)
    except:
        fail_parse('Expected integer', line_no)

def check_args(args, min_length, max_length, line_no):
    if len(args) < min_length:
        fail_parse('Expected more arguments', line_no)
    if len(args) > max_length:
        fail_parse('Unexpected extra arguments', line_no)

name_pattern = re.compile(r'[A-Z][A-Z0-9_]*$', re.I)
def check_name(name, line_no):
    if not name_pattern.match(name):
        fail_parse('Invalid name "%s"' % name, line_no)

def check_body(parse):
    if parse.body:
        fail_parse('No sub-definitions allowed here', parse.line_no)

def is_int(value):
    return value and value[0] in '0123456789'

def check_rw(rw, line_no):
    if rw not in ['R', 'W', 'RW', 'WP']:
        fail_parse('Invalid R/W specification %s' % rw, line_no)


def is_field_skip(parse):
    return parse.line.split()[0] == '-'


# field_def = "."name [ width ] [ "@"offset ] [ rw ]
def parse_field_def(offset, parse):
    line, _, doc, line_no = parse
    line = line.split()
    name = line[0]
    args = line[1:]

    check_body(parse)
    if name[0] != '.':
        fail_parse('Expected field definition', line_no)
    name = name[1:]

    if args and is_int(args[0]):
        is_bit = False
        count = parse_int(args[0], line_no)
        del args[0]
    else:
        is_bit = True
        count = 1

    if args and args[0][0] == '@':
        offset = parse_int(args[0][1:], line_no)
        del args[0]

    if count < 0:
        fail_parse('Invalid field width %d' % count, line_no)
    if offset < 0 or offset + count > 32:
        fail_parse(
            'Field (%d,%d) falls outside of register' % (offset, count),
            line_no)

    check_args(args, 0, 1, line_no)
    if args:
        rw = args[0]
        check_rw(rw, line_no)
    else:
        rw = ''

    return (Field(name, (offset, count), is_bit, rw, doc), offset + count)


# field_skip = "-" [ width ]
def parse_field_skip(parse):
    line, body, _, line_no = parse
    line = line.split()
    check_args(line, 1, 2, line_no)

    if len(line) > 1:
        return parse_int(line[1], line_no)
    else:
        return 1


def parse_field_defs(field_list):
    fields = []
    offset = 0
    for parse in field_list:
        if is_field_skip(parse):
            offset += parse_field_skip(parse)
        else:
            field, offset = parse_field_def(offset, parse)
            fields.append(field)
    return fields


# reg_def = name rw { field_def | field_skip }*
def parse_reg_def(offset, parse, expect = [], rw = None):
    line, body, doc, line_no = parse
    line = line.split()
    check_args(line, 1, 2, line_no)
    name = line[0]
    check_name(name, line_no)
    if line[1:]:
        rw = line[1]
    check_rw(rw, line_no)
    if expect and rw not in expect:
        fail_parse('Expected %s field' % expect, line_no)

    fields = parse_field_defs(body)
    return Register(name, offset, rw, fields, None, doc)


# reg_def_or_name = reg_def | shared_name
def parse_reg_def_or_name(offset, parse, defines, expect):
    line, _, _, line_no = parse
    if line[0] == ':':
        result, length = parse_shared_name(offset, parse, defines)
        if not isinstance(result, Register):
            fail_parse('Name %s is not a register' % result.name, line_no)
        assert length == 1
        if expect and result.rw not in expect:
            fail_parse('Expected %s field' % expect, line_no)
        return result
    else:
        return parse_reg_def(offset, parse, expect)


def is_reg_array(parse):
    line = parse[0].split()
    return len(line) > 2 and is_int(line[2])


# reg_array = name count rw
def parse_reg_array(offset, parse):
    line, body, doc, line_no = parse
    line = line.split()
    check_args(line, 3, 3, line_no)
    name = line[0]
    check_name(name, line_no)
    rw = line[1]
    check_rw(rw, line_no)
    count = parse_int(line[2], line_no)
    fields = parse_field_defs(body)
    return (RegisterArray(name, (offset, count), rw, fields, doc), count)
# Note: with a little care we should be able to unify reg_def and reg_array


# reg_pair = "*RW" { reg_def_or_name }2
def parse_reg_pair(offset, parse, defines):
    line, body, _, line_no = parse
    line = line.split()
    check_args(line, 1, 1, line_no)
    if len(body) != 2:
        fail_parse('Must have two registers', line_no)
    return (RwPair([
        parse_reg_def_or_name(
            offset, body[0], defines, expect = ['R']),
        parse_reg_def_or_name(
            offset, body[1], defines, expect = ['W', 'WP'])]), 1)


# reg_overlay = "*OVERLAY" name rw { reg_def_or_name }
def parse_reg_overlay(offset, parse, defines):
    line, body, doc, line_no = parse
    line = line.split()
    check_args(line, 3, 3, line_no)
    name = line[1]
    check_name(name, line_no)
    rw = line[2]
    check_rw(rw, line_no)

    registers = []
    reg_offset = 0
    for parse in body:
        registers.append(
            parse_reg_def_or_name(reg_offset, parse, defines, rw = rw))
        reg_offset += 1
    return (Overlay(name, offset, rw, registers, doc), 1)


# reg_union = "*UNION" { group_entry }
def parse_reg_union(offset, parse):
    line, body, doc, line_no = parse
    line = line.split()
    check_args(line, 1, 2, line_no)
    name = line[1] if line[1:] else ''

    size = 0
    content = []
    for parse in body:
        result, count = parse_group_entry(offset, parse, {})
        content.append(result)
        if count > size: size = count
    return (Union(name, (offset, size), content, doc), size)


# reg_pair or reg_overlay
def parse_special(offset, parse, defines):
    line, _, _, line_no = parse
    line = line.split()
    if line[0] == '*RW':
        return parse_reg_pair(offset, parse, defines)
    elif line[0] == '*OVERLAY':
        return parse_reg_overlay(offset, parse, defines)
    elif line[0] == '*UNION':
        return parse_reg_union(offset, parse)
    else:
        fail_parse('Unexpected special directive', line_no)


# shared_name = ":"saved_name [new_name [rw]]
def parse_shared_name(offset, parse, defines):
    line, body, doc, line_no = parse
    assert line[0] == ':'
    line = line.split()
    key = line[0][1:]   # Remove leading : from key
    if len(line) > 1 and line[1] != '-':
        name = line[1]
    else:
        name = key
    check_name(name, line_no)
    if key not in defines:
        fail_parse('Unknown shared name %s' % key, line_no)
    define = defines[key]
    if isinstance(define, Group):
        if len(line) > 2:
            fail_parse('Cannot specify rw for group', line_no)
        check_body(parse)
        length = define.range[1]
        result = Group(name, (offset, length), False, [], define, doc)
    elif isinstance(define, Register):
        fields = parse_field_defs(body)
        length = 1
        rw = line[2] if len(line) > 2 else define.rw
        check_rw(rw, line_no)
        result = Register(name, offset, rw, fields, define, doc)
    else:
        assert False
    return (result, length)


# Returns a list of results together with the number of registers spanned by the
# returned result.
#
# group_entry = group_def | reg_def | reg_pair | reg_array | shared_name
def parse_group_entry(offset, parse, defines):
    line, body, _, line_no = parse
    if line[0] in '.-':
        fail_parse('Field definition not allowed here', line_no)

    # Dispatch the parse
    if line[0] == ':':
        # shared_name = ":"...
        return parse_shared_name(offset, parse, defines)
    elif line[0] == '*':
        return parse_special(offset, parse, defines)
    elif line[0] == '!':
        # Not a register definition, must be a group
        return parse_group_def(offset, parse, defines)
    elif is_reg_array(parse):
        return parse_reg_array(offset, parse)
    else:
        return (parse_reg_def(offset, parse), 1)


# Parses a group definition, returns the resulting parse together with the
# number of registers in the parsed group
#
# group_def = "!"["!"]name { group_entry }*
def parse_group_def(offset, parse, defines):
    line, body, doc, line_no = parse

    line = line.split()
    name = line[0]
    assert name[0] == '!'
    hidden = name[1] == '!'
    if hidden:
        name = name[2:]
    else:
        name = name[1:]
    check_name(name, line_no)

    check_args(line, 1, 1, line_no)

    content = []
    count = 0
    for entry in body:
        result, entry_count = \
            parse_group_entry(offset + count, entry, defines)
        count += entry_count
        content.append(result)

    return (Group(name, (offset, count), hidden, content, None, doc), count)


# shared_def = shared_reg_def | shared_group_def
def parse_shared_def(parse, defines):
    # Parsing one of shared_reg_def or shared_group_def.
    line = parse.line[1:]
    parse = parse._replace(line = line)
    if line[0] == '!':
        result, _ = parse_group_def(0, parse, defines)
    else:
        result = parse_reg_def(0, parse)
    assert result.name not in defines, \
        'Repeated definition for "%s"' % result.name
    defines[result.name] = result


# constant_def = name "=" value
def parse_constant_def(parse, constants):
    check_body(parse)

    line, _, doc, line_no = parse

    name, value = line.split('=', 1)
    name = name.strip()
    check_name(name, line_no)
    value = int(value, 0)

    constants[name] = Constant(name, value, doc)


# Parse for a top level entry -- either a reusable name definition, if prefixed
# with :, or a top level group definition.
#
# register_def_entry = group_def | shared_def | constant_def
def parse_register_def_entry(parse, defines, constants):
    if parse.line[0] == ':':
        parse_shared_def(parse, defines)
        return []
    elif parse.line[0] == '!':
        group, count = parse_group_def(0, parse, defines)
        return [group]
    elif '=' in parse.line:
        parse_constant_def(parse, constants)
        return []
    else:
        fail_parse(
            'Ungrouped register definition not expected here', parse.line_no)


# Pull the defines apart into register and group definitions.
def separate_defines(defines):
    group_defs = []
    register_defs = []
    for d in defines.values():
        if isinstance(d, Group):
            group_defs.append(d)
        elif isinstance(d, Register):
            register_defs.append(d)
        else:
            assert False
    return group_defs, register_defs


# Converts a list of indented parses into a list of Group definitions
def parse_defs(parse, parsed = None):
    if parsed is None:
        parsed = empty_parse()
    defines, groups, constants = gather_parse_defs(parsed)

    # The incoming parse is a list of (line, [parse], doc, line_no) parses
    for entry in parse:
        groups.extend(parse_register_def_entry(entry, defines, constants))

    group_defs, register_defs = separate_defines(defines)
    return Parse(group_defs, register_defs, groups, constants)


# ------------------------------------------------------------------------------
# Functions to help with combining parses

# Creates a parse as if parsing an empty file
def empty_parse():
    return Parse([], [], [], {})


# Trims a parse to bare bone definitions required for includes
def trim_parse(parsed):
    return Parse(
        [group._replace(content = [])
         for group in parsed.group_defs + parsed.groups],
        [register._replace(fields = []) for register in parsed.register_defs],
        [],
        {})

def extend_defines(defines, list):
    from . import FailParse
    for entry in list:
        if entry.name in defines:
            raise FailParse('Name "%s" repeated in defs' % entry.name)
        defines[entry.name] = entry


# Extracts defines, groups and constants from parsed structure.
def gather_parse_defs(parsed):
    defines = OrderedDict()
    extend_defines(defines, parsed.group_defs)
    extend_defines(defines, parsed.register_defs)
    extend_defines(defines, parsed.groups)
    return (defines, [], parsed.constants)


# ------------------------------------------------------------------------------
# Flattening

class FlattenMethods(WalkParse):
    def walk_field(self, offset, field):
        return field

    def walk_register_array(self, offset, array):
        base, length = array.range
        return array._replace(range = (base + offset, length))

    def walk_group(self, offset, group):
        base, length = group.range
        group_def = group.definition
        if group_def:
            content = self.walk_subgroups(offset + base, group_def)
        else:
            content = self.walk_subgroups(offset, group)
        return group._replace(
            range = (base + offset, length), content = content)

    def walk_register(self, offset, reg):
        reg_def = reg.definition
        if reg_def:
            return reg._replace(
                name = reg.name, offset = offset + reg.offset,
                fields = reg_def.fields + reg.fields)
        else:
            return reg._replace(offset = reg.offset + offset)

    def walk_rw_pair(self, offset, rw_pair):
        registers = [
            self.walk_register(offset, reg)
            for reg in rw_pair.registers]
        return rw_pair._replace(registers = registers)

    def walk_overlay(self, offset, overlay):
        return overlay._replace(offset = overlay.offset + offset)

    def walk_union(self, offset, union):
        base, length = union.range
        content = self.walk_subgroups(offset, union)
        return union._replace(
            range = (base + offset, length), content = content)


# Eliminates definitions from a parse by replacing all group and register
# entries by their corresponding definitions
def flatten(parse):
    flatten = FlattenMethods()
    groups = [flatten.walk_group(0, group) for group in parse.groups]
    return parse._replace(groups = groups)
