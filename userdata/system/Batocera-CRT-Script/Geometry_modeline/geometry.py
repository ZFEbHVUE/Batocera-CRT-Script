#!/usr/bin/env python3
"""Pygame Geometry interface, Python application engine and native Python grid.

Preview/render modes never start the backend or read Batocera configuration.
Only geometry_backend.py publishes configuration, saves overlays or requests a reboot.
Visual style follows es_tool.py, which credits Sirmagb's EScentred UI concept.
"""
from __future__ import annotations

import argparse
import ctypes as C
from dataclasses import dataclass, field
import json
import os
from pathlib import Path
import re
import select
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time

from geometry_ui_bridge import LIMIT, encode

HERE = Path(__file__).resolve().parent
ES_SETTINGS = Path('/userdata/system/configs/emulationstation/es_settings.cfg')
UNAVAILABLE = 78  # Display/import startup failed before any operation started.
PREVIEWS = ('menu', 'gamepad', 'keyboard', 'review', 'saving', 'complete', 'restore', 'recovery', 'error')


def es_hide_window_enabled() -> bool:
    try:
        text = ES_SETTINGS.read_text(encoding='utf-8')
    except OSError:
        return False
    match = re.search(r'<bool name="HideWindow" value="(true|false)"\s*/>', text)
    return bool(match and match.group(1) == 'true')


def ensure_es_hide_window(log) -> bool:
    """Enable HideWindow so ES releases the DRM plane on the next tool launch.

    Returns True when HideWindow was already true. Returns False when it was
    just written and the user must exit and relaunch from EmulationStation.
    """
    try:
        text = ES_SETTINGS.read_text(encoding='utf-8') if ES_SETTINGS.is_file() else ''
        if es_hide_window_enabled():
            return True
        if re.search(r'<bool name="HideWindow"', text):
            updated = re.sub(r'<bool name="HideWindow" value="[^"]*"\s*/>',
                             '<bool name="HideWindow" value="true" />', text, count=1)
        elif '</config>' in text:
            updated = text.replace('</config>',
                                    '\t<bool name="HideWindow" value="true" />\n</config>', 1)
        else:
            updated = ('<?xml version="1.0"?>\n<config>\n'
                       '\t<bool name="HideWindow" value="true" />\n</config>\n')
        ES_SETTINGS.parent.mkdir(parents=True, exist_ok=True)
        ES_SETTINGS.write_text(updated, encoding='utf-8')
        log.write('HideWindow=true written to es_settings.cfg for the next EmulationStation launch\n')
        return False
    except OSError as error:
        log.write('Could not set HideWindow in es_settings.cfg: ' + str(error) + '\n')
        return es_hide_window_enabled()


@dataclass
class Choice:
    label: str
    code: int
    output: str = ''


@dataclass
class Screen:
    title: str
    message: str
    choices: list[Choice] = field(default_factory=list)
    selected: int = 0
    busy: bool = False
    help_page: str = ''


def argument(args: list[str], key: str, default: str = '') -> str:
    return args[args.index(key) + 1] if key in args and args.index(key) + 1 < len(args) else default


def prompt_screen(args: list[str]) -> Screen:
    """Translate the Python backend's fixed prompt descriptions."""
    if not isinstance(args, list) or not all(isinstance(a, str) for a in args):
        raise ValueError('Invalid dialog request')
    title = argument(args, '--title', 'Geometry')
    widgets = [key for key in ('--menu', '--yesno', '--msgbox') if key in args]
    if len(widgets) != 1:
        raise ValueError('Unsupported Geometry dialog')
    widget = widgets[0]
    message = argument(args, widget).replace('\\n', '\n')
    if widget == '--menu':
        index = args.index(widget)
        pairs = args[index + 5:]
        if len(pairs) % 2 or not pairs:
            raise ValueError('Invalid Geometry menu')
        labels = {'640x480@60': 'Start calibration', 'Restore Files': 'Restore original calibration', 'Quit': 'Return to EmulationStation'}
        choices = []
        for tag, _ in zip(pairs[::2], pairs[1::2]):
            if tag not in labels:
                raise ValueError('Unknown Geometry menu action')
            choices.append(Choice(labels[tag], 0, tag))
            if tag == '640x480@60':
                # Help belongs to this interface, never to the application engine.
                choices.append(Choice('Help - Button Mapping', 0, ':help'))
        return Screen('CRT GEOMETRY', 'Launch the native Switchres calibration grid at 640 x 480 / 60 Hz.\nYour changes are reviewed before saving.', choices)
    if widget == '--msgbox':
        if title == 'Geometry Error':
            screen_title = 'GEOMETRY ERROR'
            choices = [Choice('Return to EmulationStation', 0)]
        elif title == 'Relaunch Required':
            screen_title = 'RELAUNCH REQUIRED'
            choices = [Choice('Return to EmulationStation', 0)]
        elif title == 'Custom Monitor Profile':
            screen_title = 'CUSTOM MONITOR PROFILE'
            choices = [Choice('Continue', 0)]
        else:
            screen_title = 'BEFORE YOU START'
            choices = [Choice('Continue', 0)]
        return Screen(screen_title, message, choices)
    if title == 'Reboot or Exit':
        return Screen('CALIBRATION SAVED', message.split('\n\n', 1)[0] + '\nReboot to apply it now, or return and reboot later.',
                      [Choice('Return to EmulationStation', 1), Choice('Reboot now', 0)])
    if title == 'Geometry recovery':
        return Screen('RECOVER INTERRUPTED CHANGE', message,
                      [Choice('Return without recovering', 1), Choice('Recover saved files', 0)])
    if title not in ('99-nvidia.conf Found', 'EDID File Found'):
        raise ValueError('Unknown Geometry approval')
    return Screen('APPLY CALIBRATION?', message + '\nOriginal backups and recovery files will be preserved.',
                  [Choice('Discard changes', 1), Choice('Apply and save', 0)])


