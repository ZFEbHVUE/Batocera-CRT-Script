
#!/usr/bin/env python

import argparse
import subprocess
import sys
import time
import os
import logging
import platform
import re
import threading


CTR_modifier = 1<<7
STAGED_SWITCHRES_INI = '/tmp/geometry-calibrate-live.ini'


def split_switchres_command(command: str):
	"""Return binary path, source ini, and any extra switchres CLI tokens."""
	parts = command.split()
	ini_path = '/etc/switchres.ini'
	extra = []
	index = 1
	while index < len(parts):
		if parts[index] == '-i' and index + 1 < len(parts):
			ini_path = parts[index + 1]
			index += 2
		else:
			extra.append(parts[index])
			index += 1
	return parts[0], ini_path, extra


def build_switchres_command(binary: str, ini_path: str, extra: list[str]) -> str:
	tokens = [binary, *extra, '-i', ini_path]
	return ' '.join(tokens)


def write_staged_switchres_ini(source_path: str, geom: geometry, dest_path: str) -> None:
	"""Mirror live h_size/h_shift/v_shift into a temp ini so Switchres honors D-pad steps."""
	with open(source_path, 'r', encoding='utf-8', errors='replace') as stream:
		lines = stream.read().splitlines()
	output = []
	seen = dict(h_size=False, h_shift=False, v_shift=False)
	for line in lines:
		if re.match(r'^\s*h_size\s+', line):
			output.append(f'\th_size                    {geom.h_size}')
			seen['h_size'] = True
		elif re.match(r'^\s*h_shift\s+', line):
			output.append(f'\th_shift                   {geom.h_shift}')
			seen['h_shift'] = True
		elif re.match(r'^\s*v_shift\s+', line):
			output.append(f'\tv_shift                   {geom.v_shift}')
			seen['v_shift'] = True
		else:
			output.append(line)
	for key, value in (('h_size', geom.h_size), ('h_shift', geom.h_shift), ('v_shift', geom.v_shift)):
		if not seen[key]:
			output.append(f'\t{key}                    {value}')
	with open(dest_path, 'w', encoding='utf-8') as stream:
		stream.write('\n'.join(output) + '\n')


class mode:
	def __init__(self, w:int = 640, h:int = 480, rr:float = 60):
		self.width = int(w)
		self.height = int(h)
		self.refresh_rate = float(rr)

	def __str__(self):
		return "{}x{}@{}".format(self.width, self.height, self.refresh_rate)

	def __repr__(self):
		return "Mode: {}".format(str(self))


class geometry:
	def __init__(self, h_size:float = 1.0, h_shift:int = 0, v_shift:int = 0):
		self.h_size = float(h_size)
		self.h_shift = int(h_shift)
		self.v_shift = int(v_shift)

	def __str__(self):
		return "{}:{}:{}".format(self.h_size, self.h_shift, self.v_shift)

	def __eq__(self, other):
		return self.h_size == other.h_size and self.h_shift == other.h_shift and self.v_shift == other.v_shift

	def set_geometry(self, h_size:float, h_shift:int, v_shift:int):
		self.h_size = float(h_size)
		self.h_shift = int(h_shift)
		self.v_shift = int(v_shift)

	@classmethod
	def set_from_string(cls, geom:str):
		"""
		geom should be in the form of 1.0:-5:2
		"""
		hsize, hshift, vshift = geom.split(':')
		return cls(hsize, hshift, vshift)

	def inc_hsize(self, step = 0.01, factor:int = 1): self.h_size += step * factor
	def inc_hshift(self, step = 1, factor:int = 1): self.h_shift += step * factor
	def inc_vshift(self, step = 1, factor:int = 1): self.v_shift += step * factor
	def dec_hsize(self, step = 0.01, factor:int = 1): self.h_size -= step * factor
	def dec_hshift(self, step = 1, factor:int = 1): self.h_shift -= step * factor
	def dec_vshift(self, step = 1, factor:int = 1): self.v_shift -= step * factor


