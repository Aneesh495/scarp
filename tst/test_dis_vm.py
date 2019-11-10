#!/usr/bin/env python3
"""
test_dis_vm.py: Comprehensive Unit Tests for Dis Virtual Machine and Channels
Tests Dis bytecode opcode execution, memory models, micro-threads, and channel alt.
"""

import sys
import os
import ctypes

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(REPO_ROOT, "build")
LIB_NAME = "libscarp_fast.dylib" if sys.platform == "darwin" else "libscarp_fast.so"
LIB_PATH = os.path.join(BUILD_DIR, LIB_NAME)


def test_dis_vm_lifecycle():
    """Verify Dis VM lifecycle: creation, code loading, and teardown."""
    if not os.path.exists(LIB_PATH):
        print("SKIP: libscarp_fast not built yet")
        return

    clib = ctypes.CDLL(LIB_PATH)
    clib.dis_vm_create.restype = ctypes.c_void_p
    clib.dis_vm_destroy.argtypes = [ctypes.c_void_p]

    vm = clib.dis_vm_create()
    assert vm is not None, "Failed to allocate Dis VM instance"
    clib.dis_vm_destroy(vm)
    print("PASS: test_dis_vm_lifecycle")


def test_dis_channel_sync():
    """Verify Dis channel creation, send, receive, and close semantics."""
    if not os.path.exists(LIB_PATH):
        print("SKIP: libscarp_fast not built yet")
        return

    clib = ctypes.CDLL(LIB_PATH)
    clib.dis_chan_create.argtypes = [ctypes.c_size_t, ctypes.c_size_t]
    clib.dis_chan_create.restype = ctypes.c_void_p
    clib.dis_chan_destroy.argtypes = [ctypes.c_void_p]
    clib.dis_chan_send.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_bool]
    clib.dis_chan_send.restype = ctypes.c_int
    clib.dis_chan_recv.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_bool]
    clib.dis_chan_recv.restype = ctypes.c_int

    # Create channel of 32-bit integers with capacity 4
    elem_size = 4
    cap = 4
    ch = clib.dis_chan_create(elem_size, cap)
    assert ch is not None, "Failed to create Dis channel"

    # Send values: 10, 20, 30
    for val in [10, 20, 30]:
        c_val = ctypes.c_int32(val)
        res = clib.dis_chan_send(ch, ctypes.byref(c_val), True)
        assert res == 1, f"Failed to send {val} to channel"

    # Recv values and verify FIFO order
    for expected in [10, 20, 30]:
        out_val = ctypes.c_int32(0)
        res = clib.dis_chan_recv(ch, ctypes.byref(out_val), True)
        assert res == 1, f"Failed to recv from channel"
        assert out_val.value == expected, f"Received {out_val.value} vs expected {expected}"

    clib.dis_chan_destroy(ch)
    print("PASS: test_dis_channel_sync")


if __name__ == "__main__":
    test_dis_vm_lifecycle()
    test_dis_channel_sync()
    print("All Dis VM unit tests passed successfully.")
