#!/usr/bin/env python3
"""Visual EmulationStation CRT geometry editor for Batocera-CRT-Script.

Visual UI concept based on Sirmagb's EScentred tool and adapted with permission.

Important design rule:
    This program is a frontend for the CRT Script's EXISTING geometry backend.
    It reads the base CRT mode from batocera.conf and reads/writes ONLY the four
    relative values in /userdata/system/es.arg.override.  It never writes
    es.customsargs or any other value to batocera.conf.

The v43/v44 ZFEbHVUE MultiScreen EmulationStation standalone wrappers remain the
runtime authority for final geometry, including the 90/270-degree X/Y swap and
the existing SDL/ES restart workaround.  The Python tool observes enough of
that runtime state to preview the result, but it does not manage outputs or
replace the standalone backend.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from typing import Dict, Optional, Tuple

BATOCERA_CONF = Path("/userdata/system/batocera.conf")
BOOT_CONF = Path("/boot/batocera-boot.conf")
ES_ARG_OVERRIDE = Path("/userdata/system/es.arg.override")
LOG_FILE = Path("/userdata/system/logs/es_tool.log")

KEY_ORDER = (
    "screensizeoffset_x",
    "screensizeoffset_y",
    "screenoffset_x",
    "screenoffset_y",
)

DEFAULT_CONFIG: Dict[str, int] = {
    "screenoffset_x": 0,
    "screenoffset_y": 0,
    "screensizeoffset_x": 0,
    "screensizeoffset_y": 0,
}

LIMIT_MIN = -99
LIMIT_MAX = 99


@dataclass
class RuntimeState:
    base_width: int
    base_height: int
    base_source: str
    base_raw: str
    config: Dict[str, int]
    output: str
    output_source: str
    rotation: str
    rotation_source: str


def log_message(message: str) -> None:
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as handle:
            handle.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")
    except Exception:
        pass


def run_command(args: list[str]) -> str:
    try:
        completed = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=3,
            check=False,
        )
        if completed.returncode == 0:
            return completed.stdout.strip()
    except Exception as exc:
        log_message(f"Command failed ({' '.join(args)}): {exc}")
    return ""


def parse_mode_dimensions(mode: str) -> Optional[Tuple[int, int]]:
    """Parse the leading WIDTHxHEIGHT from Batocera mode IDs.

    Examples:
      769x576.50.00     -> (769, 576)
      641x480.60.00059  -> (641, 480)
    """
    match = re.match(r"^\s*(\d+)x(\d+)(?:\.|\s|$)", mode or "")
    if not match:
        return None
    width = int(match.group(1))
    height = int(match.group(2))
    if width <= 0 or height <= 0:
        return None
    return width, height


def read_assignment(path: Path, key: str) -> str:
    """Read the last active key=value assignment from a Batocera config file."""
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""

    value = ""
    pattern = re.compile(rf"^\s*{re.escape(key)}\s*=\s*([^#\s]+)")
    for line in lines:
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        match = pattern.match(line)
        if match:
            value = match.group(1).strip()
    return value


def standalone_even_width_nudge(width: int) -> int:
    """Mirror the v43/v44 wrapper rule used only for boot-config fallback."""
    if (width % 10) % 2 == 0:
        return width + 1
    return width


def determine_base_mode() -> Tuple[int, int, str, str]:
    """Return (width, height, source, raw_mode).

    Primary source is global.videomode as requested.  crt-launcher.sh syncs that
    value to batocera-resolution currentMode before launching CRT utilities.
    """
    raw = read_assignment(BATOCERA_CONF, "global.videomode")
    dimensions = parse_mode_dimensions(raw)
    if dimensions:
        return dimensions[0], dimensions[1], "batocera.conf:global.videomode", raw

    raw = run_command(["batocera-resolution", "currentMode"])
    dimensions = parse_mode_dimensions(raw)
    if dimensions:
        return dimensions[0], dimensions[1], "batocera-resolution currentMode", raw

    raw = read_assignment(BOOT_CONF, "es.resolution")
    dimensions = parse_mode_dimensions(raw)
    if dimensions:
        # Unlike global.videomode/currentMode, es.resolution is the input to the
        # standalone wrapper, so mirror its existing odd-width conversion here.
        width = standalone_even_width_nudge(dimensions[0])
        return width, dimensions[1], "batocera-boot.conf:es.resolution (+ wrapper width rule)", raw

    raise RuntimeError(
        "Could not determine the CRT base resolution from global.videomode, "
        "batocera-resolution currentMode, or es.resolution."
    )


def parse_override_value(raw: str) -> Optional[int]:
    """Accept current canonical values and older forms such as -9 or +09."""
    raw = (raw or "").strip()
    if not re.fullmatch(r"[+-]?\d{1,2}", raw):
        return None
    try:
        value = int(raw, 10)
    except ValueError:
        return None
    if value < LIMIT_MIN or value > LIMIT_MAX:
        return None
    return value


def format_override_value(value: int) -> str:
    """Format exactly as the v43/v44 wrappers accept: 00..99 or -01..-99."""
    value = max(LIMIT_MIN, min(LIMIT_MAX, int(value)))
    if value < 0:
        return f"-{abs(value):02d}"
    return f"{value:02d}"


def display_value(value: int) -> str:
    if value < 0:
        return f"-{abs(value):02d}"
    return f"+{value:02d}"


def read_override_config(path: Path = ES_ARG_OVERRIDE) -> Dict[str, int]:
    config = DEFAULT_CONFIG.copy()
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return config

    for line in lines:
        parts = line.split()
        if len(parts) < 2 or parts[0] not in config:
            continue
        parsed = parse_override_value(parts[1])
        if parsed is None:
            log_message(f"Invalid {parts[0]} value '{parts[1]}' in {path}; previewing as 0.")
            parsed = 0
        config[parts[0]] = parsed
    return config


def save_override_config(config: Dict[str, int], path: Path = ES_ARG_OVERRIDE) -> None:
    """Atomically update the four known keys while preserving unrelated lines."""
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        original_lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        original_lines = []

    seen = set()
    output_lines = []
    for line in original_lines:
        parts = line.split()
        if parts and parts[0] in config:
            key = parts[0]
            output_lines.append(f"{key} {format_override_value(config[key])}")
            seen.add(key)
        else:
            output_lines.append(line)

    for key in KEY_ORDER:
        if key not in seen:
            output_lines.append(f"{key} {format_override_value(config[key])}")

    payload = "\n".join(output_lines).rstrip("\n") + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_name, 0o644)
        os.replace(temp_name, path)
        try:
            dir_fd = os.open(path.parent, os.O_DIRECTORY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError:
            pass
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise

    log_message(
        "Saved es.arg.override: "
        + ", ".join(f"{key}={format_override_value(config[key])}" for key in KEY_ORDER)
    )


def read_runtime_lines(path: Path) -> list[str]:
    try:
        return [line.strip() for line in path.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]
    except OSError:
        return []


def detect_batocera_major() -> Optional[int]:
    raw = run_command(["/usr/bin/batocera-es-swissknife", "--version"])
    match = re.search(r"(?:^|\s)(\d{2})(?:[^0-9]|$)", raw)
    if not match:
        return None
    try:
        return int(match.group(1))
    except ValueError:
        return None


def list_connected_outputs() -> list[str]:
    """Return listOutputs when the display backend is available.

    Over SSH without DISPLAY, Batocera v43/Xorg prints "Can't open display".
    In that case return an empty list rather than treating configured outputs as
    invalid. The visual tool itself is launched with DISPLAY set by es_tool.sh.
    """
    raw = run_command(["batocera-resolution", "listOutputs"])
    return [line.strip() for line in raw.splitlines() if line.strip()]


def determine_v44_docked_output(outputs: list[str]) -> str:
    """Mirror the v44 wrapper's mixed handheld/external docked selection."""
    if not outputs:
        return ""
    handheld_last = ""
    external_last = ""
    for output in outputs:
        is_handheld = run_command(
            ["/usr/bin/batocera-settings-get-master", f"display.handheld.{output}"]
        )
        if is_handheld.strip() == "1":
            handheld_last = output
        else:
            external_last = output
    if handheld_last and external_last:
        return external_last
    return ""