class crt_range:
	def __init__(self, HfreqMin:float = 0.0, HfreqMax:float = 0.0, VfreqMin:float = 0.0, VfreqMax:float = 0.0, HFrontPorch:float = 0.0, HSyncPulse:float = 0.0, HBackPorch:float = 0.0, VFrontPorch:float = 0.0, VSyncPulse:float = 0.0, VBackPorch:float = 0.0, HSyncPol:int = 0, VSyncPol:int = 0, ProgressiveLinesMin:int = 0, ProgressiveLinesMax:int = 0, InterlacedLinesMin:int = 0, InterlacedLinesMax:int = 0):
		self.HfreqMin = float(HfreqMin)
		self.HfreqMax = float(HfreqMax)
		self.VfreqMin = float(VfreqMin)
		self.VfreqMax = float(VfreqMax)
		self.HFrontPorch = float(HFrontPorch)
		self.HSyncPulse = float(HSyncPulse)
		self.HBackPorch = float(HBackPorch)
		self.VFrontPorch = float(VFrontPorch)
		self.VSyncPulse = float(VSyncPulse)
		self.VBackPorch = float(VBackPorch)
		self.HSyncPol = int(HSyncPol)
		self.VSyncPol = int(VSyncPol)
		self.ProgressiveLinesMin = int(ProgressiveLinesMin)
		self.ProgressiveLinesMax = int(ProgressiveLinesMax)
		self.InterlacedLinesMin = int(InterlacedLinesMin)
		self.InterlacedLinesMax = int(InterlacedLinesMax)

	@classmethod
	def set_from_string(cls, range:str):
		"""
		range is in the form of 15625.00-16200.00,49.50-65.00,2.000,4.700,8.000,0.064,0.192,1.024,0,0,192,288,448,576
		"""
		HfreqRange, VfregRange, HFrontPorch, HSyncPulse, HBackPorch, VFrontPorch, VSyncPulse, VBackPorch, HSyncPol, VSyncPol, ProgressiveLinesMin, ProgressiveLinesMax, InterlacedLinesMin, InterlacedLinesMax = range.split(',')
		HfreqMin, HfreqMax = HfreqRange.split('-')
		VfreqMin, VfreqMax = VfregRange.split('-')
		return cls(HfreqMin, HfreqMax, VfreqMin, VfreqMax, HFrontPorch, HSyncPulse, HBackPorch, VFrontPorch, VSyncPulse, VBackPorch, HSyncPol, VSyncPol, ProgressiveLinesMin, ProgressiveLinesMax, InterlacedLinesMin, InterlacedLinesMax)

	def new_geometry_from_string(self, adjusted_geometry: str):
		"""
		range is in the shape of the switchres output: "H: 2.004, 4.696, 8.015 V: 0.447, 0.383, 2.425"
		"""
		#hfp, self.HSyncPulse, self.HBackPorch, vfp, self.VSyncPulse, self.VBackPorch = adjusted_geometry.split(', ')
		hfp, self.HSyncPulse, hbp_and_vfp, self.VSyncPulse, self.VBackPorch = adjusted_geometry.split(', ')
		self.HFrontPorch = hfp[3:]
		self.HBackPorch, _, self.VFrontPorch = hbp_and_vfp.split(' ')

	def __str__(self):
		return "{}-{},{}-{},{},{},{},{},{},{},{},{},{},{},{},{}".format(
			self.HfreqMin, self.HfreqMax, self.VfreqMin, self.VfreqMax, self.HFrontPorch, self.HSyncPulse, self.HBackPorch, self.VFrontPorch, self.VSyncPulse, self.VBackPorch, self.HSyncPol, self.VSyncPol, self.ProgressiveLinesMin, self.ProgressiveLinesMax, self.InterlacedLinesMin, self.InterlacedLinesMax)


def switchres_output_get_monitor_range(output:str):
	for l in output.splitlines():
		# The line to parse looks like:
		# Switchres: Monitor range 15625.00-16200.00,49.50-65.00,2.000,4.700,8.000,0.064,0.192,1.024,0,0,192,288,448,576
		if l[0:25] != "Switchres: Monitor range " : continue
		logging.debug("Found! -> {}".format(l[25:]))
		logging.debug(crt_range().set_from_string(l[25:]))
		return crt_range().set_from_string(l[25:])
	logging.warning("Couldn't find the monitor range!")
	return None