def preview_screen(name: str) -> Screen:
    if name in ('gamepad', 'keyboard'):
        return help_screen(name)
    examples = {
        'menu': Screen('CRT GEOMETRY', 'Launch the native Switchres calibration grid at 640 x 480 / 60 Hz.\nYour changes are reviewed before saving.',
                       [Choice('Start calibration', 0, '640x480@60'), Choice('Help - Button Mapping', 0, ':help'), Choice('Restore original calibration', 0, 'Restore Files'), Choice('Return to EmulationStation', 0, 'Quit')]),
        'review': Screen('APPLY CALIBRATION?', 'Apply your calibrated range and generated display settings?\nOriginal backups and recovery files will be preserved.',
                         [Choice('Discard changes', 1), Choice('Apply and save', 0)]),
        'saving': Screen('SAVING CALIBRATION', 'Saving the overlay. Please wait...', busy=True),
        'complete': Screen('CALIBRATION SAVED', 'Your calibration was installed and saved.\nReboot to apply it now, or return and reboot later.',
                           [Choice('Return to EmulationStation', 1), Choice('Reboot now', 0)]),
        'restore': Screen('RESTORE ORIGINAL CALIBRATION?', 'Replace the current calibration with your original Geometry backups?\nYour latest adjustment will be replaced.',
                          [Choice('Keep current calibration', 1), Choice('Restore original calibration', 0, 'Restore Files')]),
        'recovery': Screen('RECOVER INTERRUPTED CHANGE', 'An unfinished Geometry change was found. Recover its saved files before continuing.',
                           [Choice('Return without recovering', 1), Choice('Recover saved files', 0)]),
        'error': Screen('GEOMETRY ERROR', 'Overlay saving failed. Recovery files were retained.\nRun Geometry again to recover before rebooting.', [Choice('Return to EmulationStation', 0)]),
    }
    return examples[name]


# The native grid accepts aliases (Q/Escape, Backspace/Delete). One mapping for
# each action suffices. Batocera uses logical ES names: a=east, y=west on Xbox.
GAMEPAD_CONTROLS = (
    ('D-PAD', 'Picture position'),
    ('B (right)', 'Width +'),
    ('X (left)', 'Width -'),
    ('LB / RB', 'Hold for step x10'),
    ('L3 click', 'Reset preview'),
    ('R3 click', 'Reload grid'),
    ('A (bottom)', 'Accept / select'),
    ('BACK+START', 'Cancel / back'),
)
KEYBOARD_CONTROLS = (
    ('ARROW KEYS', 'Move the picture horizontally or vertically'),
    ('PAGE UP / DOWN', 'Increase / decrease picture width'),
    ('CTRL + adjustment', 'Use a step ten times larger'),
    ('DELETE / BACKSPACE', 'Reset the current preview adjustments'),
    ('R', 'Reload the grid with the current adjustments'),
    ('ENTER / RETURN', 'Accept the preview and open save review'),
    ('ESC / Q', 'Cancel calibration without saving'),
)


def help_screen(page: str) -> Screen:
    if page not in ('gamepad', 'keyboard'):
        raise ValueError('Unknown Geometry help page')
    choices = ([Choice('Back to Geometry', 0, ':help_close'), Choice('Keyboard controls', 0, ':help_keyboard')]
               if page == 'gamepad' else
               [Choice('Back to gamepad controls', 0, ':help_gamepad'), Choice('Back to Geometry', 0, ':help_close')])
    return Screen('HELP - BUTTON MAPPING', '', choices, help_page=page)


def draw_xbox360(p, surface, rect) -> None:
    """Original vector illustration: no downloaded images or extra runtime assets."""
    drawing = p.Surface((640, 410), p.SRCALPHA)
    body, edge, black = (211, 218, 207), (120, 140, 124), (27, 36, 30)
    p.draw.rect(drawing, edge, (114, 58, 106, 32), border_radius=12)
    p.draw.rect(drawing, edge, (420, 58, 106, 32), border_radius=12)
    p.draw.polygon(drawing, body, [(115, 86), (207, 65), (431, 65), (525, 86), (567, 156),
        (606, 337), (579, 377), (535, 371), (457, 277), (183, 277), (105, 371),
        (61, 377), (34, 337), (73, 156)])
    p.draw.ellipse(drawing, body, (80, 81, 480, 230))
    p.draw.ellipse(drawing, edge, (113, 110, 110, 106))
    p.draw.circle(drawing, black, (168, 162), 43)
    p.draw.circle(drawing, edge, (168, 162), 30, 3)
    p.draw.circle(drawing, edge, (385, 257), 51)
    p.draw.circle(drawing, black, (385, 257), 42)
    p.draw.circle(drawing, edge, (385, 257), 30, 3)
    p.draw.circle(drawing, (157, 170, 155), (245, 258), 53)
    p.draw.rect(drawing, black, (228, 217, 34, 82), border_radius=5)
    p.draw.rect(drawing, black, (204, 241, 82, 34), border_radius=5)
    p.draw.circle(drawing, black, (320, 147), 28)
    p.draw.line(drawing, (0, 220, 80), (302, 129), (338, 165), 8)
    p.draw.line(drawing, (0, 220, 80), (302, 165), (338, 129), 8)
    font = p.font.SysFont('monospace', 24, bold=True)
    small = p.font.SysFont('monospace', 19, bold=True)
    for letter, position, color in [('Y', (478, 116), (230, 190, 0)),
                                   ('B', (520, 158), (205, 43, 43)),
                                   ('A', (478, 200), (21, 155, 62)),
                                   ('X', (436, 158), (30, 105, 220))]:
        p.draw.circle(drawing, black, position, 28)
        p.draw.circle(drawing, color, position, 23)
        label = font.render(letter, True, (255, 255, 255))
        drawing.blit(label, label.get_rect(center=position))
    for label, position in [('BACK', (267, 176)), ('START', (365, 176)),
                            ('LB', (166, 72)), ('RB', (473, 72)),
                            ('L3', (168, 162)), ('R3', (385, 257))]:
        if label in ('BACK', 'START'):
            p.draw.ellipse(drawing, black, (position[0]-34, position[1]-14, 68, 28))
        text = small.render(label, True, (255, 255, 255))
        drawing.blit(text, text.get_rect(center=position))
    surface.blit(p.transform.smoothscale(drawing, rect.size), rect)


