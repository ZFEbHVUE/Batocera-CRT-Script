#!/usr/bin/env python3
"""Python CRT Grid Tool: service-menu patterns, not software calibration.

Shares Geometry's renderer, controller drawing and cursor handling. The native
Switchres/grid programs remain in charge of displaying and restoring test modes.
No calibration, EDID, boot configuration, overlay or backup is saved here.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile
import time

from geometry import (Choice, Screen, Display, SessionCursor, draw_xbox360,
                      ensure_es_hide_window, focus_switchres_grid, hide_emulationstation,
                      install_termination_handlers, open_log, stop_native)

RESOLUTIONS = {'640x480@60': ('640', '480', '60'), '320x240@60': ('320', '240', '60')}
EXIT_CODES = {0, 1, 2, 3, 64, 65, 66, 67, 68, 69}
PREVIEWS = ('notice', 'menu', 'gamepad', 'keyboard', 'error')
GAMEPAD = (
    ('D-PAD/STICK', 'Choose in menus'),
    ('A (bottom)', 'Show / return to menu'),
    ('B (right)', 'Back / close grid'),
    ('X / Y', 'Change grid pattern'),
    ('LB / RB', 'Change grid pattern'),
    ('LT / RT', 'Change grid pattern'),
    ('BACK+START', 'Exit the Grid Tool'),
)
KEYBOARD = (
    ('ARROWS / W A S D', 'Choose in menus; D-pad is inactive in the grid'),
    ('ENTER / RETURN', 'Show a grid / return to its resolution menu'),
    ('ESC / Q', 'Back / close the grid'),
    ('TAB', 'Switch between the two native patterns'),
    ('CTRL + Q', 'Exit the Grid Tool from any screen'),
)


class GridError(RuntimeError):
    pass


def notice():
    return Screen('BEFORE YOU START',
        'Use this grid to adjust your CRT with its service menu. Write down the original TV '
        'service-menu values and keep them safe before you change anything. Adjust the monitor as '
        'close as possible to the grid before you leave this tool, then use the Geometry Adjustment '
        'tool afterward only for small software fine-tuning.',
        [Choice('Continue', 0), Choice('Return to EmulationStation', 0, 'quit')])


def menu(selected=0):
    return Screen('CRT GRID TOOL',
        'Choose a test resolution and adjust the picture with your CRT service menu.\n'
        'This tool does not save software calibration.',
        [Choice('640 x 480 / 60 Hz (recommended)', 0, '640x480@60'),
         Choice('320 x 240 / 60 Hz', 0, '320x240@60'),
         Choice('Help - Button Mapping', 0, 'help'),
         Choice('Return to EmulationStation', 0, 'quit')], selected=selected)


def help_screen(page='gamepad'):
    choices = ([Choice('Back to Grid Tool', 0, 'help_close'), Choice('Keyboard controls', 0, 'keyboard')]
               if page == 'gamepad' else
               [Choice('Back to gamepad controls', 0, 'gamepad'), Choice('Back to Grid Tool', 0, 'help_close')])
    return Screen('HELP - BUTTON MAPPING', '', choices, help_page=page)


def error_screen():
    return Screen('GRID TOOL ERROR',
        'The grid could not complete normally. Details are in grid-tool.log.\n'
        'Return to the menu or EmulationStation.',
        [Choice('Back to resolution menu', 0, 'menu'), Choice('Return to EmulationStation', 0, 'quit')])


def preview(name):
    return {'notice': notice, 'menu': menu, 'gamepad': help_screen,
            'keyboard': lambda: help_screen('keyboard'), 'error': error_screen}[name]()


class GridDisplay(Display):
    def __init__(self, pygame, window, size=None):
        super().__init__(pygame, window, size, tool_name='Grid Tool', subtitle='CRT SERVICE-MENU TEST PATTERNS',
                         back_hint='B / ESC: back   HOTKEY+START: exit')

    def draw_help(self, view, preview=False):
        p, target = self.p, self.surface
        width, height = target.get_size()
        scale = min(width / 640, height / 480)
        canvas = p.Surface((640,480))
        green, dim, yellow = (0,255,102), (65,177,107), (255,230,0)
        canvas.fill((5,15,5))
        p.draw.rect(canvas,(0,0,0),(18,18,604,444))
        p.draw.rect(canvas,green,(18,18,604,444),2)
        def text(value,x,y,size=15,color=green,center=False):
            label = p.font.SysFont('monospace',size,bold=True).render(value,True,color)
            canvas.blit(label,label.get_rect(midtop=(x,y)) if center else (x,y))
        text(view.title,320,34,22,center=True)
        text('XBOX 360 POSITIONS' if view.help_page == 'gamepad' else 'KEYBOARD - NATIVE GRID',
             320,65,15,yellow,True)
        if view.help_page == 'gamepad':
            draw_xbox360(p,canvas,p.Rect(30,106,238,180))
            for index,(control,action) in enumerate(GAMEPAD):
                text(control,282,96+index*26,14,yellow)
                text(action,397,96+index*26,14)
            text('START alone: unused',150,292,12,dim,True)
            notes = ('D-pad / stick only navigate the Python menus.',
                     'A returns to resolutions. B closes the current grid.')
        else:
            for index,(control,action) in enumerate(KEYBOARD):
                y = 99+index*39
                text(control,36,y,14,yellow)
                text(action,36,y+17,12)
            notes = ('Native keyboard arrows close the grid; use Tab there.',
                     'Keep the original TV service-menu values safe.')
        for index,line in enumerate(notes):text(line,320,319+index*17,13,dim,True)
        for index,choice in enumerate(view.choices):
            rect = p.Rect(36,363+index*31,568,28)
            chosen = index == view.selected
            if chosen:p.draw.rect(canvas,(0,45,18),rect,border_radius=4)
            text(('> ' if chosen else '  ')+choice.label,45,rect.top+5,16,green if chosen else dim)
        text('D-PAD: choose   A: select   B: back   BACK+START: exit',320,433,11,dim,True)
        if preview:text('PREVIEW ONLY',320,8,10,yellow,True)
        size = (max(1,round(640*scale)),max(1,round(480*scale)))
        target.fill((5,15,5))
        target.blit(p.transform.smoothscale(canvas,size),((width-size[0])//2,(height-size[1])//2))
        p.display.flip()


def grid_command(resolution):
    if resolution not in RESOLUTIONS:raise GridError('Unknown Grid resolution')
    # An absolute ini prevents a missing relative file or launcher cwd from
    # choosing a different profile. No --keep, EDID output or configuration write.
    return ['/usr/bin/switchres',*RESOLUTIONS[resolution],'-i','/etc/switchres.ini','-v','-l','/usr/bin/grid']


def native_exit(output, returncode):
    found = re.findall(r'^Process exited with value\s+(-?\d+)\s*$',output,re.M)
    if not found:raise GridError('Switchres returned no native grid result')
    code = int(found[-1])
    # Some older wrappers report the POSIX wait status instead of WEXITSTATUS.
    if code >= 256 and code % 256 == 0:code >>= 8
    if not 0 <= code <= 255 or code & 127 not in EXIT_CODES:
        raise GridError('Unexpected native grid exit code')
    if returncode not in (0,code):raise GridError('Switchres failed while restoring the display')
    return 'quit' if code == 129 else 'menu'


def run_grid(resolution, display, log):
    command = grid_command(resolution)
    env = dict(os.environ)
    env.pop('GRID_TEXT',None)
    try:
        display.release(log)
        hide_emulationstation(log)
        with tempfile.TemporaryFile() as output:
            process = subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT,
                                       start_new_session=os.name == 'posix',env=env)
            log.write(time.strftime('%H:%M:%S')+' Native grid started: '+resolution+' (pid '+str(process.pid)+')\n')
            log.flush()
            focus_attempts = 0
            try:
                while process.poll() is None:
                    if focus_attempts < 6 and focus_switchres_grid(log):
                        focus_attempts += 1
                    try:process.wait(timeout=.12)
                    except subprocess.TimeoutExpired:pass
                code = process.returncode
                stop_native(process)
            except BaseException:
                stop_native(process)
                raise
            size = output.tell()
            output.seek(max(0,size-256*1024))
            result = output.read().decode(errors='replace')
        log.write(result[-16384:].rstrip('\n')+'\n')
        action = native_exit(result,code)
        log.write('Native grid returned: '+action+'\n');log.flush()
        return action
    finally:
        started = time.monotonic()
        display.open()
        log.write('Timing: Grid display reopened and painted in {:.3f}s\n'.format(time.monotonic()-started))
        log.flush()


@contextmanager
def display_lock(path=Path('/userdata/Batocera-CRT-Script-Backup/runtime-switch.lock')):
    import fcntl
    if any(p.is_symlink() for p in (path,*path.parents)):raise GridError('Redirected display lock')
    path.parent.mkdir(parents=True,exist_ok=True)
    fd = os.open(path,os.O_WRONLY|os.O_CREAT|os.O_NOFOLLOW|os.O_NONBLOCK,0o600)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid():
            raise GridError('Unsafe display lock')
        try:fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:raise GridError('Another CRT tool or installation is active')
        yield
    finally:os.close(fd)


def serve(display, log, preview_name=None):
    p = display.p
    view = preview(preview_name) if preview_name else notice()
    parent, selected, failed = None, 0, False
    armed = time.monotonic()+.3
    clock = p.time.Clock()
    while True:
        display.draw(view,preview_name is not None)
        for event in p.event.get():
            if event.type == p.QUIT:return 1 if failed else 0
            if event.type != p.KEYDOWN or time.monotonic() < armed:continue
            control = bool(getattr(event,'mod',0)&p.KMOD_CTRL)
            if control and event.key in (p.K_q,p.K_ESCAPE):return 1 if failed else 0
            if event.key in (p.K_UP,p.K_LEFT,p.K_w,p.K_a):view.selected=(view.selected-1)%len(view.choices)
            elif event.key in (p.K_DOWN,p.K_RIGHT,p.K_TAB,p.K_s,p.K_d):view.selected=(view.selected+1)%len(view.choices)
            elif event.key in (p.K_RETURN,p.K_KP_ENTER,p.K_SPACE,p.K_ESCAPE,p.K_q):
                back = event.key in (p.K_ESCAPE,p.K_q)
                choice = Choice('',0,'back') if back else view.choices[view.selected]
                action = choice.output
                if view.help_page:
                    if action == 'keyboard':view=help_screen('keyboard')
                    elif action == 'gamepad' or back and view.help_page == 'keyboard':view=help_screen()
                    elif parent is not None:view,parent=parent,None
                    else:return 0
                elif action == 'quit' or back and view.title in ('CRT GRID TOOL','BEFORE YOU START'):
                    return 1 if failed else 0
                elif view.title == 'BEFORE YOU START':view=menu()
                elif action == 'help':parent,view=view,help_screen()
                elif action == 'menu' or back:view=menu(selected)
                elif action in RESOLUTIONS:
                    selected=view.selected
                    if preview_name:view=menu(selected)
                    else:
                        try:
                            if run_grid(action,display,log)=='quit':return 0
                            view=menu(selected)
                        except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as error:
                            failed=True
                            log.write('Grid stopped: '+str(error)+'\n');log.flush()
                            view=error_screen()
                armed=time.monotonic()+.3
        clock.tick(40)


def main(argv=None):
    started = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--window',action='store_true')
    parser.add_argument('--preview',choices=PREVIEWS)
    parser.add_argument('--render-preview',type=Path)
    parser.add_argument('--size',nargs=2,type=int)
    args=parser.parse_args(argv)
    if args.render_preview and not args.preview:parser.error('--render-preview requires --preview')
    if args.size and (not args.preview or not all(240<=n<=3840 for n in args.size)):
        parser.error('--size requires a preview and dimensions from 240 to 3840')
    os.environ.setdefault('PYGAME_HIDE_SUPPORT_PROMPT','1')
    if args.render_preview:os.environ.setdefault('SDL_VIDEODRIVER','dummy')
    try:
        import pygame
        display=GridDisplay(pygame,args.window or bool(args.render_preview),tuple(args.size) if args.size else None)
    except Exception as error:
        print('Grid interface unavailable: '+str(error),file=sys.stderr)
        return 78
    cursor=None
    previous=install_termination_handlers()
    try:
        if args.render_preview:
            display.draw(preview(args.preview),True)
            pygame.image.save(display.surface,str(args.render_preview));return 0
        if args.preview:return serve(display,sys.stderr,args.preview)
        with open_log(Path('/userdata/system/logs/grid-tool.log')) as log:
            log.write(time.strftime('%Y-%m-%d %H:%M:%S')+' Python Grid Tool started\n')
            log.write('Timing: initial Grid display ready after {:.3f}s\n'.format(time.monotonic()-started))
            if not ensure_es_hide_window(log):
                return show_refusal(display, log, title='RELAUNCH REQUIRED',
                    message=('EmulationStation must release the CRT display before the test grid '
                             'can appear.\n\nHideWindow is now enabled. Exit to EmulationStation, '
                             'then launch Grid Tool again.'))
            cursor=SessionCursor(pygame.display.get_driver(),log,tool_name='Grid Tool')
            try:
                with display_lock():code=serve(display,log)
            except (OSError,ValueError,RuntimeError) as error:
                log.write('Grid refused: '+str(error)+'\n');log.flush()
                # One error screen, no native launch or configuration changes.
                code=show_refusal(display,log)
            log.write('Grid Tool finished with status '+str(code)+'\n');log.flush()
            return code
    except (OSError,ValueError,RuntimeError,KeyboardInterrupt) as error:
        print('Grid Tool stopped: '+str(error),file=sys.stderr);return 1
    finally:
        try:pygame.quit()
        finally:
            if cursor:cursor.close()
            for number,handler in previous.items():signal.signal(number,handler)


def show_refusal(display, log, *, title='GRID TOOL UNAVAILABLE', message=None):
    p=display.p
    if message is None:
        message='Another CRT operation may be active.\nDetails are in grid-tool.log.'
    view=Screen(title, message, [Choice('Return to EmulationStation',0)])
    clock=p.time.Clock();armed=time.monotonic()+.3
    while True:
        display.draw(view)
        for event in p.event.get():
            if event.type==p.QUIT:return 1
            if event.type==p.KEYDOWN and time.monotonic()>=armed and event.key in (p.K_RETURN,p.K_ESCAPE,p.K_q):return 1
        clock.tick(40)


if __name__=='__main__':raise SystemExit(main())