def switchres_output_get_adjusted_crt_geometry(output:str):
	for l in output.splitlines():
		# The line to parse looks like:
		# Adjusted geometry (1.000:0:0) H: 2.004, 4.696, 8.015 V: 0.223, 0.191, 1.212
		# We need what is behind H:
		if l[0:19] != "Adjusted geometry (" : continue
		Hpos = l.find('H: ')
		logging.debug("Found! -> {}".format(l[Hpos:]))
		return l[Hpos:]
	logging.warning("Couldn't find the adjusted crt geometry!")
	return None

def switchres_output_get_adjusted_geometry(output:str):
	for l in output.splitlines():
		# The line to parse looks like:
		# Adjusted geometry (1.000:0:0) H: 2.004, 4.696, 8.015 V: 0.223, 0.191, 1.212
		# We need what is between parenthesis
		if l[0:19] != "Adjusted geometry (" : continue
		Hpos = l.find('H: ')

		logging.debug("Found! -> {}".format(l[Hpos:]))
		return l[19:Hpos - 2]
	logging.warning("Couldn't find the adjusted geometry!")
	return None

def switchres_output_get_command_exit_code(output:str):
	for l in output.splitlines():
		# The line to parse looks like:
		# Process exited with value 256
		if l[0:26] != "Process exited with value " : continue
		logging.debug("Found! -> {}".format(l[26:]))
		return int(l[26:])
	logging.warning("Couldn't find the app exit code!")
	return None

def normalize_grid_exit_code(code):
	"""Map Switchres grid exit values to the 0-255 codes readjust_geometry expects."""
	if code is None:
		return None
	if code >= 256 and code % 256 == 0:
		code >>= 8
	return code

def x11_display_env():
	env = os.environ.copy()
	env.setdefault('DISPLAY', ':0')
	if os.path.isfile('/var/lib/.Xauthority'):
		env['XAUTHORITY'] = '/var/lib/.Xauthority'
	return env

_focus_last_window = None

def focus_switchres_grid_once() -> bool:
	global _focus_last_window
	try:
		found = subprocess.run(
			['xdotool', 'search', '--name', 'Switchres test grid'],
			capture_output=True, text=True, env=x11_display_env(), timeout=2, check=False)
		window_ids = [value for value in (found.stdout or '').split() if value.isdigit()]
		if not window_ids:
			return False
		window_id = window_ids[-1]
		env = x11_display_env()
		subprocess.run(['xdotool', 'windowmap', '--sync', window_id], env=env, timeout=2, check=False)
		subprocess.run(['xdotool', 'windowactivate', '--sync', window_id], env=env, timeout=2, check=False)
		subprocess.run(['xdotool', 'windowfocus', window_id], env=env, timeout=1, check=False)
		_focus_last_window = window_id
		return True
	except (OSError, subprocess.SubprocessError):
		return False

def batocera_force_mode() -> str | None:
	"""Current desktop mode for switchres -f (keeps progressive output on the CRT)."""
	try:
		result = subprocess.run(
			['batocera-resolution', 'currentMode'],
			capture_output=True, text=True, env=x11_display_env(), timeout=5, check=False)
		mode = (result.stdout or '').strip()
	except (OSError, subprocess.SubprocessError):
		return None
	if not mode or 'x' not in mode:
		return None
	wh, _, rest = mode.partition('.')
	if not rest:
		return None
	return "{}@{}".format(wh, rest)

