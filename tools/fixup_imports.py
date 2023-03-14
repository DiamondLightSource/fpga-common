# Ensure that fpga_lib can be imported

import sys
import os.path

try:
    import fpga_lib
except ImportError:
    here = os.path.dirname(__file__)
    python_dir = os.path.abspath(os.path.join(here, '..'))
    sys.path.append(python_dir)
