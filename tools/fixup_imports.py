# Ensure that fpga_lib can be imported

import sys
import os.path

try:
    import fpga_lib
except ImportError:
    python_dir = os.path.abspath(os.path.join(__file__, '../..', 'python'))
    sys.path.append(python_dir)
