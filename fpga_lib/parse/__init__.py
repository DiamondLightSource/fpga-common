# Pull in the local modules, we'll want them.

from . import indent
from . import register_defines

class FailParse(Exception):
    pass

def parsed_defs(*defs_path, warn = False, flatten = False, defines = None):
    for filename in defs_path:
        parsed_indent = indent.parse_file(open(filename), warn)
        defines = register_defines.parse_defs(parsed_indent, defines)

    if flatten:
        defines = register_defines.flatten(defines)
    return defines