def launch_switchres(mode:mode, geom:geometry = geometry(), switchres_command:str = "switchres -i /etc/switchres.ini",
                     launch_command:str = "/usr/bin/grid", display:int = 0, apply_mode:bool = True):
	return_list = dict()

	# The command line may not require launching a program, just to get the crt_range for example
	cmd = [ switchres_command.split(" ")[0], str(mode.width), str(mode.height), str(mode.refresh_rate), '-v' ]
	if switchres_command.split(" ")[1:]:
		cmd.extend(switchres_command.split(" ")[1:])
	if display > 0:
		cmd.extend(['-d', str(display)])
	if launch_command:
		if display > 0:
			launch_command += " {}".format(display)
		# Never pass -f here: it pins the Batocera xrandr mode name and geometry
		# stops moving on the CRT even when staged ini / -g change.
		if apply_mode:
			cmd.extend(['-s'])
		cmd.extend(['-l', launch_command])
	else:
		cmd.extend(['-c'])
	cmd.extend(['-g', str(geom)])
	logging.debug("Calling: {} with text: {}".format(" ".join(cmd), os.getenv('GRID_TEXT')))
	if launch_command:
		proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=x11_display_env())

		def _focus_while_running():
			while proc.poll() is None:
				focus_switchres_grid_once()
				time.sleep(0.45)

		threading.Thread(target=_focus_while_running, daemon=True).start()
		stdout, _ = proc.communicate()
		return_status = subprocess.CompletedProcess(cmd, proc.returncode, stdout, None)
	else:
		return_status = subprocess.run(cmd, capture_output=True, text=True, env=x11_display_env())
	logging.debug(return_status.stdout)

	default_crt_range = switchres_output_get_monitor_range(return_status.stdout)
	adjusted_geometry = switchres_output_get_adjusted_crt_geometry(return_status.stdout)
	user_crt_range = default_crt_range
	grid_return = None

	if launch_command:
		grid_return = normalize_grid_exit_code(
			switchres_output_get_command_exit_code(return_status.stdout))
		user_crt_range.new_geometry_from_string(adjusted_geometry)
	return_list['exit_code'] = grid_return
	return_list['new_crt_range'] = user_crt_range
	return_list['default_crt_range'] = default_crt_range
	return_list['geometry'] = switchres_output_get_adjusted_geometry(return_status.stdout)

	return return_list

def update_switchres_ini(range: crt_range, inifile:str = ''):
	if not inifile:
		sys.exit(0)
	logging.info("Updating {} with crt_range {} (NOT YET IMPLEMENTED)".format(inifile, str(range)))

def readjust_geometry(geom: geometry, range:crt_range, return_code:int):
	wanted_factor = 10 if return_code & CTR_modifier else 1
	factor_message = " with CTRL pressed" if return_code & CTR_modifier else ''
	# Disable the modifier
	return_code = return_code & ~CTR_modifier
	# This syntax requires python >= 3.10
	match return_code:
		# Pressed PAGEUP
		case 68:
			geom.inc_hsize(factor = wanted_factor)
		# Pressed PAGEDOWN
		case 69:
			geom.dec_hsize(factor = wanted_factor)
		# Pressed LEFT
		case 64:
			geom.dec_hshift(factor = wanted_factor)
		# Pressed RIGHT
		case 65:
			geom.inc_hshift(factor = wanted_factor)
		# Pressed DOWN
		case 67:
			geom.inc_vshift(factor = wanted_factor)
		# Pressed UP
		case 66:
			geom.dec_vshift(factor = wanted_factor)
		# Pressed ESCAPE / Q
		case 1:
			logging.info("Aborted!")
			sys.exit(1)
		# Pressed ENTER / RETURN
		case 0:
			logging.info("Finished!")
			logging.info("Final geometry: {}".format(str(geom)))
			logging.info("Final crt_range: {}".format(str(range)))
			#update_switchres_ini(range, switchres_ini)
			sys.exit(0)
		# Pressed DEL / BACKSPACE
		case 2:
			geom = geometry(1.0, 0, 0)
		# Pressed R
		case 3:
			logging.debug("Refreshing with the same geometry values if your screen was scrolling")
	logging.debug("Readjusted geometry: {}".format(str(geom)))
	return geom

def set_grid_text(top_txt:str = '', bottom_txt:str = '', geom:geometry = geometry()):
	help_txt = """H size: {}
H shift: {}
V shift: {}

D-Pad: Up/Down V shift | Left/Right H shift
X Button: H size +  |  Y Button: H size -
L1 / R1 held: step x10
START: validate  |  HOTKEY+START: cancel""".format(geom.h_size, geom.h_shift, geom.v_shift)
	os.environ['GRID_TEXT'] = "\n \n{}".format("\n \n".join(filter(None, [top_txt, help_txt, bottom_txt])))
	logging.debug(os.getenv('GRID_TEXT'))