def determine_current_output() -> Tuple[str, str]:
    """Determine the effective primary output without changing display state.

    This follows the *selection* semantics of the custom v43/v44 MultiScreen
    wrappers closely, but intentionally does NOT call
    `batocera-switch-screen-checker --init` or `setOutput`: the calibration UI
    must observe state, not become a second display-management backend.

    If `batocera-resolution listOutputs` cannot run (for example over SSH with
    no DISPLAY), a configured/runtime output is trusted rather than discarded.
    """
    major = detect_batocera_major()
    connected = list_connected_outputs()

    # v43 docked handling: the wrapper ultimately overrides settings_output
    # with the output stored in /var/run/batocera-docked.
    if major == 43:
        docked = read_runtime_lines(Path("/var/run/batocera-docked"))
        if docked:
            candidate = docked[0]
            if not connected or candidate in connected:
                return candidate, "v43:/var/run/batocera-docked"

    # v44 docked handling: if both handheld and external outputs exist, the
    # wrapper selects the last external output. This requires listOutputs, so it
    # is evaluated only when that display-backed query is available.
    if major is not None and major >= 44:
        docked = determine_v44_docked_output(connected)
        if docked:
            return docked, "v44:mixed handheld/external output"

    # The wrappers query master output1/2/3 first and only fall back to regular
    # settings if *all three* master values are empty. Preserve that behavior.
    master = [
        run_command(["/usr/bin/batocera-settings-get-master", key])
        for key in ("global.videooutput", "global.videooutput2", "global.videooutput3")
    ]
    if any(master):
        candidate = master[0].strip()
        source = "batocera-settings-get-master:global.videooutput"
    else:
        regular = [
            run_command(["/usr/bin/batocera-settings-get", key])
            for key in ("global.videooutput", "global.videooutput2", "global.videooutput3")
        ]
        if any(regular):
            candidate = regular[0].strip()
            source = "batocera-settings-get:global.videooutput"
        else:
            status = read_runtime_lines(Path("/var/run/batocera-switch-screen-checker-status"))
            candidate = status[0] if status else ""
            source = "/var/run/batocera-switch-screen-checker-status" if candidate else ""

    if candidate:
        if not connected or candidate in connected:
            return candidate, source
        candidate = ""

    last_primary = read_runtime_lines(Path("/var/run/switch_screen_current"))
    if last_primary:
        candidate = last_primary[0]
        if not connected or candidate in connected:
            return candidate, "/var/run/switch_screen_current"

    candidate = run_command(["batocera-resolution", "currentOutput"]).strip()
    if candidate:
        if not connected or candidate in connected:
            return candidate, "batocera-resolution currentOutput"

    if connected:
        return connected[0], "batocera-resolution listOutputs:first"

    return "", "unresolved"