class Backend:
    """One backend process, one private inherited socket, no shell command text."""
    def __init__(self, script: Path, log, env: dict | None = None):
        self.socket, child = socket.socketpair()
        self.buffer = bytearray()
        self.closed = False
        try:
            env = dict(os.environ if env is None else env, CRT_GEOMETRY_UI_FD=str(child.fileno()))
            self.process = subprocess.Popen([sys.executable, '-B', str(script)], env=env,
                                            pass_fds=(child.fileno(),), stdin=subprocess.DEVNULL,
                                            stdout=log, stderr=log)
        except BaseException:
            self.socket.close()
            raise
        finally:
            child.close()

    def receive(self) -> dict | None:
        if self.closed:
            return None
        if b'\n' not in self.buffer and select.select([self.socket], [], [], 0)[0]:
            chunk = self.socket.recv(65536)
            if not chunk:
                self.closed = True
                return None
            self.buffer.extend(chunk)
        if len(self.buffer) > LIMIT:
            raise ValueError('Geometry backend request too large')
        if b'\n' not in self.buffer:
            return None
        line, _, rest = self.buffer.partition(b'\n')
        self.buffer = bytearray(rest)
        message = json.loads(line)
        if (not isinstance(message, dict) or message.get('type') not in ('prompt', 'native', 'progress')
                or not isinstance(message.get('args'), list)
                or not all(isinstance(a, str) for a in message['args'])):
            raise ValueError('Invalid Geometry backend request')
        return message

    def reply(self, code: int, output: str = '') -> None:
        self.socket.sendall(encode(dict(code=code, output=output)))

    def close(self) -> None:
        self.socket.close()
        # Never kill an approved configuration/overlay write on window close.
        # The closed channel cancels any subsequent review/reboot question.
        try:
            self.process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            pass


_GEOMETRY_TRIPLET = re.compile(r'^([0-9]+(?:\.[0-9]+)?):(-?[0-9]+):(-?[0-9]+)$')


def native_command(args: list[str]) -> list[str]:
    script = Path(args[1]) if len(args) > 1 else None
    allowed = script and script.name in ('geometry', 'geometry-calibrate.py')
    base = (args[0] == sys.executable and len(args) >= 5 and args[2:5] == ['640', '480', '60']
            and script and script.is_absolute() and allowed)
    if not base:
        raise ValueError('Unexpected native Geometry command')
    if len(args) == 5:
        return args
    if len(args) == 7 and args[5] == '-g' and _GEOMETRY_TRIPLET.fullmatch(args[6]):
        return args
    raise ValueError('Unexpected native Geometry command')


def x11_display_env() -> dict[str, str]:
    env = os.environ.copy()
    env.setdefault('DISPLAY', ':0')
    if os.path.isfile('/var/lib/.Xauthority'):
        env['XAUTHORITY'] = '/var/lib/.Xauthority'
    return env


def unmap_window_id(window_id: int) -> None:
    if window_id <= 0:
        return
    x11 = C.CDLL('libX11.so.6')
    x11.XOpenDisplay.argtypes = [C.c_char_p]
    x11.XOpenDisplay.restype = C.c_void_p
    x11.XUnmapWindow.argtypes = [C.c_void_p, C.c_ulong]
    x11.XUnmapWindow.restype = C.c_int
    x11.XSync.argtypes = [C.c_void_p, C.c_int]
    x11.XSync.restype = C.c_int
    x11.XCloseDisplay.argtypes = [C.c_void_p]
    x11.XCloseDisplay.restype = C.c_int
    connection = x11.XOpenDisplay(None)
    if not connection:
        raise RuntimeError('X11 connection unavailable')
    try:
        x11.XUnmapWindow(connection, window_id)
        x11.XSync(connection, 0)
    finally:
        x11.XCloseDisplay(connection)


def withdraw_sdl_menu(pygame, log) -> None:
    try:
        window_id = int(pygame.display.get_wm_info().get('window') or 0)
        if window_id:
            unmap_window_id(window_id)
            log.write('Menu SDL window unmapped (wid ' + str(window_id) + ')\n')
    except (OSError, AttributeError, RuntimeError, TypeError, ValueError) as error:
        log.write('Menu SDL window unmap skipped: ' + str(error) + '\n')


