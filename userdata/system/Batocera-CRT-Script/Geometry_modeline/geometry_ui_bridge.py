"""Private inherited-FD transport for the visual Geometry frontend and backend."""
from __future__ import annotations

import json
import os
import socket

LIMIT = 512 * 1024


def encode(message: dict) -> bytes:
    data = json.dumps(message, ensure_ascii=True, separators=(',', ':')).encode() + b'\n'
    if len(data) > LIMIT:
        raise ValueError('Geometry UI message too large')
    return data


def request(message: dict) -> dict:
    number = os.environ.get('CRT_GEOMETRY_UI_FD', '')
    if not number.isdecimal() or int(number) < 3:
        raise ValueError('Geometry UI descriptor missing')
    # Both ends are created as an AF_UNIX stream socketpair. State the known
    # type explicitly; some Linux compatibility kernels cannot auto-detect it.
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0, fileno=os.dup(int(number))) as channel:
        channel.sendall(encode(message))
        data = bytearray()
        while b'\n' not in data:
            block = channel.recv(65536)
            if not block:
                raise ConnectionError('Geometry interface disconnected')
            data.extend(block)
            if len(data) > LIMIT:
                raise ValueError('Geometry UI response too large')
        first, rest = bytes(data).split(b'\n', 1)
        if rest:
            raise ValueError('Unexpected Geometry UI response')
        reply = json.loads(first)
        if not isinstance(reply, dict) or type(reply.get('code')) is not int or not 0 <= reply['code'] <= 255:
            raise ValueError('Invalid Geometry UI reply')
        if not isinstance(reply.get('output', ''), str):
            raise ValueError('Invalid Geometry UI output')
        return reply

