"""Standalone procedural Mode 8 world; official SDK is read-only."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
from functools import lru_cache

ROOT = Path(__file__).resolve().parent
MASK = 0xFFFFFFFF
ROOM_SHIFT = 3
ROOM_SIZE = 1 << ROOM_SHIFT
WINDOW = 40
MAP_BASE = 0x5C00
CENTRE = WINDOW // 2
START_ORIGIN = (3 - CENTRE) & MASK



def permutation(state):
    values = list(range(256))
    for i in range(255, 0, -1):
        state ^= (state << 13) & MASK
        state ^= state >> 17
        state ^= (state << 5) & MASK
        j = state % (i + 1)
        values[i], values[j] = values[j], values[i]
    return bytes(values)


PERM_A = permutation(0x73A92F15)
PERM_B = permutation(0xC592B837)


def room_hash(rx, ry, domain, seed):
    raw_seed = (seed & MASK).to_bytes(4, "little")
    a, b = raw_seed[0] ^ domain, raw_seed[1] ^ 0xA7
    for value in ((rx & MASK).to_bytes(4, "little")
                  + (ry & MASK).to_bytes(4, "little") + raw_seed[2:]):
        a = PERM_A[a ^ value]
        b = PERM_B[(a + b + value) & 255]
    return a, b


CORNER_MASKS = (0,0,0,0,1,2,4,8,3,12,5,10,6,9,15,0)


@lru_cache(maxsize=4096)
def axis_split(block, axis, seed):
    # Independent per axis: both rooms sharing an edge agree on its span.
    a, _ = room_hash(block & 0x0fffffff, 0, 4+axis, seed)
    return (6,8,10,8)[a & 3]


def axis_room(coord, axis, seed):
    coord &= MASK
    block, phase = coord >> 4, coord & 15
    split = axis_split(block, axis, seed)
    half = int(phase >= split)
    return block*2+half, phase-(split if half else 0), (16-split if half else split)


def room_size(index, axis, seed):
    split=axis_split(index >> 1, axis, seed)
    return 16-split if index & 1 else split


def doorway(rx, ry, domain, seed):
    a,b=room_hash(rx,ry,domain,seed)
    span=room_size(ry,1,seed) if domain==0 else room_size(rx,0,seed)
    return span//2-1+(a&1), 9 if b&3 else 0


def cell(x, y, seed):
    x, y = x & MASK, y & MASK
    rx,px,sx=axis_room(x,0,seed)
    ry,py,sy=axis_room(y,1,seed)
    if px == 0 and py == 0:
        return 1
    if px == 0 or py == 0:
        domain, position = (0,py) if px==0 else (1,px)
        gate, material = doorway(rx, ry, domain, seed)
        width = 1 if material == 9 else 2
        if gate <= position < gate+width:
            return material
        return 1
    cx,cy=sx//2,sy//2
    if cx-1 <= px <= cx+1 or cy-1 <= py <= cy+1:
        return 0
    quadrant=(1 if px>cx else 0)+(2 if py>cy else 0)
    mask=CORNER_MASKS[room_hash(rx,ry,2,seed)[0]&15]
    return int(bool(mask & (1<<quadrant)))


def world(ox, oy, seed):
    return bytes(1 if x in (0, WINDOW-1) or y in (0, WINDOW-1)
                 else cell(ox + x, oy + y, seed)
                 for y in range(WINDOW) for x in range(WINDOW))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

