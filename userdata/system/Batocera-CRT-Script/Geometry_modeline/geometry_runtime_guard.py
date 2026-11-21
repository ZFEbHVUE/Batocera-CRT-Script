"""Geometry's lock/storage guard, with optional cumulative CRT journal integration.

The contributor branch needs no operation_journal/emulator_pair installation.
When that framework is present its real check still runs under the inherited
lock. Missing/broken helpers never authorize ignoring existing recovery records.
"""
from __future__ import annotations

import fcntl
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

BASE = 'userdata/Batocera-CRT-Script-Backup'
FOREIGN_STORES = ('operations', 'emulator-pair-transactions', 'preparations')
SHARED_FILES = ('operation_journal.py', 'emulator_pair.py')
SHARED_MARKERS = (*SHARED_FILES, 'operation_journal.sh')
TOKEN = 'GEOMETRY_SHARED_CHECK_COMPLETE'

# A fresh interpreter keeps optional journal imports and their dependencies out
# of Geometry's module cache. No shell, environment-selected plugin or CLI root
# override is involved; the held file description is passed explicitly.
SHARED_CHECK = '''from pathlib import Path
import sys
directory=Path(sys.argv[1])
sys.path.insert(0,str(directory))
import emulator_pair,operation_journal
for name,module in (("emulator_pair",emulator_pair),("operation_journal",operation_journal)):
 if Path(module.__file__).resolve()!=directory/(name+".py"):
  raise RuntimeError("Unexpected shared recovery module origin")
root=Path(sys.argv[2]);descriptor=int(sys.argv[3])
operation_journal.assert_operation_lock(root,descriptor)
operation_journal.OperationStore(root).check()
print("GEOMETRY_SHARED_CHECK_COMPLETE",flush=True)
'''


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def unescape(value):
    return re.sub(r'\\([0-7]{3})', lambda match: chr(int(match[1], 8)), value)


def mounts(text):
    result = []
    try:
        for line in text.splitlines():
            left, right = line.split(' - ', 1)
            fields, filesystem = left.split(), right.split()
            result.append((Path(unescape(fields[4])), fields[5].split(','),
                           filesystem[0], unescape(filesystem[1])))
    except (ValueError, IndexError) as error:
        raise RuntimeError('Cannot validate Geometry recovery mounts.') from error
    return result


def validate_mounts(root, base, inventory):
    if root == Path('/'):
        entries = [entry for entry in inventory if entry[0] == Path('/userdata')]
        require(len(entries) == 1, 'Geometry recovery needs a separate userdata mount.')
        _, options, filesystem, source = entries[0]
        require(filesystem in ('ext2', 'ext3', 'ext4', 'btrfs', 'xfs', 'f2fs')
                and source.startswith('/dev/') and 'rw' in options,
                'Geometry recovery needs writable block-backed POSIX userdata.')
    require(not any(point == base or base in point.parents for point, *_ in inventory),
            'Unmount storage inside the CRT backup folder before using Geometry.')


def no_links(path):
    require(not any(p.is_symlink() for p in (path, *path.parents)),
            'A Geometry runtime or recovery path was redirected.')


def storage_directory(path, device, required=False):
    no_links(path)
    if not path.exists():
        require(not required, 'Geometry recovery storage is missing.')
        return False
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) and info.st_uid == os.geteuid()
            and not info.st_mode & 0o022 and info.st_dev == device,
            'Geometry recovery storage must be an owned, writable POSIX directory.')
    return True


def check_runtime(root, descriptor, shared_modules=None):
    root = Path(root)
    require(type(descriptor) is int and descriptor >= 0, 'Geometry operation lock is missing.')
    require(root.is_absolute() and root == root.resolve(), 'Invalid Geometry runtime root.')
    if root != Path('/'):
        require(root.is_relative_to(Path(tempfile.gettempdir()).resolve())
                and (root / '.geometry-python-fixture').is_file(),
                'Disposable Geometry fixture required.')
    userdata, base = root / 'userdata', root / BASE
    no_links(userdata)
    require(userdata.is_dir(), 'Geometry userdata is missing.')
    storage_directory(base, userdata.stat().st_dev, required=True)
    lock = base / 'runtime-switch.lock'
    no_links(lock)
    info, opened = lock.lstat(), os.fstat(descriptor)
    require(stat.S_ISREG(opened.st_mode) and opened.st_uid == os.geteuid()
            and opened.st_nlink == 1 and not opened.st_mode & 0o022
            and (opened.st_dev, opened.st_ino) == (info.st_dev, info.st_ino),
            'Geometry does not own the expected operation lock.')
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    validate_mounts(root, base, mounts(Path('/proc/self/mountinfo').read_text()))

    directory = Path(shared_modules) if shared_modules is not None else Path(__file__).resolve().parent / 'mode_switcher_modules'
    no_links(directory)
    require(not directory.exists() or directory.is_dir(), 'Invalid shared CRT helper directory.')
    present = any((directory / name).exists() or (directory / name).is_symlink() for name in SHARED_MARKERS)
    if present:
        for name in SHARED_FILES:
            path = directory / name
            no_links(path)
            require(path.is_file() and path.stat().st_nlink == 1,
                    'Shared CRT recovery helpers are incomplete; restore the matching helpers.')
        try:
            result = subprocess.run([sys.executable, '-I', '-B', '-c', SHARED_CHECK,
                                     str(directory.resolve()), str(root), str(descriptor)],
                                    pass_fds=(descriptor,), stdin=subprocess.DEVNULL,
                                    capture_output=True, text=True, timeout=30)
        except (OSError, subprocess.SubprocessError) as error:
            raise RuntimeError('Shared CRT recovery check could not finish; keep its records and matching helpers.') from error
        require(result.returncode == 0 and result.stdout.splitlines()[-1:] == [TOKEN],
                'Shared CRT recovery check failed; resolve its recovery or restore matching helpers.\n'
                + result.stderr[-1500:].strip())
        return 'shared'

    for name in FOREIGN_STORES:
        path = base / name
        if storage_directory(path, userdata.stat().st_dev):
            require(not any(path.iterdir()),
                    'Other CRT recovery records remain without their shared helper. '
                    'Keep the records and restore the matching runtime before using Geometry.')
    # Geometry's own operation/ is intentionally allowed: run_locked() validates
    # and offers its recovery before any new calibration or original backup.
    return 'standalone'
