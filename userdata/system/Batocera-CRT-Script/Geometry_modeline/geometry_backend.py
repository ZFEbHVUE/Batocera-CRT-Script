"""Python Geometry application/recovery engine; no shell or dialog UI process."""
from __future__ import annotations

from contextlib import contextmanager
import fcntl
import hashlib
import math
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile

from geometry_ui_bridge import request
from geometry_runtime_guard import check_runtime

BOOT_PATHS = ('/boot/boot/syslinux.cfg', '/boot/boot/syslinux/syslinux.cfg',
              '/boot/EFI/syslinux.cfg', '/boot/EFI/BOOT/syslinux.cfg',
              '/boot/EFI/batocera/syslinux.cfg', '/boot/EFI/BOOT/grub.cfg')
ALL_PATHS = ('/etc/switchres.ini', '/userdata/system/99-nvidia.conf',
             '/lib/firmware/edid/custom.bin', *BOOT_PATHS)
BASE_INI = '/tmp/geometry-calibrate-base.ini'
GEOMETRY_TRIPLET = re.compile(r'^([0-9]+(?:\.[0-9]+)?):(-?[0-9]+):(-?[0-9]+)$')


class GeometryError(RuntimeError):
    pass


def require(value, message):
    if not value: raise GeometryError(message)


def digest(data): return hashlib.sha256(data).hexdigest()


def awk_lines(text):
    """Retain CR and other unchanged bytes as the previous awk paths did."""
    return (text[:-1] if text.endswith('\n') else text).split('\n') if text else []