def determine_rotation(output: str) -> Tuple[str, str]:
    value = ""
    if output:
        value = run_command(["/usr/bin/batocera-settings-get-master", f"display.rotate.{output}"])
        if value.strip() in {"0", "1", "2", "3"}:
            return value.strip(), f"batocera-settings-get-master:display.rotate.{output}"
    value = run_command(["/usr/bin/batocera-settings-get-master", "display.rotate"])
    if value.strip() in {"0", "1", "2", "3"}:
        return value.strip(), "batocera-settings-get-master:display.rotate"
    return "0", "default:0"


def calculate_effective_geometry(
    base_width: int,
    base_height: int,
    config: Dict[str, int],
    rotation: str,
) -> Tuple[int, int, int, int]:
    """Mirror the geometry portion of v43/v44 crt_apply_primary_resolution()."""
    size_x = base_width + config["screensizeoffset_x"]
    size_y = base_height + config["screensizeoffset_y"]
    offset_x = config["screenoffset_x"]
    offset_y = config["screenoffset_y"]

    if rotation in {"1", "3"}:
        return size_y, size_x, offset_y, offset_x
    return size_x, size_y, offset_x, offset_y


def effective_base_dimensions(base_width: int, base_height: int, rotation: str) -> Tuple[int, int]:
    if rotation in {"1", "3"}:
        return base_height, base_width
    return base_width, base_height