def switchres_geometry_loop(mode: mode, switchres_command:str = "switchres", launch_command:str = "grid", display_nr:int = 0, geom:geometry = geometry()):
	working_geometry = geom
	top_txt = ''
	switchres_binary, base_ini, switchres_extra = split_switchres_command(switchres_command)
	desktop_mode = batocera_force_mode()
	if desktop_mode:
		logging.info("Batocera desktop mode {}; grid uses switchres -s (not -f)".format(desktop_mode))
	else:
		logging.warning("Could not read currentMode")

	while True:
		# Do not run switchres -c every pass: on this Batocera profile its
		# "Adjusted geometry" line snaps back to the saved triplet and would
		# undo every D-pad step before the grid redraws.
		set_grid_text(top_txt, '', working_geometry)
		# monitor custom keeps h_* / v_* from switchres.ini and ignores -g; stage live values.
		write_staged_switchres_ini(base_ini, working_geometry, STAGED_SWITCHRES_INI)
		live_switchres = build_switchres_command(switchres_binary, STAGED_SWITCHRES_INI, switchres_extra)
		logging.debug("Staged {} for grid launch".format(working_geometry))
		sr_launch_return = launch_switchres(mode, working_geometry, live_switchres, launch_command,
		                                    display_nr, apply_mode=True)
		grid_return_code = sr_launch_return['exit_code']
		logging.info("Grid exit code: {}".format(grid_return_code))
		if grid_return_code is None:
			logging.warning("No grid exit code from switchres; overlay values unchanged this pass")
			continue
		applied = sr_launch_return['geometry']
		if applied:
			sr_geometry = geometry.set_from_string(applied)
			if sr_geometry != working_geometry:
				logging.info(
					"Switchres applied {} (working {} before key)".format(sr_geometry, working_geometry))
		working_geometry = readjust_geometry(working_geometry, sr_launch_return['new_crt_range'], grid_return_code)
		logging.info("Working geometry now {}".format(working_geometry))
		os.environ['GRID_TEXT'] = ""
		top_txt = ''
		time.sleep(0.3)


#
# MAIN
#

# The default switchres.ini file depends on the platform
if platform.system() == 'Linux':
	default_switchres_ini = '/etc/switchres.ini'
else:
	default_switchres_ini = 'switchres.ini'

parser = argparse.ArgumentParser(description='Switchres wrapper to adjust a crt_range for switchres.ini')
parser.add_argument('mode', metavar='N', type=float, nargs=3,
                    help='width height refresh_rate')
parser.add_argument('-l', '--launch', metavar='launch', type=str, default='/usr/bin/grid',
                    help='The program you want to launch')
# parser.add_argument('-i', '--ini', metavar='ini', type=str, default=default_switchres_ini,
                    # help='The switchres.ini file to edit')
parser.add_argument('-s', '--switchres', metavar='binary', type=str, default='switchres -i /etc/switchres.ini',
                    help='The switchres binary to use')
parser.add_argument('-d', '--display', metavar='display', type=int, default=0,
                    help='Set the display to calibrate')
#parser.add_argument('-m', '--monitor', metavar='monitor', type=str, default='arcade_15',
                    # help='The monitor preset base, to override the switchres.ini (NOT YET IMPLEMENTED)')
parser.add_argument('-g', '--geometry', metavar='geometry', type=str, default='1.0:0:0',
                    help='Start with a predefined geometry')
parser.add_argument('-v', '--verbose', action='count', default=0, help='Verbose mode')


if sys.version_info.major < 3:
    raise Exception("Must use Python 3.7 or later")
if sys.version_info.minor < 10:
    raise Exception("Must use Python 3.7 or later")

#args = parser.parse_args(['320', '240', '59.94'])
args = parser.parse_args()

# Set log level according to wanted verbosity
loggingLevel = logging.INFO
logging.basicConfig(stream=sys.stdout, level=loggingLevel, format='%(message)s')
if args.verbose > 0:
	loggingLevel = logging.DEBUG
	logger = logging.getLogger()
	logger.setLevel(loggingLevel)
	for handler in logger.handlers:
		handler.setLevel(loggingLevel)
	for handler in logging.root.handlers[:]:
		logging.root.removeHandler(handler)
	logging.basicConfig(stream=sys.stdout, level=loggingLevel,
		format='[%(levelname)s] %(filename)s/%(funcName)s(%(lineno)d): %(message)s')
logging.debug("Specified logging level: {}".format(args.verbose))
logging.debug("Command line arguments: {}".format(args))

logging.debug(args)

command_mode = mode(args.mode[0], args.mode[1], args.mode[2])
geometry_arg = geometry.set_from_string(args.geometry)

switchres_geometry_loop(command_mode, args.switchres, args.launch, args.display, geometry_arg)