class GeometryEngine:
    def __init__(self, root=Path('/'), exchange=request, runner=None, parent_guard=None, boot_readonly=None):
        self.root = Path(root).absolute()
        if self.root != Path('/'):
            require(self.root == self.root.resolve() and self.root.is_relative_to(Path(tempfile.gettempdir()).resolve())
                    and (self.root / '.geometry-python-fixture').is_file(), 'Disposable Geometry fixture required.')
        self.exchange, self.runner, self.parent_guard = exchange, runner or subprocess.run, parent_guard
        self.boot_readonly, self.boot_writable = boot_readonly, False
        self.base = self.path('/userdata/Batocera-CRT-Script-Backup')
        self.log = self.base / 'Geometry_Tool_Backup'
        self.operation = self.log / 'operation'
        self.fd = None

    def path(self, name): return self.root / name.lstrip('/')

    def safe(self, path):
        require(not path.is_symlink(), 'A Geometry path was redirected: ' + str(path))
        for parent in path.parents:
            if parent == self.root: break
            if parent.is_symlink():
                require(parent == self.path('/lib') and parent.resolve() == self.path('/usr/lib'),
                        'A Geometry parent directory was redirected.')
        require(path.parent.resolve().is_relative_to(self.root), 'Geometry path escaped its filesystem.')

    def read(self, path):
        self.safe(path)
        require(path.is_file() and path.stat().st_nlink == 1, 'Missing or unsafe Geometry file: ' + str(path))
        return path.read_bytes()

    @staticmethod
    def sync_dir(path):
        fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try: os.fsync(fd)
        finally: os.close(fd)

    def publish(self, path, data, mode=0o644):
        self.safe(path)
        require(not path.exists() or (path.is_file() and path.stat().st_nlink == 1), 'Unsafe Geometry destination.')
        path.parent.mkdir(parents=True, exist_ok=True)
        self.safe(path)
        fd, name = tempfile.mkstemp(prefix='.geometry-', dir=path.parent)
        staged = Path(name)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(data); stream.flush(); os.fchmod(stream.fileno(), mode); os.fsync(stream.fileno())
            require(staged.read_bytes() == data, 'Geometry staging verification failed.')
            os.replace(staged, path)
            self.sync_dir(path.parent)
            require(self.read(path) == data, 'Geometry publication verification failed.')
        finally:
            staged.unlink(missing_ok=True)

    def remove_file(self, path):
        self.safe(path)
        require(not path.exists() or path.is_file(), 'Unexpected Geometry removal target.')
        path.unlink(missing_ok=True)
        if path.parent.exists(): self.sync_dir(path.parent)

    def validate_operation_tree(self):
        self.safe(self.operation)
        require(self.operation.parent == self.log and self.operation.name == 'operation'
                and self.operation.is_dir() and not os.path.ismount(self.operation), 'Unsafe recovery folder.')
        for parent, dirs, files in os.walk(self.operation, followlinks=False):
            for name in dirs + files:
                path = Path(parent) / name
                self.safe(path)
                require(not os.path.ismount(path), 'Mounted Geometry recovery payload.')
                if path.is_file(): require(path.stat().st_nlink == 1, 'Shared Geometry recovery payload.')

    def validate_targets(self, targets):
        for name in targets:
            require(name in ALL_PATHS, 'Unknown Geometry target.')
            path = self.path(name)
            self.safe(path)
            if path.exists(): self.read(path)

    def clean_operation(self):
        self.validate_operation_tree()
        shutil.rmtree(self.operation)
        self.sync_dir(self.log)

    def command(self, args, **kwargs):
        result = self.runner([str(a) for a in args], capture_output=True, text=True, **kwargs)
        require(result.returncode == 0, 'Geometry command failed: ' + str(args[0]))
        return result.stdout

    def prompt(self, title, widget, message, *values):
        reply = self.exchange(dict(type='prompt', args=['--title', title, widget, message, '20', '80', *values]))
        require(type(reply.get('code')) is int and 0 <= reply['code'] <= 255, 'Invalid Geometry interface response.')
        return reply

    def progress(self, text):
        require(self.exchange(dict(type='progress', args=[text]))['code'] == 0, 'Geometry interface disconnected.')

    @contextmanager
    def locked(self):
        self.safe(self.base)
        self.base.mkdir(parents=True, exist_ok=True)
        lock = self.base / 'runtime-switch.lock'
        self.safe(lock)
        self.fd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
        try:
            info = os.fstat(self.fd)
            require(stat.S_ISREG(info.st_mode) and info.st_uid == os.geteuid() and info.st_nlink == 1,
                    'Unsafe Geometry operation lock.')
            try: fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError: raise GeometryError('Another installation or mode switch is active.')
            if self.parent_guard: self.parent_guard(self)
            else:
                mode = check_runtime(self.root, self.fd)
                print('Geometry runtime guard: ' + mode, file=sys.stderr, flush=True)
            self.safe(self.log)
            if not self.log.exists():
                old = self.path('/userdata/system/Batocera-CRT-Script/Geometry_modeline/backup')
                self.safe(old)
                if old.is_dir(): shutil.copytree(old, self.log, symlinks=True)
            self.log.mkdir(parents=True, exist_ok=True)
            self.safe(self.operation)
            if self.boot_readonly is None:
                entries = [l.split(' - ')[0].split() for l in self.path('/proc/self/mountinfo').read_text().splitlines()
                           if l.split(' - ')[0].split()[4] == str(self.path('/boot'))]
                require(len(entries) == 1, 'Cannot identify the boot mount.')
                self.boot_readonly = 'ro' in entries[0][5].split(',')
            yield
        finally:
            try:
                if self.boot_writable and self.boot_readonly:
                    self.command(['mount', '-o', 'remount,ro', str(self.path('/boot'))])
                    self.boot_writable = False
            finally:
                os.close(self.fd); self.fd = None

    def writable_boot(self):
        self.boot_writable = True
        self.command(['mount', '-o', 'remount,rw', str(self.path('/boot'))])

    def save_overlay(self):
        writer = 'batocera-save-overlay'
        if self.path('/boot/crt/linux').is_file() and self.path('/boot/crt/initrd-crt.gz').is_file():
            cmdline = self.path('/proc/cmdline').read_text()
            if re.search(r'(^|\s)BOOT_IMAGE=/crt/linux(\s|$)', cmdline):
                writer = str(self.path('/userdata/system/Batocera-CRT-Script/batocera-save-crt-overlay'))
            elif not re.search(r'(^|\s)BOOT_IMAGE=/boot/linux(\s|$)', cmdline):
                display = self.command(['batocera-resolution', 'getDisplayMode']).strip()
                require(display in ('xorg', 'wayland'), 'Unknown display environment; overlay not saved.')
                if display == 'xorg': writer = str(self.path('/userdata/system/Batocera-CRT-Script/batocera-save-crt-overlay'))
        self.command([writer])
        os.sync()

    def snapshot(self, targets):
        result = {}
        for name in [*targets, '/userdata/system/logs/BootRes.log']:
            path = self.path(name)
            self.safe(path)
            result[name] = digest(self.read(path)) if path.exists() else None
        return result

    def mirror(self, prefix, name, suffix=''):
        # Preserve the existing Bash backup/preimage layout byte for byte.
        return prefix / (str(self.path(name)).lstrip('/') + suffix)

    def originals(self, targets):
        checkpoint = self.log / 'backup.file'
        self.safe(checkpoint)
        complete = checkpoint.exists()
        if complete: require(self.read(checkpoint) == b'', 'Invalid original Geometry backup checkpoint.')
        planned = []
        for name in targets:
            source = self.path(name)
            saved, absent = self.mirror(self.log, name, '.backup'), self.mirror(self.log, name, '.absent')
            self.safe(saved); self.safe(absent)
            require(not (saved.exists() and absent.exists()), 'Conflicting original Geometry backups.')
            if complete and not saved.exists() and not absent.exists():
                if source.exists():
                    # Checkpoint exists but one target was never recorded (partial first run).
                    planned.append((saved, self.read(source)))
                else:
                    planned.append((absent, b''))
            elif absent.exists():
                require(self.read(absent) == b'', 'Invalid original absence marker.')
            elif saved.exists():
                self.read(saved)
            elif source.exists():
                planned.append((saved, self.read(source)))
            else:
                planned.append((absent, b''))
        for path, data in planned: self.publish(path, data)
        if not complete: self.publish(checkpoint, b'')
        os.sync()

    def begin(self, targets):
        require(not self.operation.exists(), 'Previous Geometry operation requires recovery.')
        self.operation.mkdir(mode=0o700)
        for name in targets:
            source = self.path(name)
            self.safe(source)
            if source.exists():
                data = self.read(source)
                self.publish(self.mirror(self.operation / 'before', name), data)
                self.publish(self.mirror(self.operation / 'before', name, '.sha256'), (digest(data) + '\n').encode())
            else: self.publish(self.mirror(self.operation / 'absent', name), b'')
        self.publish(self.operation / 'targets', ''.join(str(self.path(n)) + '\n' for n in targets).encode())
        os.sync()
        self.publish(self.operation / 'ready', b'')
        os.sync()

    def recover(self):
        if not self.operation.exists(): return True
        self.validate_operation_tree()
        ready = self.operation / 'ready'
        if not ready.exists():
            self.clean_operation()
            return True
        require(self.read(ready) == b'', 'Invalid Geometry recovery checkpoint.')
        reply = self.prompt('Geometry recovery', '--yesno', 'An unfinished Geometry change was found. Restore its saved files and save the current environment before continuing?')
        if reply['code'] != 0: return False
        raw = self.read(self.operation / 'targets').decode().splitlines()
        known = {str(self.path(n)): n for n in ALL_PATHS}
        require(raw and len(raw) == len(set(raw)) and set(raw) <= known.keys(), 'Invalid Geometry recovery targets.')
        restored = []
        for actual in raw:
            name = known[actual]
            saved = self.mirror(self.operation / 'before', name)
            absent = self.mirror(self.operation / 'absent', name)
            if saved.exists():
                data = self.read(saved)
                require(self.read(self.mirror(self.operation / 'before', name, '.sha256')).decode().strip() == digest(data),
                        'Geometry recovery preimage is corrupted.')
                require(not absent.exists(), 'Conflicting recovery preimages.')
                restored.append((name, data))
            else:
                require(self.read(absent) == b'', 'Missing recovery preimage.')
                restored.append((name, None))
        self.validate_targets([name for name, _ in restored])
        self.progress('Recovering the saved Geometry files...')
        self.writable_boot()
        for name, data in restored:
            self.remove_file(self.path(name)) if data is None else self.publish(self.path(name), data)
        self.save_overlay()
        self.clean_operation()
        return True

    def finish(self):
        self.progress('Saving the overlay. Please wait...')
        try: self.save_overlay()
        except Exception as error:
            raise GeometryError('Overlay saving failed. Recovery files were retained. Do not reboot; rerun Geometry to recover.') from error
        self.clean_operation()

    def completed(self, message):
        if self.boot_writable and self.boot_readonly:
            self.command(['mount', '-o', 'remount,ro', str(self.path('/boot'))])
            self.boot_writable = False
        reply = self.prompt('Reboot or Exit', '--yesno', message)
        if reply['code'] == 0:
            try: self.command(['reboot'])
            except GeometryError as error: raise GeometryError('The files were saved, but the reboot command failed. Reboot manually when ready.') from error
        else: require(reply['code'] in (1, 255), 'The files were saved, but the reboot choice failed.')

    @staticmethod
    def geometry_from_ini(text: str) -> str:
        """Read h_size / h_shift / v_shift like the native Calamity geometry tool."""
        h_size = h_shift = v_shift = None
        for line in awk_lines(text):
            if re.match(r'^\s*h_size\s+', line):
                parts = line.split()
                require(len(parts) >= 2, 'Invalid h_size in switchres.ini.')
                h_size = parts[-1]
            elif re.match(r'^\s*h_shift\s+', line):
                parts = line.split()
                require(len(parts) >= 2, 'Invalid h_shift in switchres.ini.')
                h_shift = parts[-1]
            elif re.match(r'^\s*v_shift\s+', line):
                parts = line.split()
                require(len(parts) >= 2, 'Invalid v_shift in switchres.ini.')
                v_shift = parts[-1]
        if h_size is None and h_shift is None and v_shift is None:
            return '1.0:0:0'
        try:
            hs = float(h_size if h_size is not None else '1.0')
            hi = int(h_shift if h_shift is not None else '0')
            vi = int(v_shift if v_shift is not None else '0')
        except ValueError as error:
            raise GeometryError('Invalid geometry values in switchres.ini.') from error
        triplet = f'{hs}:{hi}:{vi}'
        require(GEOMETRY_TRIPLET.fullmatch(triplet), 'Invalid geometry values in switchres.ini.')
        return triplet

    @staticmethod
    def ini_value(text: str, key: str) -> str | None:
        for line in awk_lines(text):
            match = re.match(rf'^\s*{key}\s+(\S+)', line)
            if match: return match[1]
        return None

    @staticmethod
    def saved_geometry(text: str) -> tuple[str, str, str]:
        """Return the triplet and the monitor / crt_range0 baseline it was calibrated on."""
        triplet = base = None
        for line in awk_lines(text):
            found = re.match(r'^# crt_script_geometry\s+(\S+)\s*$', line)
            if found: triplet = found[1]
            found = re.match(r'^# crt_script_geometry_base\s+(\S+)\s+(\S+)\s*$', line)
            if found: base = (found[1], found[2])
        if triplet is None or base is None:
            # Saves without markers (main, older branch builds): the live range is the baseline.
            triplet = GeometryEngine.geometry_from_ini(text)
            base = (GeometryEngine.ini_value(text, 'monitor') or 'custom',
                    GeometryEngine.ini_value(text, 'crt_range0') or 'auto')
        require(GEOMETRY_TRIPLET.fullmatch(triplet), 'Invalid saved geometry in switchres.ini.')
        require(re.fullmatch(r'[A-Za-z0-9_]+', base[0]) and re.fullmatch(r'auto|[0-9.,-]+', base[1]),
                'Invalid saved geometry baseline in switchres.ini.')
        return triplet, base[0], base[1]

    @staticmethod
    def custom_monitor_profile_message(text: str) -> str | None:
        """Explain saved ini geometry when monitor custom is active (Calamity-style profile)."""
        if not any(re.match(r'^\s*monitor\s+custom\b', line) for line in awk_lines(text)):
            return None
        triplet_hint = ''
        try:
            triplet = GeometryEngine.saved_geometry(text)[0]
            if triplet != '1.0:0:0':
                triplet_hint = (
                    f'\nSaved geometry: {triplet} (H size : H shift : V shift).\n'
                )
        except GeometryError:
            pass
        return (
            'Your system is using a custom monitor profile saved in switchres.ini.'
            f'{triplet_hint}\n'
            'The calibration grid starts from those saved values, not from factory defaults.\n\n'
            'To return to your original install baseline, use Restore original calibration on the main menu.'
        )

    @staticmethod
    def _ini_set_field(line: str, key: str, value) -> str:
        pattern = re.compile(rf'^(\s*{re.escape(key)}\s+)\S+(.*)$')
        match = pattern.match(line)
        if not match:
            return line
        return f'{match.group(1)}{value}{match.group(2)}'

    @staticmethod
    def rewrite_ini(original, monitor_name, range_text, markers=()):
        # h_* / v_* stay neutral: RetroArch's libswitchres ignores them while the
        # switchres CLI (EDID for ES) applies them on top of crt_range0, so any
        # geometry must live inside crt_range0 or ES and games drift apart.
        neutral = dict(h_size='1.0', h_shift='0', v_shift='0')
        result, monitor, crt = [], False, False
        for line in awk_lines(original.decode()):
            key = next((k for k in neutral if re.match(rf'^\s*{k}\s+', line)), None)
            if re.match(r'^# crt_script_geometry(_base)?\s', line): continue
            if re.match(r'^\s*monitor\s+', line):
                if not monitor: result.append(GeometryEngine._ini_set_field(line, 'monitor', monitor_name))
                monitor = True
            elif re.match(r'^\s*crt_range0\s+', line):
                if not crt: result.append(GeometryEngine._ini_set_field(line, 'crt_range0', range_text))
                crt = True
            elif key:
                result.append(GeometryEngine._ini_set_field(line, key, neutral[key]))
            else: result.append(line)
        if not monitor: result.append('monitor ' + monitor_name)
        if not crt: result.append('crt_range0 ' + range_text)
        result.extend(markers)
        return ('\n'.join(result) + '\n').encode()

    @staticmethod
    def stage_ini(original, range_text, geometry_text, base_monitor, base_range):
        """Calibrated range for Switchres plus the triplet/baseline the next run starts from."""
        return GeometryEngine.rewrite_ini(original, 'custom', range_text, (
            f'# crt_script_geometry {geometry_text}',
            f'# crt_script_geometry_base {base_monitor} {base_range}'))

    @staticmethod
    def modeline(text, width, height):
        lines = [re.sub(r'^\s*Switchres:\s*', '', l) for l in text.splitlines()]
        line = next((l for l in lines if re.match(r'^\s*Modeline\s+"', l)), '')
        tokens = shlex.split(line)
        require(len(tokens) >= 11, 'SwitchRes Error: no valid modeline.')
        try:
            values = list(map(int, tokens[3:11])); clock = float(tokens[2])
        except ValueError: raise GeometryError('Switchres generated an invalid modeline.')
        x, a, b, c, y, d, e, f = values
        require(math.isfinite(clock) and clock > 0 and x == width and y == height and 0 < x <= a <= b < c and 0 < y <= d <= e < f
                and all(t.lower() in ('interlace', 'doublescan', '+hsync', '-hsync', '+vsync', '-vsync') for t in tokens[11:]),
                'Switchres generated an invalid modeline.')
        return re.sub(r'(Modeline\s+"[^_"]*)_[^"]*"', r'\1"', line)

    @staticmethod
    def boot_reference(data):
        text = data.decode()
        dual = bool(re.search(r'^\s*LABEL\s+crt\s*$|menuentry.*CRT', text, re.M))
        active, lines = not dual, []
        for line in awk_lines(text):
            if re.match(r'^\s*LABEL\s+', line):
                require(len(line.split()) > 1, 'Invalid boot menu entry.')
                active = not dual or line.split()[1] == 'crt'
            if re.match(r'^\s*menuentry', line): active = not dual or 'CRT' in line
            lines.append(re.sub(r':edid/[^\s]*\.bin', ':edid/custom.bin', line) if active else line)
        return ('\n'.join(lines) + ('\n' if lines else '')).encode()

    def run(self):
        try:
            with self.locked(): return self.run_locked()
        except (OSError, ValueError, GeometryError, RuntimeError) as error:
            message = str(error)
            if (self.operation / 'ready').exists() and 'Recovery' not in message:
                message += ' Recovery files were retained.'
            print('Geometry backend stopped: ' + message, file=sys.stderr, flush=True)
            try: self.prompt('Geometry Error', '--msgbox', message)
            except Exception: pass
            return 1

    def run_locked(self):
        if not self.recover(): return 1
        if os.environ.get('GEOMETRY_LAUNCH_NEEDS_ES_RELAUNCH') == '1':
            self.prompt(
                'Relaunch Required',
                '--msgbox',
                'EmulationStation must release the CRT display before the calibration grid can appear.\n\n'
                'HideWindow is now enabled for CRT tools. Exit to EmulationStation, then launch '
                'Geometry again from the CRT menu.',
            )
            return 0
        nvidia = self.path('/userdata/system/99-nvidia.conf').is_file()
        targets = ['/etc/switchres.ini', '/userdata/system/99-nvidia.conf'] if nvidia else ['/etc/switchres.ini', '/lib/firmware/edid/custom.bin', *BOOT_PATHS]
        initial = self.snapshot(targets)
        ini_text = self.read(self.path('/etc/switchres.ini')).decode()
        if self.prompt(
            'Important Notice',
            '--msgbox',
            'This Geometry Adjustment tool is meant to be used only after you have made '
            'adjustments through the Grid Tool first. This should be a last resort for '
            'fine-tune adjustments.',
        )['code'] != 0: return 0
        profile_notice = self.custom_monitor_profile_message(ini_text)
        if profile_notice is not None and self.prompt(
            'Custom Monitor Profile',
            '--msgbox',
            profile_notice,
        )['code'] != 0:
            return 0
        menu = self.prompt('Resolution Selection', '--menu', 'Choose your resolution', '10', '640x480@60', 'Calibration', 'Restore Files', 'Restore original calibration', 'Quit', 'Exit')
        if menu['code'] != 0 or menu.get('output') == 'Quit': return 0
        selection = menu.get('output')
        if selection == 'Restore Files':
            restored = []
            for name in targets:
                saved, absent = self.mirror(self.log, name, '.backup'), self.mirror(self.log, name, '.absent')
                require(saved.exists() != absent.exists(), 'Original Geometry backup is incomplete or conflicting. Nothing was restored.')
                restored.append((name, self.read(saved) if saved.exists() else None))
                if absent.exists(): require(self.read(absent) == b'', 'Invalid original absence marker.')
            self.progress('Preparing recovery files...')
            self.begin(targets)
            self.writable_boot()
            for name, data in restored:
                self.remove_file(self.path(name)) if data is None else self.publish(self.path(name), data)
            self.finish()
            self.completed('Original Geometry files were restored and saved.')
            return 0
        require(selection == '640x480@60', 'Unknown Geometry selection.')
        bootres = self.read(self.path('/userdata/system/logs/BootRes.log')).decode()
        match = re.search(r'^Boot Resolution: ([0-9]+)x([0-9]+)@([0-9]+(?:[.][0-9]+)?)$', bootres, re.M)
        require(match, 'Boot Resolution is missing or invalid.')
        width, height, hz = int(match[1]) + 1, int(match[2]), match[3]
        require(width > 1 and height > 0, 'Invalid boot dimensions.')
        native_script = self.path('/userdata/system/Batocera-CRT-Script/UsrBin_configs/geometry-calibrate.py')
        if not native_script.is_file():
            native_script = self.path('/usr/bin/geometry')
        geometry_arg, base_monitor, base_range = self.saved_geometry(ini_text)
        # Calibrate against the original baseline so the saved triplet reproduces
        # the current picture instead of being applied on top of it again.
        base_ini = self.path(BASE_INI)
        self.publish(base_ini, self.rewrite_ini(ini_text.encode(), base_monitor, base_range))
        try:
            native = self.exchange(dict(type='native', args=[
                sys.executable, str(native_script), '640', '480', '60', '-g', geometry_arg,
                '-s', 'switchres -i ' + BASE_INI,
            ]))
        finally:
            self.remove_file(base_ini)
        output, code = native.get('output', ''), native['code']
        if code in (0, 1) and output.rstrip('\n').splitlines()[-1:] == ['Aborted!']: return 0
        require(code == 0, 'Geometry calibration failed.')
        found = re.search(r'^\s*Final\s*crt_range:\s*(.+)$', output, re.M)
        require(found, 'Geometry returned no crt_range.')
        range_text = found[1]
        require(re.fullmatch(r'[0-9., \t-]+', range_text), 'Geometry returned an invalid crt_range.')
        found_geom = re.search(r'^\s*Final\s*geometry:\s*(\S+)', output, re.M)
        require(found_geom and GEOMETRY_TRIPLET.fullmatch(found_geom[1]), 'Geometry returned no valid geometry triplet.')
        geometry_text = found_geom[1]
        self.progress('Preparing the calibrated display settings...')
        self.path('/tmp').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='geometry-work.', dir=self.path('/tmp')) as directory:
            work = Path(directory)
            staged = work / 'switchres.ini'
            ini = self.stage_ini(self.read(self.path('/etc/switchres.ini')), range_text,
                                 geometry_text, base_monitor, base_range)
            staged.write_bytes(ini)
            generated = dict()
            if nvidia:
                result = self.command(['switchres', width, height, hz, '-f', f'{width}x{height}@{hz}', '-i', staged, '-c'])
                modeline = self.modeline(result, width, height)
                old = awk_lines(self.read(self.path('/userdata/system/99-nvidia.conf')).decode())
                lines, done = [], False
                for line in old:
                    if re.match(r'^\s*Modeline\s+"', line):
                        if not done: lines.append(modeline)
                        done = True
                    else: lines.append(line)
                if not done: lines.append(modeline)
                generated['/userdata/system/99-nvidia.conf'] = ('\n'.join(lines) + '\n').encode()
                title, message = '99-nvidia.conf Found', 'Apply the calibrated range and generated NVIDIA modeline?'
            else:
                self.command(['switchres', width, height, hz, '-f', f'{width}x{height}@{hz}', '-i', staged, '-e'], cwd=work)
                edids = list(work.glob('*.bin'))
                require(len(edids) == 1, 'Switchres must generate exactly one EDID.')
                data = self.read(edids[0])
                require(len(data) >= 128 and len(data) % 128 == 0 and data[:8] == bytes.fromhex('00ffffffffffff00')
                        and len(data) == 128 * (data[126] + 1)
                        and all(sum(data[i:i + 128]) % 256 == 0 for i in range(0, len(data), 128)), 'Switchres generated an invalid EDID.')
                generated['/lib/firmware/edid/custom.bin'] = data
                generated.update({name: self.boot_reference(self.read(self.path(name))) for name in BOOT_PATHS if self.path(name).is_file()})
                title, message = 'EDID File Found', 'Apply the calibrated range and generated custom.bin EDID?'
            if self.prompt(title, '--yesno', message)['code'] != 0: return 0
            require(self.snapshot(targets) == initial, 'Configuration changed during calibration. Review it again before applying.')
            self.originals(targets)
            self.progress('Saving calibration and recovery files...')
            self.begin(targets)
            if not nvidia: self.writable_boot()
            self.publish(self.path('/etc/switchres.ini'), ini)
            for name, data in generated.items(): self.publish(self.path(name), data)
            self.finish()
        self.completed('Calibration was installed and saved.')
        return 0


if __name__ == '__main__':
    raise SystemExit(GeometryEngine().run())