def collect_runtime_state() -> RuntimeState:
    """Collect the state used by both --dump-state and the graphical UI.

    Keeping this in one path prevents the diagnostic and GUI from interpreting
    output/rotation state differently.
    """
    base_w, base_h, source, raw_mode = determine_base_mode()
    config = read_override_config()
    output, output_source = determine_current_output()
    rotation, rotation_source = determine_rotation(output)
    return RuntimeState(
        base_width=base_w,
        base_height=base_h,
        base_source=source,
        base_raw=raw_mode,
        config=config,
        output=output,
        output_source=output_source,
        rotation=rotation,
        rotation_source=rotation_source,
    )


def dump_state() -> int:
    try:
        state = collect_runtime_state()
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 1

    eff_w, eff_h, eff_x, eff_y = calculate_effective_geometry(
        state.base_width, state.base_height, state.config, state.rotation
    )

    print(f"base_mode={state.base_width}x{state.base_height}")
    print(f"base_source={state.base_source}")
    print(f"base_raw={state.base_raw}")
    print(f"output={state.output or '(unknown)'}")
    print(f"output_source={state.output_source}")
    print(f"rotation={state.rotation}")
    print(f"rotation_source={state.rotation_source}")
    for key in KEY_ORDER:
        print(f"{key}={format_override_value(state.config[key])}")
    print(f"effective_screensize={eff_w}x{eff_h}")
    print(f"effective_screenoffset={format_override_value(eff_x)},{format_override_value(eff_y)}")
    return 0


