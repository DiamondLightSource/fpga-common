# Simple argument parsing helper functions

from __future__ import division
from __future__ import print_function

import argparse
import numpy


def parse_count(argument):
    scaling = { 'K' : 1024, 'M' : 1024**2, }
    if argument[-1] in scaling:
        scale = scaling[argument[-1]]
        argument = argument[:-1]
    else:
        scale = 1

    count = int(argument) * scale
    if count <= 0:
        raise argparse.ArgumentTypeError('Invalid count')
    return count


def parse_int(s):
    try:
        return int(s)
    except:
        raise argparse.ArgumentTypeError('Invalid integer "%s"' % s)


def parse_range(argument):
    fields = []
    # Allow a list of numbers or a range
    for field in argument.split(','):
        sub_fields = field.split(':')
        if len(sub_fields) == 1:
            fields.append(parse_int(field))
        elif len(sub_fields) == 2:
            fields.extend(
                range(parse_int(sub_fields[0]), parse_int(sub_fields[1]) + 1))
        else:
            raise argparse.ArgumentTypeError('Invalid range "%s"' % field)
    return fields

