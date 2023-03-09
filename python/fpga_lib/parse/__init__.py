# Pull in the local modules, we'll want them.

from . import indent
from . import register_defines

def parsed_defs(defs_path, warn = False, flatten = False):
    defs = register_defines.parse_defs(
        indent.parse_file(open(defs_path), warn))
    if flatten:
        defs = register_defines.flatten(defs)
    return defs