def hide_emulationstation(log) -> None:
    env = x11_display_env()
    try:
        found = subprocess.run(['xdotool', 'search', '--class', 'emulationstation'],
                                 capture_output=True, text=True, env=env, timeout=2, check=False)
        for window_id in (found.stdout or '').split():
            if not window_id.isdigit():
                continue
            subprocess.run(['xdotool', 'windowunmap', window_id], env=env, timeout=1, check=False)
            log.write('EmulationStation window unmapped (wid ' + window_id + ')\n')
    except (OSError, subprocess.SubprocessError) as error:
        log.write('EmulationStation unmap skipped: ' + str(error) + '\n')


def show_emulationstation(log) -> None:
    """Remap ES after native grid/calibration; hide_emulationstation leaves it unmapped."""
    env = x11_display_env()
    try:
        found = subprocess.run(['xdotool', 'search', '--class', 'emulationstation'],
                                 capture_output=True, text=True, env=env, timeout=2, check=False)
        for window_id in (found.stdout or '').split():
            if not window_id.isdigit():
                continue
            subprocess.run(['xdotool', 'windowmap', '--sync', window_id], env=env, timeout=2, check=False)
            subprocess.run(['xdotool', 'windowactivate', '--sync', window_id], env=env, timeout=2, check=False)
            subprocess.run(['xdotool', 'windowraise', window_id], env=env, timeout=1, check=False)
            log.write('EmulationStation window remapped (wid ' + window_id + ')\n')
    except (OSError, subprocess.SubprocessError) as error:
        log.write('EmulationStation remap skipped: ' + str(error) + '\n')


_focus_logged_wid = ''

def focus_switchres_grid(log) -> bool:
    """Raise the native grid window and drop any leftover Pygame menu shells."""
    global _focus_logged_wid
    env = x11_display_env()
    try:
        for tool_name in ('Batocera CRT Script', 'Switchres Geometry'):
            found = subprocess.run(['xdotool', 'search', '--name', tool_name],
                                   capture_output=True, text=True, env=env, timeout=2, check=False)
            for window_id in (found.stdout or '').split():
                if window_id.isdigit():
                    subprocess.run(['xdotool', 'windowunmap', window_id],
                                   env=env, timeout=1, check=False)
        found = subprocess.run(['xdotool', 'search', '--name', 'Switchres test grid'],
                                 capture_output=True, text=True, env=env, timeout=2, check=False)
        window_ids = [value for value in (found.stdout or '').split() if value.isdigit()]
        if not window_ids:
            return False
        window_id = window_ids[-1]
        subprocess.run(['xdotool', 'windowmap', '--sync', window_id], env=env, timeout=2, check=False)
        subprocess.run(['xdotool', 'windowactivate', '--sync', window_id], env=env, timeout=2, check=False)
        subprocess.run(['xdotool', 'windowfocus', window_id], env=env, timeout=1, check=False)
        subprocess.run(['xdotool', 'windowraise', window_id], env=env, timeout=1, check=False)
        if window_id != _focus_logged_wid:
            _focus_logged_wid = window_id
            log.write('Native grid focused (wid ' + window_id + ')\n')
        return True
    except (OSError, subprocess.SubprocessError) as error:
        log.write('Native grid focus failed: ' + str(error) + '\n')
        return False


def wrap(font, text: str, width: int) -> list[str]:
    lines = []
    for paragraph in text.split('\n'):
        current = ''
        for word in paragraph.split():
            while font.size(word)[0] > width:
                if current:
                    lines.append(current)
                    current = ''
                low, high = 1, len(word)
                while low < high:
                    middle = (low + high + 1) // 2
                    if font.size(word[:middle])[0] <= width: low = middle
                    else: high = middle - 1
                lines.append(word[:low])
                word = word[low:]
            if not word: continue
            candidate = (current + ' ' + word).strip()
            if current and font.size(candidate)[0] > width:
                lines.append(current)
                current = word
            else:
                current = candidate
        lines.append(current)
    return lines


class SessionCursor:
    """Hide the X11 cursor across SDL/native transitions, with client-owned cleanup.

    XFixes v4 hides a window's complete subtree, including cursor grabs. Closing
    this private connection removes only our hide request, even after a crash.
    No window, overlay, input grab, background process or settings file is used.
    """
    def __init__(self, driver, log, loader=None, *, tool_name='Geometry'):
        self.connection, self.hidden, self.root = None, False, 0
        self.x11, self.fixes = None, None
        if driver != 'x11': return
        try:
            loader = loader or C.CDLL
            self.x11, self.fixes = loader('libX11.so.6'), loader('libXfixes.so.3')
            definitions = [
                (self.x11, 'XOpenDisplay', [C.c_char_p], C.c_void_p),
                (self.x11, 'XDefaultRootWindow', [C.c_void_p], C.c_ulong),
                (self.x11, 'XSync', [C.c_void_p, C.c_int], C.c_int),
                (self.x11, 'XCloseDisplay', [C.c_void_p], C.c_int),
                (self.fixes, 'XFixesQueryVersion', [C.c_void_p, C.POINTER(C.c_int), C.POINTER(C.c_int)], C.c_int),
                (self.fixes, 'XFixesHideCursor', [C.c_void_p, C.c_ulong], None),
                (self.fixes, 'XFixesShowCursor', [C.c_void_p, C.c_ulong], None),
            ]
            for library, name, args, result in definitions:
                function = getattr(library, name)
                function.argtypes, function.restype = args, result
            self.connection = self.x11.XOpenDisplay(None)
            if not self.connection: raise RuntimeError('X11 cursor connection unavailable')
            major, minor = C.c_int(4), C.c_int(0)
            if not self.fixes.XFixesQueryVersion(self.connection, C.byref(major), C.byref(minor)) or major.value < 4:
                raise RuntimeError('XFixes cursor hiding unavailable')
            self.root = self.x11.XDefaultRootWindow(self.connection)
            if not self.root: raise RuntimeError('X11 root window unavailable')
            self.fixes.XFixesHideCursor(self.connection, self.root)
            self.hidden = True
            self.x11.XSync(self.connection, 0)
            log.write('Mouse cursor hidden for the ' + tool_name + ' session\n')
        except (OSError, AttributeError, RuntimeError) as error:
            self.close()
            log.write('Session cursor hiding unavailable: ' + str(error) + '\n')
        log.flush()

    def close(self):
        connection, self.connection = self.connection, None
        if connection:
            try:
                if self.hidden:
                    self.fixes.XFixesShowCursor(connection, self.root)
                    self.x11.XSync(connection, 0)
            except (OSError, AttributeError, RuntimeError):
                pass  # Closing the private connection also releases our request.
            finally:
                self.hidden = False
                try: self.x11.XCloseDisplay(connection)
                except (OSError, AttributeError, RuntimeError): pass


