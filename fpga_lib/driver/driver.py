# Low level register interface to D2EBPM registers

from __future__ import print_function

import sys
import os
import mmap
import fcntl
import select
import struct
import errno
import numpy

from .register_defines import load_register_defs


VERBOSE = False


# Corresponds to _IOC macro defined in ioctl.h and AMC_IOCTL defined in
# amc_pci_driver.h.
def AMC_IOCTL(n):
    return (1 << 30) | (ord('L') << 8) | n

# Size of register map
AMC_MAP_SIZE = AMC_IOCTL(0)
# Optimal DMA buffer request size
AMC_BUF_SIZE = AMC_IOCTL(1)
# Size of underlying DMA area
AMC_DMA_AREA_SIZE = AMC_IOCTL(4)



# We want to support two ways to specify the device name: by sequence number, or
# by PCI address (which encodes the backplane port).
def device_name(name, part, prefix = 0):
    if isinstance(prefix, int):
        # Assume the prefix is just a device number identification
        return '/dev/%s.%d.%s' % (name, prefix, part)
    else:
        # Assume the prefix is a string.  The options are now:
        #  1. single character device number as above
        #  2. two character PCIe part number
        #  3. full pci- address
        #  4. full device name
        if len(prefix) == 1:
            return '/dev/%s.%s.%s' % (name, prefix, part)
        elif len(prefix) == 2:
            # Prefix is the short form PCIe address
            return '/dev/%s/pci-0000:%s:00.0/%s.%s' % (
                name, prefix, name, part)
        elif prefix.startswith('pci-'):
            # Prefix is long form PCIe address
            return '/dev/%s/%s/%s.%s' % (name, prefix, name, part)
        else:
            # Assume prefix is complete device name
            return '/dev/%s.%s' % (prefix, part)


class RawRegisters:
    def __init__(self, name, prefix):
        self.name = name
        self.prefix = prefix

        # Open register file and map into memory.
        self.reg_file = os.open(self.device_name('reg'), os.O_RDWR | os.O_SYNC)
        reg_size = fcntl.ioctl(self.reg_file, AMC_MAP_SIZE)
        self.reg_map = mmap.mmap(self.reg_file, reg_size)
        self.regs = numpy.frombuffer(self.reg_map, dtype = numpy.uint32)

    def __del__(self):
        if hasattr(self, 'reg_file'):
            os.close(self.reg_file)

    def make_registers(self, name, range, *defines):
        if range is None:
            range = numpy.s_[:]
        # Special trick to fall back to old filename if present, helps with
        # loading registers during development
        defines = [
            name + '.old' if os.path.isfile(name + '.old') else name
            for name in defines]
        groups, constants = load_register_defs(*defines)
        register_map = RegisterMap(self.regs[range], name)
        setattr(self, name, groups[name](register_map))
        return constants


    def device_name(self, part):
        return device_name(self.name, part, self.prefix)

    def read_events(self, wait = True, verbose = False):
        # If requested wait for device to become ready, otherwise fall through
        # to reading.
        if not wait:
            r, w, x = select.select([self.reg_file], [], [], 0)
            if not r:
                return 0

        try:
            events = os.read(self.reg_file, 4)
        except OSError as e:
            # This will work for Python 2, but for Python 3 (after version 3.5)
            # the underlying os.read() call will be automatically retried in
            # this case.
            #   Either way, the goal is to silence the EINTR exception triggered
            # by Ctrl-C.
            if e.errno == errno.EINTR:
                if verbose:
                    print('Interrupted call', file = sys.stderr)
                return 0
            else:
                # Don't recognise this exception, let it through.
                raise
        else:
            return struct.unpack('I', events)[0]

    def reader(self, name, dtype = None):
        '''Returns file handle for reading from DMA area.'''
        return _Reader(self.device_name(name), dtype)

    def __getitem__(self, key):
        return self.regs[key]

    def __setitem__(self, key, value):
        self.regs[key] = value


class RegisterMap:
    def __init__(self, registers, name):
        self.registers = registers
        self.name = name

    def _read_value(self, offset):
        value = self.registers[offset]
        if VERBOSE:
            print('%s[%03X] => %08X' % (self.name, offset, value))
        return value

    def _write_value(self, offset, value):
        if VERBOSE:
            print('%s[%03X] <= %08X' % (self.name, offset, value))
        self.registers[offset] = value



# Wraps reading interface around a DMA device
class _Reader:
    def __init__(self, name, dtype):
        self.__dtype = dtype
        self.__file = open(name, 'rb')

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def size(self):
        '''Returns size of underlying area on FPGA'''
        return fcntl.ioctl(self.__file.fileno(), AMC_DMA_AREA_SIZE)

    def buf_size(self):
        '''Returns optimal read block size, determined by underlying DMA buffer
        in the kernel driver.'''
        return fcntl.ioctl(self.__file.fileno(), AMC_BUF_SIZE)

    def read(self, count):
        buffer = self.__file.read(count)
        if self.__dtype is None:
            return buffer
        else:
            return numpy.frombuffer(buffer, dtype = self.__dtype)

    def seek(self, where):
        self.__file.seek(where)

    def close(self):
        self.__file.close()


__all__ = ['RawRegisters']