def self_test() -> int:
    assert parse_mode_dimensions("769x576.50.00") == (769, 576)
    assert parse_mode_dimensions("641x480.60.00059") == (641, 480)
    assert parse_mode_dimensions("default") is None
    assert standalone_even_width_nudge(768) == 769
    assert standalone_even_width_nudge(769) == 769
    assert parse_override_value("-9") == -9
    assert parse_override_value("-09") == -9
    assert parse_override_value("+09") == 9
    assert parse_override_value("100") is None
    assert format_override_value(-9) == "-09"
    assert format_override_value(0) == "00"
    assert format_override_value(9) == "09"
    assert display_value(-2) == "-02"
    assert display_value(0) == "+00"
    cfg = {
        "screenoffset_x": 8,
        "screenoffset_y": 10,
        "screensizeoffset_x": -10,
        "screensizeoffset_y": -20,
    }
    assert calculate_effective_geometry(769, 576, cfg, "0") == (759, 556, 8, 10)
    assert calculate_effective_geometry(769, 576, cfg, "1") == (556, 759, 10, 8)

    with tempfile.TemporaryDirectory() as directory:
        test_file = Path(directory) / "es.arg.override"
        test_file.write_text(
            "# preserved comment\n"
            "screensizeoffset_x -9\n"
            "unknown_setting keepme\n"
            "screenoffset_y +08\n",
            encoding="utf-8",
        )
        loaded = read_override_config(test_file)
        assert loaded["screensizeoffset_x"] == -9
        assert loaded["screenoffset_y"] == 8
        save_override_config(loaded, test_file)
        saved = test_file.read_text(encoding="utf-8")
        assert "screensizeoffset_x -09" in saved
        assert "screenoffset_y 08" in saved
        assert "unknown_setting keepme" in saved
        assert "screenoffset_x 00" in saved
        assert "screensizeoffset_y 00" in saved

    print("es_tool.py self-test: PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Batocera CRT Script visual ES geometry editor")
    parser.add_argument("--window", action="store_true", help="run in a window (development/debugging)")
    parser.add_argument("--dump-state", action="store_true", help="print detected geometry state and exit")
    parser.add_argument("--self-test", action="store_true", help="run non-Pygame helper tests and exit")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.dump_state:
        return dump_state()

    try:
        import pygame  # type: ignore
    except ImportError as exc:
        log_message(f"pygame import failed: {exc}")
        print(f"pygame is required for the visual UI: {exc}", file=sys.stderr)
        return 2

    try:
        state = collect_runtime_state()
    except RuntimeError as exc:
        log_message(str(exc))
        print(str(exc), file=sys.stderr)
        return 3

    base_w = state.base_width
    base_h = state.base_height
    base_source = state.base_source
    raw_mode = state.base_raw
    config = state.config.copy()
    original_config = config.copy()
    output = state.output
    output_source = state.output_source
    rotation = state.rotation
    rotation_source = state.rotation_source

    log_message(
        f"Visual tool start: base={base_w}x{base_h} raw='{raw_mode}' source='{base_source}' "
        f"output='{output}' output_source='{output_source}' rotation={rotation} "
        f"rotation_source='{rotation_source}'"
    )

    pygame.init()
    pygame.joystick.init()
    pygame.key.set_repeat(260, 65)

    joysticks = []
    for index in range(pygame.joystick.get_count()):
        try:
            joystick = pygame.joystick.Joystick(index)
            joystick.init()
            joysticks.append(joystick)
        except Exception as exc:
            log_message(f"Could not initialize joystick {index}: {exc}")

    info = pygame.display.Info()
    effective_base_w, effective_base_h = effective_base_dimensions(base_w, base_h, rotation)

    if args.window:
        screen_w = max(640, min(960, effective_base_w))
        screen_h = max(480, min(720, effective_base_h))
        flags = 0
    else:
        screen_w = info.current_w if info.current_w > 0 else effective_base_w
        screen_h = info.current_h if info.current_h > 0 else effective_base_h
        flags = pygame.FULLSCREEN

    screen = pygame.display.set_mode((screen_w, screen_h), flags)
    pygame.display.set_caption("Batocera CRT Script - ES Centering & Scaling")
    pygame.mouse.set_visible(False)
    clock = pygame.time.Clock()

    # Sirmagb-inspired monochrome CRT palette.
    color_bg = (5, 15, 5)
    color_green = (0, 255, 102)
    color_dim_green = (0, 110, 45)
    color_dark_green = (0, 45, 18)
    color_warn = (255, 180, 0)
    color_yellow = (255, 230, 0)
    color_black = (0, 0, 0)

    ui_scale = max(0.72, min(1.35, screen_h / 576.0))
    font_main = pygame.font.SysFont("monospace", max(13, int(17 * ui_scale)), bold=True)
    font_title = pygame.font.SysFont("monospace", max(15, int(20 * ui_scale)), bold=True)
    font_small = pygame.font.SysFont("monospace", max(11, int(13 * ui_scale)), bold=True)

    options = [
        ("Horizontal Position", "screenoffset_x"),
        ("Vertical Position", "screenoffset_y"),
        ("Horizontal Size", "screensizeoffset_x"),
        ("Vertical Size", "screensizeoffset_y"),
    ]
    selected = 0
    status_message = ""
    status_until = 0.0
    show_saved = False
    saved_at = 0.0
    running = True

    def adjust_selected(delta: int) -> None:
        nonlocal status_message, status_until
        key = options[selected][1]
        old_value = config[key]
        new_value = max(LIMIT_MIN, min(LIMIT_MAX, old_value + delta))
        config[key] = new_value
        if new_value == old_value and delta:
            status_message = f"Limit reached: {LIMIT_MIN} .. +{LIMIT_MAX}"
            status_until = time.monotonic() + 1.5

    while running:
        screen.fill(color_bg)

        eff_w, eff_h, eff_x, eff_y = calculate_effective_geometry(base_w, base_h, config, rotation)
        virtual_w, virtual_h = effective_base_dimensions(base_w, base_h, rotation)
        scale_x = screen_w / float(max(1, virtual_w))
        scale_y = screen_h / float(max(1, virtual_h))

        # Physical/current-mode frame.
        pygame.draw.rect(screen, color_dim_green, (0, 0, screen_w - 1, screen_h - 1), max(1, int(2 * ui_scale)))

        # Preview the exact effective --screensize/--screenoffset semantics used by
        # the v43/v44 standalone wrapper. Pygame clipping naturally shows portions
        # that would lie beyond the visible CRT area.
        preview_rect = pygame.Rect(
            int(round(eff_x * scale_x)),
            int(round(eff_y * scale_y)),
            max(1, int(round(eff_w * scale_x))),
            max(1, int(round(eff_h * scale_y))),
        )
        pygame.draw.rect(screen, color_yellow, preview_rect, max(2, int(3 * ui_scale)))

        # Calibration helpers inside the effective ES area.
        if preview_rect.width > 20 and preview_rect.height > 20:
            cx, cy = preview_rect.center
            pygame.draw.line(screen, color_dim_green, (preview_rect.left, cy), (preview_rect.right, cy), 1)
            pygame.draw.line(screen, color_dim_green, (cx, preview_rect.top), (cx, preview_rect.bottom), 1)
            inset = max(8, int(min(preview_rect.width, preview_rect.height) * 0.035))
            inner = preview_rect.inflate(-2 * inset, -2 * inset)
            if inner.width > 4 and inner.height > 4:
                pygame.draw.rect(screen, color_dim_green, inner, 1)

        panel_w = min(screen_w - 24, max(520, int(610 * ui_scale)))
        panel_h = min(screen_h - 24, max(300, int(390 * ui_scale)))
        panel = pygame.Rect((screen_w - panel_w) // 2, (screen_h - panel_h) // 2, panel_w, panel_h)
        pygame.draw.rect(screen, color_black, panel)
        pygame.draw.rect(screen, color_green, panel, max(1, int(2 * ui_scale)))

        title = font_title.render("EMULATIONSTATION CENTERING & SCALING", True, color_green)
        screen.blit(title, title.get_rect(center=(screen_w // 2, panel.top + int(34 * ui_scale))))

        base_line = f"Base: {base_w} x {base_h}   Output: {output or '?'}   Rotation: {rotation}"
        base_surface = font_small.render(base_line, True, color_dim_green)
        screen.blit(base_surface, base_surface.get_rect(center=(screen_w // 2, panel.top + int(62 * ui_scale))))

        result_line = f"Effective ES: {eff_w} x {eff_h}   Offset: {display_value(eff_x)}, {display_value(eff_y)}"
        result_surface = font_small.render(result_line, True, color_yellow)
        screen.blit(result_surface, result_surface.get_rect(center=(screen_w // 2, panel.top + int(83 * ui_scale))))

        start_y = panel.top + int(112 * ui_scale)
        row_gap = int(45 * ui_scale)
        row_left = panel.left + int(35 * ui_scale)
        row_width = panel.width - int(70 * ui_scale)
        row_height = max(29, int(34 * ui_scale))

        for index, (label, key) in enumerate(options):
            y = start_y + index * row_gap
            if index == selected:
                pygame.draw.rect(screen, color_dark_green, (row_left, y, row_width, row_height), border_radius=4)
                text_color = color_green
                prefix = ">"
            else:
                text_color = color_dim_green
                prefix = " "
            line = f"{prefix} {label:<22} [{display_value(config[key])}]"
            surface = font_main.render(line, True, text_color)
            screen.blit(surface, (row_left + int(12 * ui_scale), y + int(5 * ui_scale)))

        legend_y = panel.bottom - int(62 * ui_scale)
        legend1 = font_small.render("LEFT/RIGHT: adjust 1    PAGE UP/DOWN: adjust 10", True, color_dim_green)
        screen.blit(legend1, legend1.get_rect(center=(screen_w // 2, legend_y)))
        legend2 = font_small.render("[A/ENTER] SAVE   [X/R] RESET   [B/ESC] CANCEL", True, color_dim_green)
        screen.blit(legend2, legend2.get_rect(center=(screen_w // 2, legend_y + int(22 * ui_scale))))

        if status_message and time.monotonic() < status_until:
            status = font_small.render(status_message, True, color_warn)
            screen.blit(status, status.get_rect(center=(screen_w // 2, panel.bottom - int(12 * ui_scale))))

        if show_saved:
            box_w = min(screen_w - 30, max(520, int(620 * ui_scale)))
            box_h = min(screen_h - 30, max(220, int(270 * ui_scale)))
            box = pygame.Rect((screen_w - box_w) // 2, (screen_h - box_h) // 2, box_w, box_h)
            pygame.draw.rect(screen, color_dark_green, box)
            pygame.draw.rect(screen, color_green, box, max(2, int(3 * ui_scale)))
            msg1 = font_title.render("SETTINGS SAVED SUCCESSFULLY", True, color_green)
            screen.blit(msg1, msg1.get_rect(center=(screen_w // 2, box.top + int(48 * ui_scale))))
            msg2 = font_main.render(
                f"ES: {eff_w} x {eff_h}  Offset: {display_value(eff_x)}, {display_value(eff_y)}",
                True,
                color_green,
            )
            screen.blit(msg2, msg2.get_rect(center=(screen_w // 2, box.top + int(96 * ui_scale))))
            msg3 = font_small.render("Back in EmulationStation: RIGHTALT (AltGr) + F2 to apply.", True, color_warn)
            screen.blit(msg3, msg3.get_rect(center=(screen_w // 2, box.top + int(146 * ui_scale))))
            msg4 = font_small.render("Press A / ENTER / ESC to continue", True, color_green)
            screen.blit(msg4, msg4.get_rect(center=(screen_w // 2, box.top + int(184 * ui_scale))))

        pygame.display.flip()
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
                continue

            if event.type == pygame.KEYDOWN:
                if show_saved:
                    if time.monotonic() - saved_at > 0.25 and event.key in (pygame.K_RETURN, pygame.K_ESCAPE, pygame.K_SPACE):
                        running = False
                    continue

                if event.key == pygame.K_UP:
                    selected = (selected - 1) % len(options)
                elif event.key == pygame.K_DOWN:
                    selected = (selected + 1) % len(options)
                elif event.key == pygame.K_LEFT:
                    adjust_selected(-1)
                elif event.key == pygame.K_RIGHT:
                    adjust_selected(1)
                elif event.key == pygame.K_PAGEUP:
                    adjust_selected(10)
                elif event.key == pygame.K_PAGEDOWN:
                    adjust_selected(-10)
                elif event.key in (pygame.K_r, pygame.K_x):
                    config = DEFAULT_CONFIG.copy()
                    status_message = "Reset to defaults (not saved yet)"
                    status_until = time.monotonic() + 2.0
                elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                    try:
                        save_override_config(config)
                        show_saved = True
                        saved_at = time.monotonic()
                    except Exception as exc:
                        log_message(f"Save failed: {exc}")
                        status_message = f"SAVE FAILED: {exc}"
                        status_until = time.monotonic() + 4.0
                elif event.key == pygame.K_ESCAPE:
                    config = original_config
                    running = False

            elif event.type == pygame.JOYHATMOTION and not show_saved:
                hat_x, hat_y = event.value
                if hat_y > 0:
                    selected = (selected - 1) % len(options)
                elif hat_y < 0:
                    selected = (selected + 1) % len(options)
                if hat_x < 0:
                    adjust_selected(-1)
                elif hat_x > 0:
                    adjust_selected(1)

            elif event.type == pygame.JOYBUTTONDOWN:
                if show_saved:
                    if time.monotonic() - saved_at > 0.25:
                        running = False
                    continue
                # SDL's common A/B/X ordering. The .keys file also maps these to
                # Enter/Escape/R, so controller support does not depend on raw
                # joystick delivery reaching pygame.
                if event.button == 0:  # A
                    try:
                        save_override_config(config)
                        show_saved = True
                        saved_at = time.monotonic()
                    except Exception as exc:
                        log_message(f"Save failed: {exc}")
                        status_message = f"SAVE FAILED: {exc}"
                        status_until = time.monotonic() + 4.0
                elif event.button == 1:  # B
                    config = original_config
                    running = False
                elif event.button == 2:  # X
                    config = DEFAULT_CONFIG.copy()
                    status_message = "Reset to defaults (not saved yet)"
                    status_until = time.monotonic() + 2.0

    pygame.mouse.set_visible(True)
    pygame.quit()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