class Display:
    def __init__(self, pygame, window: bool, size: tuple[int, int] | None = None, *,
                 tool_name='Geometry', subtitle='SWITCHRES CALIBRATION',
                 back_hint='HOTKEY+START / ESC: back'):
        self.p = pygame
        self.window = window
        self.size = size
        self.tool_name, self.subtitle = tool_name, subtitle
        self.back_hint = back_hint
        self.surface = None
        self.ever_opened = False
        self.open()

    def open(self) -> None:
        p = self.p
        p.display.init()
        p.font.init()
        info = p.display.Info()
        size = self.size or ((769, 576) if self.window else (info.current_w or 769, info.current_h or 576))
        # The menu covers the desktop without taking ownership of its video mode.
        # Native Switchres may replace mode IDs while its grid is active; SDL's
        # exclusive-fullscreen restore can then fail with RRSetCrtcConfig BadMatch.
        self.surface = p.display.set_mode(size, 0 if self.window else p.NOFRAME)
        p.display.set_caption('Batocera CRT Script - Switchres ' + self.tool_name)
        p.mouse.set_visible(False)
        p.event.set_blocked([p.MOUSEMOTION, p.MOUSEBUTTONDOWN, p.MOUSEBUTTONUP, p.MOUSEWHEEL])
        p.key.set_repeat(260, 90)
        p.event.clear()
        # SDL's new window starts black. Paint before starting/waiting for the
        # backend, including when returning from the native grid. This is the
        # ordinary menu window; no cover is kept above the calibration grid.
        title = ('RETURNING TO ' if self.ever_opened else 'STARTING ') + self.tool_name.upper()
        self.ever_opened = True
        Display.draw(self, Screen(title, 'Please wait...', busy=True))

    def release(self, log=None) -> None:
        # Native Switchres/grid must own the visible framebuffer. A borderless
        # fullscreen Pygame menu painted black can stay mapped above the grid.
        p = self.p
        try:
            if self.surface is not None:
                if self.window:
                    self.surface.fill((0, 0, 0))
                    p.display.flip()
                else:
                    hidden = getattr(p, 'HIDDEN', None)
                    try:
                        if hidden is not None:
                            p.display.set_mode((1, 1), hidden)
                        else:
                            p.display.iconify()
                    except Exception:
                        pass
        finally:
            if not self.window and log is not None:
                withdraw_sdl_menu(p, log)
            p.display.quit()
            self.surface = None

    def draw(self, view: Screen, preview: bool = False) -> None:
        if view.help_page:
            self.draw_help(view, preview)
            return
        p, screen = self.p, self.surface
        width, height = screen.get_size()
        scale = max(.55, min(1.35, height / 576))
        bg, green, dim, dark, yellow = (5, 15, 5), (0, 255, 102), (0, 110, 45), (0, 45, 18), (255, 230, 0)
        screen.fill(bg)
        p.draw.rect(screen, dim, (1, 1, width - 2, height - 2), 2)
        p.draw.line(screen, dim, (width // 2, 0), (width // 2, height), 1)
        p.draw.line(screen, dim, (0, height // 2), (width, height // 2), 1)
        margin = max(10, int(18 * scale))
        box_w = min(width - 2 * margin, max(500, int(610 * scale)))
        box_h = min(height - 2 * margin, max(205, int(430 * scale)))
        box = p.Rect((width - box_w) // 2, (height - box_h) // 2, box_w, box_h)
        p.draw.rect(screen, (0, 0, 0), box)
        p.draw.rect(screen, green, box, 2)
        pad = max(12, int(26 * scale))
        title_size = max(13, int(20 * scale))
        title_font = p.font.SysFont('monospace', title_size, bold=True)
        while title_font.size(view.title)[0] > box.width - 2 * pad and title_size > 8:
            title_size -= 1
            title_font = p.font.SysFont('monospace', title_size, bold=True)
        title = title_font.render(view.title, True, green)
        screen.blit(title, title.get_rect(center=(width // 2, box.top + max(22, int(35 * scale)))))
        small = p.font.SysFont('monospace', max(10, int(13 * scale)), bold=True)
        main = p.font.SysFont('monospace', max(12, int(17 * scale)), bold=True)
        subtitle = small.render('PREVIEW ONLY - no system changes' if preview else self.subtitle, True, yellow)
        screen.blit(subtitle, subtitle.get_rect(center=(width // 2, box.top + max(41, int(61 * scale)))))
        row_h = max(24, int(43 * scale))
        footer_h = max(32, int(60 * scale))
        choices_y = box.bottom - footer_h - len(view.choices) * row_h
        text_y = box.top + max(58, int(91 * scale))
        body_bottom = choices_y - 8 if view.choices else box.bottom - footer_h - 30
        text_size = max(12, int(17 * scale))
        min_text_size = 12 if height >= 480 else 10
        text_font = p.font.SysFont('monospace', text_size, bold=True)
        message = view.message[:16384]
        while True:
            body = wrap(text_font, message, box.width - 2 * pad)
            available_lines = max(1, (body_bottom - text_y) // text_font.get_linesize())
            if (len(body) <= available_lines or (len(body) > 8 and available_lines >= 8)
                    or text_size <= min_text_size):
                break
            text_size -= 1
            text_font = p.font.SysFont('monospace', text_size, bold=True)
        capacity = min(8, max(1, (body_bottom - text_y) // text_font.get_linesize()))
        if len(body) > capacity or len(message) != len(view.message):
            body = body[:capacity]
            body[-1] = 'More details: geometry-ui.log'
        for line in body:
            rendered = text_font.render(line, True, dim)
            screen.blit(rendered, (box.left + pad, text_y))
            text_y += text_font.get_linesize()
        for index, choice in enumerate(view.choices):
            rect = p.Rect(box.left + pad, choices_y + index * row_h, box.width - 2 * pad, row_h - 5)
            chosen = index == view.selected
            if chosen: p.draw.rect(screen, dark, rect, border_radius=4)
            font = main
            choice_size = max(12, int(17 * scale))
            label = ('> ' if chosen else '  ') + choice.label
            while font.size(label)[0] > rect.width - 14 and choice_size > 8:
                choice_size -= 1
                font = p.font.SysFont('monospace', choice_size, bold=True)
            rendered = font.render(label, True, green if chosen else dim)
            screen.blit(rendered, rendered.get_rect(midleft=(rect.left + 7, rect.centery)))
        if view.busy:
            track = p.Rect(box.left + pad, box.bottom - footer_h - 10, box.width - 2 * pad, max(6, int(9 * scale)))
            p.draw.rect(screen, dark, track)
            segment = max(12, track.width // 5)
            offset = int((time.monotonic() % 2) / 2 * (track.width - segment))
            p.draw.rect(screen, yellow, (track.left + offset, track.top, segment, track.height))
        legends = ['Please wait...' if view.busy else 'D-PAD / ARROWS: choose   A / ENTER: select',
                   'PREVIEW: changes are simulated' if preview else 'Finishing the current operation' if view.busy else self.back_hint]
        for index, line in enumerate(legends):
            label = small.render(line, True, dim)
            last_center = box.bottom - max(9, int(18 * scale))
            screen.blit(label, label.get_rect(center=(width // 2, last_center - (1 - index) * small.get_linesize())))
        p.display.flip()

    def draw_help(self, view: Screen, preview: bool = False) -> None:
        """A dedicated, readable help layout instead of truncating a dialog body."""
        p, target = self.p, self.surface
        width, height = target.get_size()
        scale = min(width / 640, height / 480)
        canvas = p.Surface((640, 480))
        green, dim, yellow = (0, 255, 102), (65, 177, 107), (255, 230, 0)
        canvas.fill((5, 15, 5))
        p.draw.rect(canvas, (0, 0, 0), (18, 18, 604, 444))
        p.draw.rect(canvas, green, (18, 18, 604, 444), 2)
        def text(value, x, y, size=16, color=green, center=False):
            image = p.font.SysFont('monospace', size, bold=True).render(value, True, color)
            canvas.blit(image, image.get_rect(midtop=(x, y)) if center else (x, y))
        text(view.title, 320, 34, 22, center=True)
        text('XBOX 360 POSITIONS' if view.help_page == 'gamepad' else 'KEYBOARD - NATIVE SWITCHRES GRID',
             320, 65, 15, yellow, True)
        if view.help_page == 'gamepad':
            draw_xbox360(p, canvas, p.Rect(30, 106, 238, 180))
            for index, (control, action) in enumerate(GAMEPAD_CONTROLS):
                y = 96 + index * 24
                text(control, 282, y, 15, yellow)
                text(action, 397, y, 15)
            text('Y / START / triggers: unused', 150, 292, 11, dim, True)
            notes = ('Labels follow Xbox positions; other pads may differ.',
                     'Reset changes the preview only. Saving needs review.')
        else:
            for index, (control, action) in enumerate(KEYBOARD_CONTROLS):
                y = 94 + index * 30
                text(control, 36, y, 14, yellow)
                text(action, 36, y + 15, 12)
            notes = ('In menus: arrows choose; Enter selects; Escape goes back.',
                     'Reset / reload never restore or overwrite saved files.')
        for index, line in enumerate(notes):
            text(line, 320, 319 + index * 17, 13, dim, True)
        for index, choice in enumerate(view.choices):
            rect = p.Rect(36, 363 + index * 31, 568, 28)
            chosen = index == view.selected
            if chosen: p.draw.rect(canvas, (0, 45, 18), rect, border_radius=4)
            text(('> ' if chosen else '  ') + choice.label, 45, rect.top + 5, 16, green if chosen else dim)
        text('D-PAD: choose   A: select   BACK+START: back', 320, 433, 12, dim, True)
        if preview:
            text('PREVIEW ONLY', 320, 8, 10, yellow, True)
        size = (max(1, round(640 * scale)), max(1, round(480 * scale)))
        target.fill((5, 15, 5))
        target.blit(p.transform.smoothscale(canvas, size), ((width-size[0])//2, (height-size[1])//2))
        p.display.flip()


def stop_native(process) -> None:
    """Stop only the private native session, including Switchres/grid children."""
    if os.name != 'posix':
        if process.poll() is None: process.terminate()
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=3)
        return
    try: os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError: pass
    deadline = time.monotonic() + .3
    while time.monotonic() < deadline:
        process.poll()
        try: os.killpg(process.pid, 0)
        except ProcessLookupError: break
        time.sleep(.02)
    # The native Python parent can exit before one of its grid children does.
    # Kill any remaining members of that same isolated group, not the app/ES.
    try: os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError: pass
    process.wait(timeout=3)


def install_termination_handlers():
    previous = {}
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Geometry interrupted by ' + signal.Signals(signum).name)
    for name in ('SIGTERM', 'SIGHUP'):
        number = getattr(signal, name, None)
        if number is not None:
            previous[number] = signal.signal(number, interrupted)
    return previous


def run_native(args: list[str], display: Display, log) -> tuple[int, str]:
    command = native_command(args)
    try:
        released_at = time.monotonic()
        display.release(log)
        hide_emulationstation(log)
        log.write('Native command: ' + ' '.join(command) + '\n')
        log.write('Timing: menu released in {:.3f}s\n'.format(time.monotonic() - released_at))
        with tempfile.TemporaryFile() as output:
            process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=output, stderr=log,
                                       start_new_session=os.name == 'posix')
            try:
                log.write('Native Geometry started (pid ' + str(process.pid) + ')\n')
                log.flush()
                last_focus_at = 0.0
                while process.poll() is None:
                    now = time.monotonic()
                    if now - last_focus_at >= 0.45:
                        focus_switchres_grid(log)
                        last_focus_at = now
                    try: process.wait(timeout=.12)
                    except subprocess.TimeoutExpired: pass
                code = process.returncode
                stop_native(process)
            except BaseException:
                stop_native(process)
                raise
            size = output.tell()
            output.seek(max(0, size - 256 * 1024))
            result = output.read().decode('utf-8', errors='replace')
        log.write('Native Geometry exited with status ' + str(code) + '\n')
        if result:
            log.write(result[-16384:].rstrip('\n') + '\n')
        log.flush()
        return code if code >= 0 else 128 - code, result
    finally:
        reopened_at = time.monotonic()
        log.write(time.strftime('%H:%M:%S') + ' Reopening Geometry display\n')
        log.flush()
        display.open()
        log.write('Timing: Geometry display reopened and painted in {:.3f}s\n'.format(time.monotonic() - reopened_at))
        log.flush()


def open_log(path: Path):
    if any(p.is_symlink() for p in path.parents):
        raise ValueError('Unsafe Geometry log directory')
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | getattr(os, 'O_NOFOLLOW', 0)
                 | getattr(os, 'O_NONBLOCK', 0), 0o600)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or (hasattr(os, 'geteuid') and info.st_uid != os.geteuid()):
        os.close(fd)
        raise ValueError('Unsafe Geometry log')
    return os.fdopen(fd, 'a', buffering=1)


def serve(display: Display, backend: Backend | None, preview: str | None, log) -> int:
    p = display.p
    view = preview_screen(preview) if preview else Screen('STARTING GEOMETRY', 'Checking the current environment...', busy=True)
    awaiting = False
    closing = False
    handled_error = False
    final_code = None
    parent_menu = None
    armed_at = time.monotonic() + .3
    clock = p.time.Clock()
    while True:
        if backend:
            request = backend.receive()
            if request:
                kind, args = request['type'], request['args']
                if kind == 'native':
                    if closing:
                        backend.reply(1, 'Aborted!')
                    else:
                        try:
                            code, output = run_native(args, display, log)
                        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                            log.write('Native Geometry stopped: ' + str(error) + '\n')
                            code, output = 127, ''
                        backend.reply(code, output)
                        view = Screen('PREPARING CALIBRATION', 'Reading the native calibration result...', busy=True)
                    armed_at = time.monotonic() + .3
                elif kind == 'progress':
                    if len(args) != 1: raise ValueError('Invalid progress request')
                    view = Screen('SAVING CALIBRATION', args[0], busy=True)
                    backend.reply(0)
                else:
                    view = prompt_screen(args)
                    log.write(view.title + ': ' + view.message.replace('\n', ' | ') + '\n')
                    log.flush()
                    if closing:
                        backend.reply(255)
                    else:
                        awaiting = True
                        armed_at = time.monotonic() + .3
            code = backend.process.poll()
            if code is not None:
                if code == 0 or handled_error or closing:
                    return code
                if final_code is None:
                    final_code = code
                    view = Screen('GEOMETRY STOPPED', 'The operation did not complete. Details are in geometry-ui.log.\nKeep your backups and run Geometry again to check recovery.', [Choice('Return to EmulationStation', 0)])
                    armed_at = time.monotonic() + .3
        display.draw(view, preview is not None)
        for event in p.event.get():
            if event.type == p.QUIT:
                if not backend: return 0
                closing = True
                if awaiting:
                    backend.reply(255)
                    awaiting = False
                view = Screen('FINISHING GEOMETRY', 'Finishing any approved save before closing...', busy=True)
                continue
            if event.type != p.KEYDOWN or time.monotonic() < armed_at:
                continue
            if view.busy:
                continue
            if event.key in (p.K_UP, p.K_LEFT, p.K_w, p.K_a):
                view.selected = (view.selected - 1) % len(view.choices)
            elif event.key in (p.K_DOWN, p.K_RIGHT, p.K_TAB, p.K_s, p.K_d):
                view.selected = (view.selected + 1) % len(view.choices)
            elif event.key in (p.K_RETURN, p.K_KP_ENTER, p.K_SPACE, p.K_ESCAPE, p.K_q):
                escape = event.key in (p.K_ESCAPE, p.K_q)
                choice = Choice('', 255) if escape else view.choices[view.selected]
                if view.help_page:
                    # Keep the backend's original menu request pending. Help
                    # cannot start calibration, approve restore, or write files.
                    if choice.output == ':help_keyboard':
                        view = help_screen('keyboard')
                    elif choice.output == ':help_gamepad' or (escape and view.help_page == 'keyboard'):
                        view = help_screen('gamepad')
                    elif parent_menu is not None:
                        view, parent_menu = parent_menu, None
                    else:
                        return 0  # Standalone help preview.
                    armed_at = time.monotonic() + .3
                    continue
                if parent_menu is not None:
                    if not escape and view.selected == 1:
                        if backend:
                            backend.reply(0, 'Restore Files')
                            awaiting = False
                            view = Screen('RESTORING CALIBRATION', 'Preparing recovery files...', busy=True)
                        else: view = preview_screen('complete')
                        parent_menu = None
                    else:
                        view, parent_menu = parent_menu, None
                    armed_at = time.monotonic() + .3
                    continue
                if choice.output == ':help':
                    parent_menu = view
                    view = help_screen('gamepad')
                    log.write('Opened button mapping help\n')
                    log.flush()
                    armed_at = time.monotonic() + .3
                    continue
                if choice.output == 'Restore Files':
                    parent_menu = view
                    view = preview_screen('restore')
                    armed_at = time.monotonic() + .3
                    continue
                if final_code is not None:
                    return final_code
                if backend and awaiting:
                    backend.reply(choice.code, choice.output)
                    handled_error = view.title == 'GEOMETRY ERROR'
                    awaiting = False
                    view = Screen('WORKING', 'Please wait...', busy=True)
                elif not backend:
                    if escape or choice.output == 'Quit': return 0
                    if choice.output == '640x480@60': view = preview_screen('review')
                    elif view.title == 'APPLY CALIBRATION?' and choice.code == 0: view = preview_screen('complete')
                    else: return 0
                armed_at = time.monotonic() + .3
        clock.tick(40)


def main(argv=None) -> int:
    started_at = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--window', action='store_true')
    parser.add_argument('--preview', choices=PREVIEWS)
    parser.add_argument('--render-preview', type=Path)
    parser.add_argument('--size', nargs=2, type=int, metavar=('WIDTH', 'HEIGHT'))
    args = parser.parse_args(argv)
    if args.render_preview and not args.preview:
        parser.error('--render-preview requires --preview')
    if args.size and (not args.preview or not 320 <= args.size[0] <= 3840 or not 240 <= args.size[1] <= 2160):
        parser.error('--size requires a preview and dimensions of at least 320x240')
    os.environ.setdefault('PYGAME_HIDE_SUPPORT_PROMPT', '1')
    if args.render_preview: os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')
    try:
        import pygame
        display = Display(pygame, args.window or bool(args.render_preview), tuple(args.size) if args.size else None)
    except Exception as error:
        # No backend was started; return a distinct display/import failure.
        print('Visual Geometry interface unavailable: ' + str(error), file=sys.stderr)
        return UNAVAILABLE
    backend, cursor = None, None
    previous_handlers = install_termination_handlers()
    try:
        if args.render_preview:
            display.draw(preview_screen(args.preview), True)
            pygame.image.save(display.surface, str(args.render_preview))
            return 0
        if args.preview:
            return serve(display, None, args.preview, sys.stderr)
        script = HERE / 'geometry_backend.py'
        if script.is_symlink() or not script.is_file(): raise ValueError('Geometry backend missing or unsafe')
        with open_log(Path('/userdata/system/logs/geometry-ui.log')) as log:
            log.write(time.strftime('%Y-%m-%d %H:%M:%S') + ' Visual Geometry started\n')
            log.write('Timing: initial display ready and painted after {:.3f}s\n'.format(time.monotonic() - started_at))
            hide_window_ready = ensure_es_hide_window(log)
            if not hide_window_ready:
                os.environ['GEOMETRY_LAUNCH_NEEDS_ES_RELAUNCH'] = '1'
            elif not es_hide_window_enabled():
                log.write('Warning: HideWindow is not enabled; the CRT may stay black during native grid\n')
            cursor = SessionCursor(pygame.display.get_driver(), log)
            backend = Backend(script, log)
            try:
                result = serve(display, backend, None, log)
                log.write('Geometry backend finished with status ' + str(result) + '; closing menu\n')
                log.flush()
            except (OSError, ValueError, RuntimeError, KeyboardInterrupt) as error:
                log.write('Visual Geometry stopped: ' + str(error) + '\n')
                raise
            # 78 is reserved for display/import failure BEFORE backend start.
            # Never let a backend status cause the launcher to repeat a write.
            return 1 if result == UNAVAILABLE else result
    except (OSError, ValueError, RuntimeError, KeyboardInterrupt) as error:
        print('Visual Geometry stopped: ' + str(error), file=sys.stderr)
        return 1
    finally:
        try:
            if backend: backend.close()
        finally:
            try:
                with open_log(Path('/userdata/system/logs/geometry-ui.log')) as log:
                    show_emulationstation(log)
            except (OSError, ValueError, RuntimeError):
                pass
            try:
                pygame.quit()
            finally:
                if cursor: cursor.close()
                for number, handler in previous_handlers.items(): signal.signal(number, handler)


if __name__ == '__main__':
    raise SystemExit(main())
