"""
Telemetry Trajectory Visualizer
Reads CSV telemetry data and renders 3D trajectory + sensor plots.
"""

import sys
import numpy as np
import pandas as pd
from pathlib import Path

from PyQt6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QPushButton,
    QLabel,
    QFileDialog,
    QTabWidget,
    QFrame,
    QSplitter,
    QStatusBar,
    QGroupBox,
    QComboBox,
    QCheckBox,
    QScrollArea,
    QGridLayout,
    QLineEdit,
    QFormLayout,
    QMessageBox,
    QSlider,
    QSizePolicy,
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QTimer
from PyQt6.QtGui import QFont, QColor, QPalette, QFontDatabase

from scipy.signal import medfilt

import matplotlib

matplotlib.use("QtAgg")
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.backends.backend_qtagg import NavigationToolbar2QT as NavigationToolbar
from matplotlib.figure import Figure
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.mplot3d.art3d import Line3DCollection
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec

# ─── Colors
BG = "#ffffff"
BG_PANEL = "#f9f9f9"
BG_WIDGET = "#f0f0f0"
BORDER = "#dddddd"
TEXT_PRI = "#111111"
TEXT_SEC = "#777777"
ACCENT = "#2980b9"  # blue  — primary action / trajectory
ACCENT2 = "#e8761a"  # orange
ACCENT3 = "#27ae60"  # green
WARN = "#c0392b"  # red
TEMP_TOO_HIGH_COLOR = "#c0392b"  # red
TEMP_TOO_LOW_COLOR = "#2980b9"  # blue
TEMP_WIN_RISE_COLOR = "#e67e22"  # orange
TEMP_WIN_FALL_COLOR = "#8e44ad"  # purple

TEMP_ALERT_SPECS = {
    "too_high": {
        "label": "Temp too high",
        "color": TEMP_TOO_HIGH_COLOR,
        "alpha": 0.20,
        "z": 3,
    },
    "too_low": {
        "label": "Temp too low",
        "color": TEMP_TOO_LOW_COLOR,
        "alpha": 0.18,
        "z": 2,
    },
    "win_increase": {
        "label": "Window temp increase",
        "color": TEMP_WIN_RISE_COLOR,
        "alpha": 0.15,
        "z": 1,
    },
    "win_decrease": {
        "label": "Window temp decrease",
        "color": TEMP_WIN_FALL_COLOR,
        "alpha": 0.15,
        "z": 1,
    },
}

MPL_BG = "#ffffff"
MPL_PANEL = "#f9f9f9"


#Matplotlib style
def apply_mpl_style():
    plt.rcParams.update(
        {
            "figure.facecolor": MPL_BG,
            "axes.facecolor": MPL_PANEL,
            "axes.edgecolor": BORDER,
            "axes.labelcolor": TEXT_SEC,
            "axes.titlecolor": TEXT_PRI,
            "text.color": TEXT_PRI,
            "xtick.color": TEXT_SEC,
            "ytick.color": TEXT_SEC,
            "grid.color": BORDER,
            "grid.alpha": 0.8,
            "legend.facecolor": BG_WIDGET,
            "legend.edgecolor": BORDER,
            "legend.labelcolor": TEXT_PRI,
            "lines.linewidth": 1.5,
            "font.family": "sans-serif",
        }
    )


apply_mpl_style()


#Car model
def _rect_loop(pts):
    segs = []
    for i in range(len(pts)):
        segs.append((np.array(pts[i], float), np.array(pts[(i + 1) % len(pts)], float)))
    return segs


def _make_car_vertices():
    segs = []
    chassis_z = 0.00
    sill_z = 0.30
    hood_z = 0.32
    roof_z = 0.75
    wheel_r = 0.22
    x_front = 1.00
    x_hood_end = 0.38
    x_roof_f = 0.30
    x_roof_r = -0.30
    x_trunk_st = -0.38
    x_rear = -1.00
    y_body = 0.45
    y_cabin = 0.40

    for y in [y_body, -y_body]:
        segs.append(([x_rear, y, chassis_z], [x_front, y, chassis_z]))
    segs += _rect_loop(
        [
            [x_front, y_body, chassis_z],
            [x_front, -y_body, chassis_z],
            [x_rear, -y_body, chassis_z],
            [x_rear, y_body, chassis_z],
        ]
    )
    segs += _rect_loop(
        [
            [x_front, y_body, hood_z],
            [x_hood_end, y_body, hood_z],
            [x_hood_end, -y_body, hood_z],
            [x_front, -y_body, hood_z],
        ]
    )
    segs += _rect_loop(
        [
            [x_front, y_body, chassis_z],
            [x_front, y_body, hood_z],
            [x_front, -y_body, hood_z],
            [x_front, -y_body, chassis_z],
        ]
    )
    for y in [y_body, -y_body]:
        segs.append(([x_front, y, chassis_z], [x_front, y, hood_z]))
        segs.append(([x_hood_end, y, chassis_z], [x_hood_end, y, hood_z]))
    segs += _rect_loop(
        [
            [x_rear, y_body, hood_z],
            [x_trunk_st, y_body, hood_z],
            [x_trunk_st, -y_body, hood_z],
            [x_rear, -y_body, hood_z],
        ]
    )
    segs += _rect_loop(
        [
            [x_rear, y_body, chassis_z],
            [x_rear, y_body, hood_z],
            [x_rear, -y_body, hood_z],
            [x_rear, -y_body, chassis_z],
        ]
    )
    for y in [y_body, -y_body]:
        segs.append(([x_rear, y, chassis_z], [x_rear, y, hood_z]))
        segs.append(([x_trunk_st, y, chassis_z], [x_trunk_st, y, hood_z]))
    for y in [y_body, -y_body]:
        segs.append(([x_hood_end, y, chassis_z], [x_trunk_st, y, chassis_z]))
        segs.append(([x_hood_end, y, sill_z], [x_trunk_st, y, sill_z]))
        for xp in [x_hood_end, 0.0, x_trunk_st]:
            segs.append(([xp, y, chassis_z], [xp, y, sill_z]))
    for y in [y_cabin, -y_cabin]:
        segs.append(([x_hood_end, y, sill_z], [x_roof_f, y, roof_z]))
    segs += _rect_loop(
        [
            [x_hood_end, y_cabin, sill_z],
            [x_roof_f, y_cabin, roof_z],
            [x_roof_f, -y_cabin, roof_z],
            [x_hood_end, -y_cabin, sill_z],
        ]
    )
    for y in [y_cabin, -y_cabin]:
        segs.append(([x_trunk_st, y, sill_z], [x_roof_r, y, roof_z]))
    segs += _rect_loop(
        [
            [x_trunk_st, y_cabin, sill_z],
            [x_roof_r, y_cabin, roof_z],
            [x_roof_r, -y_cabin, roof_z],
            [x_trunk_st, -y_cabin, sill_z],
        ]
    )
    segs += _rect_loop(
        [
            [x_roof_f, y_cabin, roof_z],
            [x_roof_r, y_cabin, roof_z],
            [x_roof_r, -y_cabin, roof_z],
            [x_roof_f, -y_cabin, roof_z],
        ]
    )
    segs.append(([x_roof_f, 0, roof_z], [x_roof_r, 0, roof_z]))

    nw = 16
    wt = 0.12
    wheel_pos = [
        (0.65, y_body, wheel_r),
        (0.65, -y_body, wheel_r),
        (-0.65, y_body, wheel_r),
        (-0.65, -y_body, wheel_r),
    ]
    for wx, wy, wz in wheel_pos:
        for sy in [wy - wt, wy + wt]:
            ring = [
                (
                    wx + wheel_r * np.cos(2 * np.pi * k / nw),
                    sy,
                    wz + wheel_r * np.sin(2 * np.pi * k / nw),
                )
                for k in range(nw)
            ]
            segs += _rect_loop(ring)
        for ang in np.linspace(0, np.pi, 4, endpoint=False):
            p1 = [wx + wheel_r * np.cos(ang), wy - wt, wz + wheel_r * np.sin(ang)]
            p2 = [wx + wheel_r * np.cos(ang), wy + wt, wz + wheel_r * np.sin(ang)]
            segs.append((p1, p2))
        for ang in [0, np.pi / 2]:
            dx = wheel_r * np.cos(ang)
            dz = wheel_r * np.sin(ang)
            for sy in [wy - wt, wy + wt]:
                segs.append(([wx - dx, sy, wz - dz], [wx + dx, sy, wz + dz]))

    for y_sign in [1, -1]:
        y0, y1 = y_sign * 0.42, y_sign * 0.20
        z0, z1 = 0.14, 0.28
        segs += _rect_loop(
            [
                [x_front, y0, z0],
                [x_front, y1, z0],
                [x_front, y1, z1],
                [x_front, y0, z1],
            ]
        )
    for y_sign in [1, -1]:
        y0, y1 = y_sign * 0.42, y_sign * 0.20
        z0, z1 = 0.14, 0.32
        segs += _rect_loop(
            [
                [x_rear, y0, z0],
                [x_rear, y1, z0],
                [x_rear, y1, z1],
                [x_rear, y0, z1],
            ]
        )

    return [(np.array(p1, float), np.array(p2, float)) for p1, p2 in segs]


_CAR_SEGS_UNIT = _make_car_vertices()


def draw_car(ax, pos, R, scale, color="#555555", alpha=0.55):
    ox, oy, oz = pos
    lines = []
    for p1, p2 in _CAR_SEGS_UNIT:
        w1 = R @ (p1 * scale) + np.array([ox, oy, oz])
        w2 = R @ (p2 * scale) + np.array([ox, oy, oz])
        lines.append([w1, w2])
    lc = Line3DCollection(lines, colors=color, linewidths=0.8, alpha=alpha)
    ax.add_collection3d(lc)


#Column mapping
class ColumnMapDialog(QWidget):
    mappingConfirmed = pyqtSignal(dict)

    FIELDS = [
        ("time", "Time (s or datetime)"),
        ("ax", "Accel X (m/s²)"),
        ("ay", "Accel Y (m/s²)"),
        ("az", "Accel Z (m/s²)"),
        ("gx", "Gyro X (rad/s or °/s)"),
        ("gy", "Gyro Y (rad/s or °/s)"),
        ("gz", "Gyro Z (rad/s or °/s)"),
        ("lat", "GPS Latitude"),
        ("lon", "GPS Longitude"),
        ("alt", "GPS Altitude (m)"),
        ("temp", "Temperature (°C)"),
    ]

    def __init__(self, columns, parent=None):
        super().__init__(parent, Qt.WindowType.Window)
        self.setWindowTitle("Map CSV Columns")
        self.setMinimumWidth(420)
        self.columns = ["(none)"] + list(columns)
        self._build(columns)

    def _build(self, columns):
        layout = QVBoxLayout(self)
        layout.setSpacing(8)
        layout.setContentsMargins(16, 16, 16, 16)
        hdr = QLabel("Map CSV columns to telemetry fields")
        hdr.setStyleSheet(f"color:{TEXT_PRI}; font-size:13px; font-weight:600;")
        layout.addWidget(hdr)
        form = QFormLayout()
        form.setSpacing(6)
        self.combos = {}
        guesses = self._guess(columns)
        for field, label in self.FIELDS:
            cb = QComboBox()
            cb.addItems(self.columns)
            if field in guesses:
                idx = cb.findText(guesses[field])
                if idx >= 0:
                    cb.setCurrentIndex(idx)
            form.addRow(QLabel(label), cb)
            self.combos[field] = cb
        layout.addLayout(form)
        btn = QPushButton("Confirm Mapping")
        btn.clicked.connect(self._confirm)
        layout.addWidget(btn)
        self.setStyleSheet(f"background:{BG}; color:{TEXT_PRI};")

    def _guess(self, cols):
        mapping = {}
        lc = {c.lower(): c for c in cols}
        hints = {
            "time": ["time", "t", "timestamp", "elapsed"],
            "ax": ["ax", "accel_x", "acc_x", "a_x", "accelx"],
            "ay": ["ay", "accel_y", "acc_y", "a_y", "accely"],
            "az": ["az", "accel_z", "acc_z", "a_z", "accelz"],
            "gx": ["gx", "gyro_x", "gyroscope_x", "wx", "roll_rate"],
            "gy": ["gy", "gyro_y", "gyroscope_y", "wy", "pitch_rate"],
            "gz": ["gz", "gyro_z", "gyroscope_z", "wz", "yaw_rate"],
            "lat": ["lat", "latitude", "gps_lat"],
            "lon": ["lon", "lng", "longitude", "gps_lon", "gps_lng"],
            "alt": ["alt", "altitude", "gps_alt", "elevation"],
            "temp": ["temp", "temperature", "tmp", "celsius"],
        }
        for field, candidates in hints.items():
            for c in candidates:
                if c in lc:
                    mapping[field] = lc[c]
                    break
        return mapping

    def _confirm(self):
        result = {}
        for field, cb in self.combos.items():
            val = cb.currentText()
            if val != "(none)":
                result[field] = val
        self.mappingConfirmed.emit(result)
        self.close()


#Trajectory processing
class TelemetryProcessor:
    def __init__(self, df, col_map):
        self.df = df.copy()
        self.col = col_map
        self._normalize_time()

    def _normalize_time(self):
        tc = self.col.get("time")
        if tc and tc in self.df.columns:
            t = pd.to_numeric(self.df[tc], errors="coerce")
            if t.isna().all():
                t = pd.to_datetime(self.df[tc], errors="coerce")
                t = (t - t.iloc[0]).dt.total_seconds()
            self.t = t.ffill().values.astype(float)
        else:
            self.t = np.arange(len(self.df), dtype=float)

    def _col(self, key, default=0.0):
        c = self.col.get(key)
        if c and c in self.df.columns:
            return pd.to_numeric(self.df[c], errors="coerce").fillna(0).values.copy()
        return np.full(len(self.df), default)

    def compute(self, noise_gates=None, median_kernels=None):
        t = self.t
        ax = self._col("ax")
        ay = self._col("ay")
        az = self._col("az")
        gx = self._col("gx")
        gy = self._col("gy")
        gz = self._col("gz")
        lat = self._col("lat", np.nan)
        lon = self._col("lon", np.nan)
        alt = self._col("alt", 0.0)
        temp = self._col("temp", np.nan)

        if median_kernels:
            ka = median_kernels.get("mf_accel", 1)
            kg = median_kernels.get("mf_gyro", 1)
            if ka > 1:
                ax = medfilt(ax, ka)
                ay = medfilt(ay, ka)
                az = medfilt(az, ka)
            if kg > 1:
                gx = medfilt(gx, kg)
                gy = medfilt(gy, kg)
                gz = medfilt(gz, kg)

        dt = np.diff(t, prepend=t[0])
        dt[0] = dt[1] if len(dt) > 1 else 0.01
        dt = np.clip(dt, 1e-6, 1.0)

        N = min(50, len(ax))
        ax = ax - np.mean(ax[:N])
        ay = ay - np.mean(ay[:N])
        az_bias = np.mean(az[:N])
        az = az - (az_bias if abs(az_bias) > 0.5 else 0)

        if noise_gates:
            for arr, key in [
                (ax, "ax"),
                (ay, "ay"),
                (az, "az"),
                (gx, "gx"),
                (gy, "gy"),
                (gz, "gz"),
            ]:
                thr = noise_gates.get(key, 0.0)
                if thr > 0:
                    arr = arr.copy()
                    arr[np.abs(arr) < thr] = 0.0
                    if key == "ax":
                        ax = arr
                    elif key == "ay":
                        ay = arr
                    elif key == "az":
                        az = arr
                    elif key == "gx":
                        gx = arr
                    elif key == "gy":
                        gy = arr
                    elif key == "gz":
                        gz = arr

        vx = np.cumsum(ax * dt)
        vy = np.cumsum(ay * dt)
        vz = np.cumsum(az * dt)
        px = np.cumsum(vx * dt)
        py = np.cumsum(vy * dt)
        pz = np.cumsum(vz * dt)

        has_gps = not (np.all(np.isnan(lat)) or np.all(lat == 0))
        gps_x = gps_y = gps_z = None
        if has_gps:
            lat0 = np.nanmean(lat)
            lon0 = np.nanmean(lon)
            R = 6371000.0
            gps_x = R * np.radians(lon - lon0) * np.cos(np.radians(lat0))
            gps_y = R * np.radians(lat - lat0)
            gps_z = alt - np.nanmean(alt)

        speed = np.sqrt(vx**2 + vy**2 + vz**2)
        rotations = np.zeros((len(t), 3, 3))
        Rmat = np.eye(3)
        for i in range(len(t)):
            wx, wy, wz2 = gx[i], gy[i], gz[i]
            d = dt[i]
            angle = np.sqrt(wx**2 + wy**2 + wz2**2) * d
            if angle > 1e-8:
                kx, ky, kz = wx / (angle / d), wy / (angle / d), wz2 / (angle / d)
                kx, ky, kz = kx * d, ky * d, kz * d
                c, s = np.cos(angle), np.sin(angle)
                t_r = 1 - c
                norm = np.sqrt(kx**2 + ky**2 + kz**2)
                kx /= norm
                ky /= norm
                kz /= norm
                dR = np.array(
                    [
                        [
                            c + kx * kx * t_r,
                            kx * ky * t_r - kz * s,
                            kx * kz * t_r + ky * s,
                        ],
                        [
                            ky * kx * t_r + kz * s,
                            c + ky * ky * t_r,
                            ky * kz * t_r - kx * s,
                        ],
                        [
                            kz * kx * t_r - ky * s,
                            kz * ky * t_r + kx * s,
                            c + kz * kz * t_r,
                        ],
                    ]
                )
                Rmat = Rmat @ dR
            rotations[i] = Rmat

        return {
            "t": t,
            "dt": dt,
            "ax": ax,
            "ay": ay,
            "az": az,
            "gx": gx,
            "gy": gy,
            "gz": gz,
            "px": px,
            "py": py,
            "pz": pz,
            "vx": vx,
            "vy": vy,
            "vz": vz,
            "speed": speed,
            "temp": temp,
            "has_gps": has_gps,
            "gps_x": gps_x,
            "gps_y": gps_y,
            "gps_z": gps_z,
            "lat": lat,
            "lon": lon,
            "alt": alt,
            "rotations": rotations,
        }


#Matplotlib 3D trajectory canvas
class TrajectoryCanvas(FigureCanvas):
    def __init__(self):
        self.fig = Figure(figsize=(7, 6), tight_layout=True)
        super().__init__(self.fig)
        self.ax3d = self.fig.add_subplot(111, projection="3d")
        self._style_3d()
        self._data = None
        self._show_gps = False
        self._show_car = True
        self._anim_frame = 0
        self._anim_total = 0
        self._xlim = self._ylim = self._zlim = (-1, 1)
        self._norm = None
        self._MAX_ANIM = 800
        self._px = self._py = self._pz = None
        self._speed_ds = None
        self._rots_ds = None
        self._colorbar = None
        self._car_scale = 1.0
        self._triad_len = 1.0
        self._default_elev = 25.0
        self._default_azim = -60.0
        self._temp_mode = False
        self._temp_masks_ds = {}

    def _style_3d(self):
        ax = self.ax3d
        ax.set_facecolor(MPL_PANEL)
        self.fig.patch.set_facecolor(MPL_BG)
        for pane in [ax.xaxis.pane, ax.yaxis.pane, ax.zaxis.pane]:
            pane.fill = False
            pane.set_edgecolor(BORDER)
        ax.grid(True, color=BORDER, alpha=0.8)

    def plot(self, data, show_gps=False):
        self._data = data
        self._show_gps = show_gps
        px_full = data["px"]
        py_full = data["py"]
        pz_full = data["pz"]
        speed_full = data["speed"]
        N = len(px_full)
        idx = np.linspace(0, N - 1, min(N, self._MAX_ANIM), dtype=int)
        self._px = px_full[idx]
        self._py = py_full[idx]
        self._pz = pz_full[idx]
        self._speed_ds = speed_full[idx]
        self._rots_ds = data["rotations"][idx]
        self._temp_masks_ds = {}
        self._anim_total = len(self._px)
        self._anim_frame = self._anim_total
        self._norm = plt.Normalize(speed_full.min(), speed_full.max())

        def lim(arr):
            r = max(np.ptp(arr) * 0.1, 0.1)
            return arr.min() - r, arr.max() + r

        self._xlim = lim(self._px)
        self._ylim = lim(self._py)
        self._zlim = lim(self._pz)

        span = max(
            self._xlim[1] - self._xlim[0],
            self._ylim[1] - self._ylim[0],
            self._zlim[1] - self._zlim[0],
        )
        self._car_scale = span * 0.09
        self._triad_len = span * 0.13

        self.fig.clf()
        self.ax3d = self.fig.add_subplot(111, projection="3d")
        self.ax3d.view_init(elev=self._default_elev, azim=self._default_azim)
        sm = plt.cm.ScalarMappable(cmap="viridis", norm=self._norm)
        sm.set_array([])
        self._colorbar = self.fig.colorbar(sm, ax=self.ax3d, pad=0.1, shrink=0.6)
        self._colorbar.set_label("Speed (m/s)", color=TEXT_SEC)
        self._colorbar.ax.yaxis.set_tick_params(color=TEXT_SEC)
        plt.setp(self._colorbar.ax.yaxis.get_ticklabels(), color=TEXT_SEC)
        self._draw_frame(self._anim_total)

    def _draw_frame(self, n):
        self.ax3d.cla()
        self._style_3d()
        ax = self.ax3d
        n = max(1, min(n, self._anim_total))
        px = self._px[:n]
        py = self._py[:n]
        pz = self._pz[:n]
        spd = self._speed_ds[:n]

        ax.plot(
            self._px,
            self._py,
            self._pz,
            color=BORDER,
            linewidth=0.7,
            alpha=0.4,
            zorder=1,
        )

        if len(px) > 1:
            points = np.array([px, py, pz]).T.reshape(-1, 1, 3)
            segs = np.concatenate([points[:-1], points[1:]], axis=1)

            if self._temp_mode and self._temp_masks_ds:
                base_colors = plt.cm.viridis(self._norm(spd[:-1]))
                seg_colors = base_colors.copy()

                # Apply in priority order so that severe threshold flags override window trend colors
                for key in ["win_increase", "win_decrease", "too_low", "too_high"]:
                    mask = self._temp_masks_ds.get(key)
                    if mask is None:
                        continue
                    color = matplotlib.colors.to_rgba(TEMP_ALERT_SPECS[key]["color"])
                    mask_n = mask[:n]
                    for i in range(len(segs)):
                        if mask_n[i]:
                            seg_colors[i] = color

                lc = Line3DCollection(
                    segs, colors=seg_colors, linewidth=2.2, alpha=0.95
                )
            else:
                colors = plt.cm.viridis(self._norm(spd[:-1]))
                lc = Line3DCollection(segs, colors=colors, linewidth=1.8, alpha=0.9)

            ax.add_collection3d(lc)

            if self._temp_mode:
                for key, size, alpha in [
                    ("win_increase", 16, 0.70),
                    ("win_decrease", 16, 0.70),
                    ("too_low", 20, 0.80),
                    ("too_high", 22, 0.85),
                ]:
                    mask = self._temp_masks_ds.get(key)
                    if mask is None:
                        continue
                    mask_n = mask[:n]
                    if not mask_n.any():
                        continue
                    pts_mask = mask_n[:-1] if len(mask_n) > 1 else mask_n
                    ax.scatter(
                        px[:-1][pts_mask],
                        py[:-1][pts_mask],
                        pz[:-1][pts_mask],
                        color=TEMP_ALERT_SPECS[key]["color"],
                        s=size,
                        zorder=6,
                        depthshade=False,
                        alpha=alpha,
                        label=TEMP_ALERT_SPECS[key]["label"],
                    )

        ax.scatter(
            [self._px[0]],
            [self._py[0]],
            [self._pz[0]],
            color=ACCENT3,
            s=55,
            zorder=5,
            label="Start",
            depthshade=False,
        )

        pos = np.array([px[-1], py[-1], pz[-1]])
        R = self._rots_ds[n - 1] if self._rots_ds is not None else np.eye(3)

        if self._show_car:
            draw_car(ax, pos, R, scale=self._car_scale, color="#555555", alpha=0.55)

        for col, color in enumerate(["#cc3333", "#33aa33", "#3366cc"]):
            axis = R[:, col] * self._triad_len
            ax.quiver(
                pos[0],
                pos[1],
                pos[2],
                axis[0],
                axis[1],
                axis[2],
                color=color,
                linewidth=2.2,
                arrow_length_ratio=0.25,
                alpha=0.9,
                zorder=7,
            )

        if n >= self._anim_total:
            ax.scatter(
                [self._px[-1]],
                [self._py[-1]],
                [self._pz[-1]],
                color=ACCENT2,
                s=55,
                zorder=5,
                label="End",
                depthshade=False,
            )

        if self._show_gps and self._data and self._data["has_gps"]:
            gx2, gy2, gz2 = (
                self._data["gps_x"],
                self._data["gps_y"],
                self._data["gps_z"],
            )
            mask = ~np.isnan(gx2)
            ax.plot(
                gx2[mask],
                gy2[mask],
                gz2[mask],
                color=ACCENT,
                linewidth=1.2,
                alpha=0.7,
                linestyle="--",
                label="GPS track",
            )

        ax.set_xlabel("X (m)", labelpad=4)
        ax.set_ylabel("Y (m)", labelpad=4)
        ax.set_zlabel("Z (m)", labelpad=4)
        pct = int(100 * n / max(self._anim_total, 1))
        ax.set_title(f"3D Trajectory  [{pct}%]", color=TEXT_PRI, pad=16)
        ax.legend(
            fontsize=7,
            loc="upper center",
            bbox_to_anchor=(0.5, 1.02),
            ncol=2,
            framealpha=0.78,
            borderpad=0.35,
            handlelength=1.1,
            labelspacing=0.25,
            columnspacing=0.9,
        )

        x_mid = (self._xlim[0] + self._xlim[1]) / 2
        y_mid = (self._ylim[0] + self._ylim[1]) / 2
        z_mid = (self._zlim[0] + self._zlim[1]) / 2
        half = (
            max(
                self._xlim[1] - self._xlim[0],
                self._ylim[1] - self._ylim[0],
                self._zlim[1] - self._zlim[0],
            )
            / 2
        )
        ax.set_xlim(x_mid - half, x_mid + half)
        ax.set_ylim(y_mid - half, y_mid + half)
        ax.set_zlim(z_mid - half, z_mid + half)
        self.draw()

    def reset_view(self):
        self.ax3d.view_init(elev=self._default_elev, azim=self._default_azim)
        self.draw()

    def anim_step(self, frame):
        self._anim_frame = frame
        self._draw_frame(frame)

    def set_show_gps(self, val):
        self._show_gps = val
        if self._px is not None:
            self._draw_frame(self._anim_frame)

    def set_show_car(self, val):
        self._show_car = val
        if self._px is not None:
            self._draw_frame(self._anim_frame)

    def set_temp_masks(self, masks_full):
        if not masks_full:
            self._temp_masks_ds = {}
            if self._px is not None:
                self._draw_frame(self._anim_frame)
            return

        first = next(iter(masks_full.values()), None)
        N = len(first) if first is not None else 0
        if N == 0:
            self._temp_masks_ds = {}
            if self._px is not None:
                self._draw_frame(self._anim_frame)
            return

        idx = np.linspace(0, N - 1, min(N, self._MAX_ANIM), dtype=int)
        self._temp_masks_ds = {
            key: np.asarray(mask, dtype=bool)[idx] for key, mask in masks_full.items()
        }
        if self._px is not None:
            self._draw_frame(self._anim_frame)

    def set_temp_mode(self, active):
        self._temp_mode = active
        if self._px is not None:
            self._draw_frame(self._anim_frame)


class SensorCanvas(FigureCanvas):
    def __init__(self, title, channels, colors):
        self.fig = Figure(figsize=(7, 3.2), tight_layout=True)
        super().__init__(self.fig)
        self.ax = self.fig.add_subplot(111)
        self.title = title
        self.channels = channels
        self.colors = colors
        self._t = None
        self._playhead = None
        self._lines = {}
        self._arrays = {}
        self._visible = {ch: True for ch in channels}
        self._alert_masks = {}
        self._style()

    def _style(self):
        self.ax.set_facecolor(MPL_PANEL)
        self.fig.patch.set_facecolor(MPL_BG)
        self.ax.grid(True, color=BORDER, alpha=0.8)

    def _legend_kwargs(self, with_alerts=False):
        if self.title == "Temperature":
            return {
                "fontsize": 8,
                "ncol": 3 if with_alerts else 2,
                "loc": "upper center",
                "bbox_to_anchor": (0.5, 1.10 if with_alerts else 1.06),
                "framealpha": 0.78,
                "borderpad": 0.30,
                "labelspacing": 0.25,
                "columnspacing": 0.9,
                "handlelength": 1.3,
            }
        return {
            "fontsize": 8,
            "ncol": 4 if with_alerts else 3,
            "loc": "upper right",
        }

    def plot(self, t, arrays, labels=None):
        self.ax.cla()
        self._style()
        self._t = t
        self._lines = {}
        labels = labels or self.channels
        for arr, label, color in zip(arrays, labels, self.colors):
            self._arrays[label] = arr
            vis = self._visible.get(label, True)
            (line,) = self.ax.plot(
                t, arr, color=color, label=label, linewidth=1.4, alpha=0.85, visible=vis
            )
            self._lines[label] = line
        if self.title == "Temperature":
            self.ax.set_title(self.title, color=TEXT_PRI, y=1.21, pad=0)
        else:
            self.ax.set_title(self.title, color=TEXT_PRI)
        self.ax.set_xlabel("Time (s)")
        self.ax.legend(**self._legend_kwargs(with_alerts=False))
        self._playhead = self.ax.axvline(
            x=t[-1],
            color="#aaaaaa",
            linewidth=1.2,
            linestyle="--",
            alpha=0.75,
            zorder=10,
        )
        self._draw_alert_overlays()
        self.draw()

    def set_alert_overlays(self, t, alert_masks):
        self._alert_masks = alert_masks or {}
        if self._t is not None:
            self.ax.cla()
            self._style()
            for label, color in zip(self.channels, self.colors):
                arr = self._arrays.get(label)
                if arr is None:
                    continue
                vis = self._visible.get(label, True)
                (line,) = self.ax.plot(
                    self._t,
                    arr,
                    color=color,
                    label=label,
                    linewidth=1.4,
                    alpha=0.85,
                    visible=vis,
                )
                self._lines[label] = line
            if self.title == "Temperature":
                self.ax.set_title(self.title, color=TEXT_PRI, y=1.21, pad=0)
            else:
                self.ax.set_title(self.title, color=TEXT_PRI)
            self.ax.set_xlabel("Time (s)")
            self.ax.legend(**self._legend_kwargs(with_alerts=False))
            self._playhead = self.ax.axvline(
                x=self._t[-1],
                color="#aaaaaa",
                linewidth=1.2,
                linestyle="--",
                alpha=0.75,
                zorder=10,
            )
            self._draw_alert_overlays()
            self.draw()

    def _draw_alert_overlays(self):
        if self._t is None:
            return
        t = self._t

        def _span_mask(mask, color, alpha, label, zorder):
            if mask is None or not np.any(mask):
                return
            in_run = False
            start = 0
            added_label = False
            for i, v in enumerate(mask):
                if v and not in_run:
                    in_run = True
                    start = i
                elif not v and in_run:
                    in_run = False
                    kw = {"label": label} if not added_label else {}
                    self.ax.axvspan(
                        t[start],
                        t[i - 1],
                        color=color,
                        alpha=alpha,
                        zorder=zorder,
                        **kw,
                    )
                    added_label = True
            if in_run:
                kw = {"label": label} if not added_label else {}
                self.ax.axvspan(
                    t[start], t[-1], color=color, alpha=alpha, zorder=zorder, **kw
                )

        has_any_alert = False
        for key in ["win_increase", "win_decrease", "too_low", "too_high"]:
            mask = self._alert_masks.get(key)
            spec = TEMP_ALERT_SPECS[key]
            if mask is not None and np.any(mask):
                has_any_alert = True
            _span_mask(mask, spec["color"], spec["alpha"], spec["label"], spec["z"])

        if has_any_alert:
            self.ax.legend(**self._legend_kwargs(with_alerts=True))

    def set_channel_visible(self, label, visible):
        self._visible[label] = visible
        if label in self._lines:
            self._lines[label].set_visible(visible)
            handles = [l for l in self._lines.values() if l.get_visible()]
            self.ax.legend(handles=handles, **self._legend_kwargs(with_alerts=False))
            self.draw_idle()

    def set_playhead(self, t_val):
        if self._playhead is None:
            return
        self._playhead.set_xdata([t_val, t_val])
        self.draw_idle()


#Stats bar label
class StatLabel(QLabel):
    def __init__(self, key, unit=""):
        super().__init__()
        self.key = key
        self.unit = unit
        self.setStyleSheet(
            f"""
            color:{TEXT_PRI}; background:{BG_WIDGET};
            border:1px solid {BORDER}; border-radius:4px;
            padding:4px 10px; font-size:11px;
        """
        )
        self.setValue(None)

    def setValue(self, val):
        if val is None:
            self.setText(f"<span style='color:{TEXT_SEC}'>{self.key}</span>  —")
        else:
            self.setText(
                f"<span style='color:{TEXT_SEC}'>{self.key}</span>"
                f"  <b>{val:.2f}</b>"
                f"<span style='color:{TEXT_SEC}'> {self.unit}</span>"
            )
        self.setTextFormat(Qt.TextFormat.RichText)

    def setIntValue(self, val, note=None):
        text = (
            f"<span style='color:{TEXT_SEC}'>{self.key}</span>"
            f"  <b>{int(val)}</b>"
            f"<span style='color:{TEXT_SEC}'> {self.unit}</span>"
        )
        if note:
            text += f"<span style='color:{TEXT_SEC}; font-size:9px;'>  ({note})</span>"
        self.setText(text)
        self.setTextFormat(Qt.TextFormat.RichText)


#Main window
STYLE = """
QMainWindow, QWidget {
    background:#ffffff; color:#111111;
    font-family:'Segoe UI','Helvetica Neue',Arial,sans-serif;
}
QPushButton {
    background:#ffffff; color:#111111; border:1px solid #cccccc;
    border-radius:4px; padding:6px 16px; font-size:13px;
}
QPushButton:hover   { background:#f5f5f5; }
QPushButton:pressed { background:#ebebeb; }
QPushButton:disabled { color:#aaaaaa; border-color:#dddddd; }

QTabWidget::pane { border:1px solid #dddddd; background:#ffffff; }
QTabBar::tab {
    background:#f9f9f9; color:#777777;
    padding:6px 18px; border:1px solid #dddddd;
    font-size:12px;
}
QTabBar::tab:selected { color:#111111; border-bottom:2px solid #2980b9; background:#ffffff; }

QGroupBox {
    border:1px solid #dddddd; border-radius:4px; margin-top:10px; padding:6px;
    font-size:11px; color:#777777;
}
QGroupBox::title { subcontrol-origin:margin; left:8px; padding:0 4px; color:#777777; }

QComboBox {
    background:#ffffff; color:#111111; border:1px solid #cccccc;
    border-radius:4px; padding:3px 8px; font-size:12px;
}
QComboBox::drop-down { border:none; }
QComboBox QAbstractItemView { background:#ffffff; color:#111111; selection-background-color:#e8f0fe; }

QCheckBox { color:#111111; font-size:12px; }
QCheckBox::indicator {
    width:13px; height:13px; border:1px solid #cccccc;
    border-radius:2px; background:#ffffff;
}
QCheckBox::indicator:checked { background:#2980b9; border-color:#2980b9; }

QLineEdit {
    background:#ffffff; color:#111111; border:1px solid #cccccc;
    border-radius:4px; font-size:12px; padding:2px 6px;
}
QLineEdit:focus { border-color:#2980b9; }

QSlider::groove:horizontal { background:#dddddd; height:4px; border-radius:2px; }
QSlider::handle:horizontal {
    background:#2980b9; width:12px; height:12px;
    margin:-4px 0; border-radius:6px;
}
QSlider::sub-page:horizontal { background:#2980b9; border-radius:2px; opacity:0.5; }

QScrollBar:vertical { background:#f9f9f9; width:8px; }
QScrollBar::handle:vertical { background:#cccccc; border-radius:4px; }

QSplitter::handle { background:#dddddd; width:4px; height:4px; }
QSplitter::handle:hover { background:#aaaaaa; }

QStatusBar { background:#f9f9f9; color:#777777; border-top:1px solid #dddddd; font-size:11px; }
"""


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Telemetry Trajectory Visualizer")
        self.setMinimumSize(1200, 780)
        self.df = None
        self.col_map = {}
        self.data = None
        self._anim_timer = QTimer(self)
        self._anim_timer.timeout.connect(self._anim_tick)
        self._anim_frame = 0
        self._anim_speed = 5
        self._build_ui()
        self.setStyleSheet(STYLE)

    #Noise gate
    def _build_noise_gate_panel(self):
        outer = QWidget()
        outer.setStyleSheet(f"border-bottom:1px solid {BORDER};")
        outer_layout = QVBoxLayout(outer)
        outer_layout.setContentsMargins(0, 0, 0, 0)
        outer_layout.setSpacing(0)

        header_row = QWidget()
        header_row.setFixedHeight(32)
        hr_layout = QHBoxLayout(header_row)
        hr_layout.setContentsMargins(16, 0, 16, 0)

        self._ng_toggle_btn = QPushButton("▶  Noise Gate")
        self._ng_toggle_btn.setStyleSheet(
            """
            QPushButton {
                background:transparent; color:#777777; border:none;
                font-size:11px; text-align:left; padding:0;
            }
            QPushButton:hover { color:#111111; }
        """
        )
        self._ng_toggle_btn.setFlat(True)
        self._ng_toggle_btn.clicked.connect(self._toggle_noise_gate)
        hr_layout.addWidget(self._ng_toggle_btn)
        hr_layout.addStretch()

        ng_reset_btn = QPushButton("Reset")
        ng_reset_btn.setFixedWidth(80)
        ng_reset_btn.clicked.connect(self._ng_reset)
        hr_layout.addWidget(ng_reset_btn)
        outer_layout.addWidget(header_row)

        self._ng_body = QWidget()
        self._ng_body.setVisible(False)
        self._ng_body.setStyleSheet(f"background:{BG_WIDGET};")
        body_layout = QHBoxLayout(self._ng_body)
        body_layout.setContentsMargins(16, 8, 16, 8)
        body_layout.setSpacing(24)

        self._ng_fields = {}

        accel_grp = QGroupBox("Accel Threshold (m/s²)")
        ag = QHBoxLayout(accel_grp)
        ag.setSpacing(8)
        for axis, color in [("ax", ACCENT2), ("ay", ACCENT3), ("az", ACCENT)]:
            lbl = QLabel(axis)
            lbl.setStyleSheet(f"color:{color}; font-weight:bold;")
            field = QLineEdit("0.0")
            field.setFixedWidth(62)
            ag.addWidget(lbl)
            ag.addWidget(field)
            self._ng_fields[axis] = field
        body_layout.addWidget(accel_grp)

        gyro_grp = QGroupBox("Gyro Threshold (rad/s)")
        gg = QHBoxLayout(gyro_grp)
        gg.setSpacing(8)
        for axis, color in [("gx", "#cc3333"), ("gy", "#33aa33"), ("gz", "#3366cc")]:
            lbl = QLabel(axis)
            lbl.setStyleSheet(f"color:{color}; font-weight:bold;")
            field = QLineEdit("0.0")
            field.setFixedWidth(62)
            gg.addWidget(lbl)
            gg.addWidget(field)
            self._ng_fields[axis] = field
        body_layout.addWidget(gyro_grp)

        medfilt_grp = QGroupBox("Median Filter")
        mf = QHBoxLayout(medfilt_grp)
        mf.setSpacing(8)
        self._medfilt_check = QCheckBox("Enable")
        self._medfilt_check.setChecked(False)
        self._medfilt_check.stateChanged.connect(self._on_medfilt_toggle)
        mf.addWidget(self._medfilt_check)
        sep = QLabel("  |  ")
        sep.setStyleSheet(f"color:{BORDER};")
        mf.addWidget(sep)
        lbl_kernel = QLabel("Kernel (odd):")
        lbl_kernel.setStyleSheet(f"color:{TEXT_SEC}; font-size:11px;")
        mf.addWidget(lbl_kernel)
        for axis, color in [("mf_accel", ACCENT2), ("mf_gyro", "#cc3333")]:
            label_text = "Accel" if axis == "mf_accel" else "Gyro"
            lbl = QLabel(label_text)
            lbl.setStyleSheet(f"color:{color}; font-weight:bold;")
            field = QLineEdit("3")
            field.setFixedWidth(62)
            field.setEnabled(False)
            mf.addWidget(lbl)
            mf.addWidget(field)
            self._ng_fields[axis] = field
        body_layout.addWidget(medfilt_grp)

        body_layout.addStretch()
        outer_layout.addWidget(self._ng_body)
        return outer

    def _toggle_noise_gate(self):
        visible = not self._ng_body.isVisible()
        self._ng_body.setVisible(visible)
        self._ng_toggle_btn.setText(f"{'▼' if visible else '▶'}  Noise Gate")

    def _on_medfilt_toggle(self, state):
        enabled = bool(state)
        for key in ("mf_accel", "mf_gyro"):
            self._ng_fields[key].setEnabled(enabled)

    def _ng_reset(self):
        self._medfilt_check.setChecked(False)
        for key, field in self._ng_fields.items():
            field.setText("3" if key.startswith("mf_") else "0.0")

    def _get_noise_gates(self):
        gates = {}
        for axis, field in self._ng_fields.items():
            if axis.startswith("mf_"):
                continue
            try:
                val = float(field.text())
                if val > 0:
                    gates[axis] = val
            except ValueError:
                pass
        return gates

    def _get_median_kernels(self):
        if not self._medfilt_check.isChecked():
            return {}
        kernels = {}
        for key in ("mf_accel", "mf_gyro"):
            field = self._ng_fields.get(key)
            if field is None:
                continue
            try:
                k = int(field.text())
                k = max(1, k if k % 2 == 1 else k + 1)
                kernels[key] = k
            except ValueError:
                kernels[key] = 3
        return kernels

    #Temp alerts
    def _build_temp_alert_panel(self):
        """Collapsible panel for specific temperature alert settings."""
        outer = QWidget()
        outer.setStyleSheet(f"border-bottom:1px solid {BORDER};")
        outer_layout = QVBoxLayout(outer)
        outer_layout.setContentsMargins(0, 0, 0, 0)
        outer_layout.setSpacing(0)

        # Always-visible header row
        header_row = QWidget()
        header_row.setFixedHeight(32)
        hr_layout = QHBoxLayout(header_row)
        hr_layout.setContentsMargins(16, 0, 16, 0)

        self._ta_toggle_btn = QPushButton("▶  Temperature Alerts")
        self._ta_toggle_btn.setStyleSheet(
            """
            QPushButton {
                background:transparent; color:#777777; border:none;
                font-size:11px; text-align:left; padding:0;
            }
            QPushButton:hover { color:#111111; }
        """
        )
        self._ta_toggle_btn.setFlat(True)
        self._ta_toggle_btn.clicked.connect(self._toggle_temp_alert)
        hr_layout.addWidget(self._ta_toggle_btn)
        hr_layout.addStretch()

        ta_reset_btn = QPushButton("Reset")
        ta_reset_btn.setFixedWidth(80)
        ta_reset_btn.clicked.connect(self._ta_reset)
        hr_layout.addWidget(ta_reset_btn)
        outer_layout.addWidget(header_row)

        # Collapsible body
        self._ta_body = QWidget()
        self._ta_body.setVisible(False)
        self._ta_body.setStyleSheet(f"background:{BG_WIDGET};")
        body_layout = QGridLayout(self._ta_body)
        body_layout.setContentsMargins(16, 8, 16, 8)
        body_layout.setHorizontalSpacing(16)
        body_layout.setVerticalSpacing(8)
        body_layout.setColumnStretch(0, 1)
        body_layout.setColumnStretch(1, 2)
        body_layout.setColumnMinimumWidth(0, 280)
        body_layout.setColumnMinimumWidth(1, 420)

        thresh_grp = QGroupBox("Threshold (°C)")
        tg = QHBoxLayout(thresh_grp)
        tg.setSpacing(8)
        thresh_grp.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred
        )

        self._ta_enable_check = QCheckBox("Enable")
        self._ta_enable_check.setChecked(False)
        self._ta_enable_check.stateChanged.connect(self._on_temp_alert_changed)
        tg.addWidget(self._ta_enable_check)

        sep = QLabel("  |  ")
        sep.setStyleSheet(f"color:{BORDER};")
        tg.addWidget(sep)

        lbl_min = QLabel("Min:")
        lbl_min.setStyleSheet(f"color:{TEMP_TOO_LOW_COLOR}; font-weight:bold;")
        tg.addWidget(lbl_min)
        self._ta_min_field = QLineEdit("-40.0")
        self._ta_min_field.setFixedWidth(70)
        self._ta_min_field.textChanged.connect(self._on_temp_alert_changed)
        tg.addWidget(self._ta_min_field)

        lbl_max = QLabel("Max:")
        lbl_max.setStyleSheet(f"color:{TEMP_TOO_HIGH_COLOR}; font-weight:bold;")
        tg.addWidget(lbl_max)
        self._ta_max_field = QLineEdit("85.0")
        self._ta_max_field.setFixedWidth(70)
        self._ta_max_field.textChanged.connect(self._on_temp_alert_changed)
        tg.addWidget(self._ta_max_field)
        body_layout.addWidget(thresh_grp, 0, 0)

        trend_grp = QGroupBox("Moving-Window Delta (°C)")
        trg = QGridLayout(trend_grp)
        trg.setHorizontalSpacing(8)
        trg.setVerticalSpacing(4)
        trend_grp.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred
        )

        self._ta_trend_enable = QCheckBox("Enable")
        self._ta_trend_enable.setChecked(False)
        self._ta_trend_enable.stateChanged.connect(self._on_temp_alert_changed)
        trg.addWidget(self._ta_trend_enable, 0, 0)

        sep2 = QLabel("  |  ")
        sep2.setStyleSheet(f"color:{BORDER};")
        trg.addWidget(sep2, 0, 1)

        lbl_win = QLabel("Window (s):")
        lbl_win.setStyleSheet(f"color:{TEXT_SEC}; font-weight:bold;")
        trg.addWidget(lbl_win, 0, 2)
        self._ta_window_field = QLineEdit("2.0")
        self._ta_window_field.setFixedWidth(55)
        self._ta_window_field.textChanged.connect(self._on_temp_alert_changed)
        trg.addWidget(self._ta_window_field, 0, 3)

        lbl_delta = QLabel("Delta:")
        lbl_delta.setStyleSheet(f"color:{TEXT_SEC}; font-weight:bold;")
        trg.addWidget(lbl_delta, 0, 4)
        self._ta_delta_field = QLineEdit("2.0")
        self._ta_delta_field.setFixedWidth(55)
        self._ta_delta_field.textChanged.connect(self._on_temp_alert_changed)
        trg.addWidget(self._ta_delta_field, 0, 5)

        rise_check = QCheckBox("Increase")
        rise_check.setChecked(True)
        rise_check.setStyleSheet(
            f"QCheckBox {{ color:{TEMP_WIN_RISE_COLOR}; font-weight:600; }}"
        )
        rise_check.stateChanged.connect(self._on_temp_alert_changed)
        self._ta_inc_check = rise_check
        trg.addWidget(rise_check, 1, 2)

        fall_check = QCheckBox("Decrease")
        fall_check.setChecked(True)
        fall_check.setStyleSheet(
            f"QCheckBox {{ color:{TEMP_WIN_FALL_COLOR}; font-weight:600; }}"
        )
        fall_check.stateChanged.connect(self._on_temp_alert_changed)
        self._ta_dec_check = fall_check
        trg.addWidget(fall_check, 1, 3)

        delta_note = QLabel("(change from window start to end)")
        delta_note.setStyleSheet(f"color:{TEXT_SEC}; font-size:10px;")
        delta_note.setWordWrap(True)
        delta_note.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Preferred,
        )
        trg.addWidget(delta_note, 1, 4, 1, 2)
        body_layout.addWidget(trend_grp, 0, 1)

        counts_grp = QGroupBox("Violation Counts")
        cgl = QGridLayout(counts_grp)
        cgl.setContentsMargins(8, 8, 8, 8)
        cgl.setSpacing(4)
        self._ta_count_labels = {}
        for i, key in enumerate(
            ["too_high", "too_low", "win_increase", "win_decrease"]
        ):
            lbl = QLabel()
            lbl.setTextFormat(Qt.TextFormat.RichText)
            lbl.setWordWrap(True)
            self._ta_count_labels[key] = lbl
            cgl.addWidget(lbl, i // 2, i % 2)
        counts_grp.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred
        )
        body_layout.addWidget(counts_grp, 1, 0, 1, 2)

        self._update_temp_alert_summary(None)
        outer_layout.addWidget(self._ta_body)
        return outer

    def _toggle_temp_alert(self):
        visible = not self._ta_body.isVisible()
        self._ta_body.setVisible(visible)
        self._ta_toggle_btn.setText(f"{'▼' if visible else '▶'}  Temperature Alerts")

    def _ta_reset(self):
        self._ta_enable_check.setChecked(False)
        self._ta_min_field.setText("-40.0")
        self._ta_max_field.setText("85.0")
        self._ta_trend_enable.setChecked(False)
        self._ta_window_field.setText("2.0")
        self._ta_delta_field.setText("2.0")
        self._ta_inc_check.setChecked(True)
        self._ta_dec_check.setChecked(True)

    def _compute_temp_masks(self):
        if self.data is None:
            return {}
        t = self.data["t"]
        temp = self.data["temp"]
        N = len(temp)
        masks = {
            "too_high": np.zeros(N, dtype=bool),
            "too_low": np.zeros(N, dtype=bool),
            "win_increase": np.zeros(N, dtype=bool),
            "win_decrease": np.zeros(N, dtype=bool),
        }
        valid = ~np.isnan(temp)

        if self._ta_enable_check.isChecked():
            try:
                t_min = float(self._ta_min_field.text())
                t_max = float(self._ta_max_field.text())
                masks["too_low"] = valid & (temp < t_min)
                masks["too_high"] = valid & (temp > t_max)
            except ValueError:
                pass

        if self._ta_trend_enable.isChecked():
            try:
                win_sec = max(0.0, float(self._ta_window_field.text()))
                delta_thresh = max(0.0, float(self._ta_delta_field.text()))
                check_inc = self._ta_inc_check.isChecked()
                check_dec = self._ta_dec_check.isChecked()
                for i in range(N):
                    start_time = t[i] - win_sec
                    j = int(np.searchsorted(t, start_time, side="left"))
                    if i - j < 1:
                        continue
                    window = temp[j : i + 1]
                    if np.any(np.isnan(window)):
                        continue
                    delta = window[-1] - window[0]
                    if check_inc and delta >= delta_thresh:
                        masks["win_increase"][j : i + 1] = True
                    if check_dec and delta <= -delta_thresh:
                        masks["win_decrease"][j : i + 1] = True
            except ValueError:
                pass

        return masks

    def _update_temp_alert_summary(self, masks):
        if not hasattr(self, "_ta_count_labels"):
            return

        def _count_text(key):
            if masks is None:
                return "-"
            arr = masks.get(key)
            if arr is None:
                return "0"
            return str(int(np.count_nonzero(arr)))

        for key, lbl in self._ta_count_labels.items():
            spec = TEMP_ALERT_SPECS[key]
            lbl.setText(
                f"<span style='color:{TEXT_SEC}'>{spec['label']}:</span> "
                f"<b style='color:{spec['color']}'>{_count_text(key)}</b>"
            )

    def _on_temp_alert_changed(self):
        if self.data is None:
            self._update_temp_alert_summary(None)
            return
        masks = self._compute_temp_masks()
        self._update_temp_alert_summary(masks)
        self.temp_canvas.set_alert_overlays(self.data["t"], masks)
        self.traj_canvas.set_temp_masks(masks)

    #Main UI
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        header = QWidget()
        header.setFixedHeight(56)
        header.setStyleSheet(f"background:#ffffff; border-bottom:1px solid {BORDER};")
        hl = QHBoxLayout(header)
        hl.setContentsMargins(20, 0, 20, 0)
        title = QLabel("Telemetry Trajectory Visualizer")
        title.setStyleSheet("font-size:18px; font-weight:600; color:#111111;")
        hl.addWidget(title)
        hl.addStretch()
        self.file_label = QLabel("No file loaded")
        self.file_label.setStyleSheet(f"color:{TEXT_SEC}; font-size:12px;")
        hl.addWidget(self.file_label)
        hl.addSpacing(12)
        self.load_btn = QPushButton("Open CSV")
        self.load_btn.clicked.connect(self.load_csv)
        hl.addWidget(self.load_btn)
        self.process_btn = QPushButton("Process")
        self.process_btn.setEnabled(False)
        self.process_btn.clicked.connect(self.process)
        hl.addWidget(self.process_btn)
        root.addWidget(header)

        root.addWidget(self._build_noise_gate_panel())

        root.addWidget(self._build_temp_alert_panel())

        stats_bar = QWidget()
        stats_bar.setFixedHeight(42)
        stats_bar.setStyleSheet(
            f"background:#f9f9f9; border-bottom:1px solid {BORDER};"
        )
        sl = QHBoxLayout(stats_bar)
        sl.setContentsMargins(16, 0, 16, 0)
        sl.setSpacing(8)
        self.stats = {
            "Duration": StatLabel("Duration", "s"),
            "Samples": StatLabel("Samples", ""),
            "Max Speed": StatLabel("Max Speed", "m/s"),
            "Max Accel": StatLabel("Max Accel", "m/s²"),
            "Temp": StatLabel("Avg Temp", "°C"),
        }
        for s in self.stats.values():
            sl.addWidget(s)
        sl.addStretch()

        self.car_check = QCheckBox("Show Car Model")
        self.car_check.setChecked(True)
        self.car_check.stateChanged.connect(
            lambda v: self.traj_canvas.set_show_car(bool(v))
        )
        sl.addWidget(self.car_check)
        root.addWidget(stats_bar)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(4)

        left = QWidget()
        ll = QVBoxLayout(left)
        ll.setContentsMargins(8, 8, 4, 8)
        grp = QGroupBox("3D Trajectory")
        gl = QVBoxLayout(grp)
        self.traj_canvas = TrajectoryCanvas()
        self.traj_toolbar = NavigationToolbar(self.traj_canvas, self)
        self.traj_toolbar.setStyleSheet(f"background:{BG_PANEL};")
        gl.addWidget(self.traj_toolbar)
        gl.addWidget(self.traj_canvas)

        anim_bar = QWidget()
        anim_bar.setStyleSheet(
            f"background:{BG_WIDGET}; border-top:1px solid {BORDER};"
        )
        al = QHBoxLayout(anim_bar)
        al.setContentsMargins(8, 4, 8, 4)
        al.setSpacing(8)

        self.anim_play_btn = QPushButton("▶  Play")
        self.anim_play_btn.setEnabled(False)
        self.anim_play_btn.clicked.connect(self._anim_play_pause)
        al.addWidget(self.anim_play_btn)

        self.anim_reset_btn = QPushButton("⏮")
        self.anim_reset_btn.setEnabled(False)
        self.anim_reset_btn.setFixedWidth(38)
        self.anim_reset_btn.clicked.connect(self._anim_reset)
        al.addWidget(self.anim_reset_btn)

        self.view_reset_btn = QPushButton("⌂")
        self.view_reset_btn.setToolTip("Reset camera to default view")
        self.view_reset_btn.setFixedWidth(38)
        self.view_reset_btn.clicked.connect(self.traj_canvas.reset_view)
        al.addWidget(self.view_reset_btn)

        self.anim_slider = QSlider(Qt.Orientation.Horizontal)
        self.anim_slider.setMinimum(1)
        self.anim_slider.setMaximum(100)
        self.anim_slider.setValue(100)
        self.anim_slider.setEnabled(False)
        self.anim_slider.sliderMoved.connect(self._anim_scrub)
        al.addWidget(self.anim_slider, 1)

        spd_lbl = QLabel("Speed:")
        spd_lbl.setStyleSheet(f"color:{TEXT_SEC}; font-size:12px;")
        al.addWidget(spd_lbl)

        self.anim_speed_combo = QComboBox()
        self.anim_speed_combo.addItems(["0.25×", "0.5×", "1×", "2×", "4×"])
        self.anim_speed_combo.setCurrentIndex(2)
        self.anim_speed_combo.setFixedWidth(70)
        self.anim_speed_combo.currentIndexChanged.connect(self._anim_set_speed)
        al.addWidget(self.anim_speed_combo)

        gl.addWidget(anim_bar)
        ll.addWidget(grp)
        splitter.addWidget(left)

        right = QWidget()
        rl = QVBoxLayout(right)
        rl.setContentsMargins(4, 8, 8, 8)
        self.tabs = QTabWidget()
        self.accel_canvas = SensorCanvas(
            "Accelerometer", ["ax", "ay", "az"], [ACCENT2, ACCENT3, ACCENT]
        )
        self.tabs.addTab(self._canvas_tab(self.accel_canvas), "Accel")
        self.gyro_canvas = SensorCanvas(
            "Gyroscope", ["gx", "gy", "gz"], ["#cc3333", "#33aa33", "#3366cc"]
        )
        self.tabs.addTab(self._canvas_tab(self.gyro_canvas), "Gyro")
        self.speed_canvas = SensorCanvas(
            "Dead-Reckoning Speed",
            ["Vx", "Vy", "Vz", "|V|"],
            [ACCENT2, ACCENT3, ACCENT, "#111111"],
        )
        self.tabs.addTab(self._canvas_tab(self.speed_canvas), "Speed")
        self.temp_canvas = SensorCanvas("Temperature", ["Temp"], [WARN])
        self.tabs.addTab(self._canvas_tab(self.temp_canvas), "Temp")
        rl.addWidget(self.tabs)
        self.tabs.currentChanged.connect(self._on_tab_changed)

        splitter.addWidget(right)
        splitter.setSizes([600, 560])
        splitter.setCollapsible(0, False)
        splitter.setCollapsible(1, False)
        root.addWidget(splitter, 1)

        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status.showMessage("Ready — open a CSV file to begin")

    def _canvas_tab(self, canvas):
        w = QWidget()
        l = QVBoxLayout(w)
        l.setContentsMargins(4, 4, 4, 4)
        l.setSpacing(2)
        tb = NavigationToolbar(canvas, self)
        tb.setStyleSheet(f"background:{BG_PANEL};")
        l.addWidget(tb)
        l.addWidget(canvas, 1)

        if len(canvas.channels) > 1:
            cb_bar = QWidget()
            cb_bar.setStyleSheet(
                f"background:{BG_WIDGET}; border-top:1px solid {BORDER};"
            )
            cb_layout = QHBoxLayout(cb_bar)
            cb_layout.setContentsMargins(8, 4, 8, 4)
            cb_layout.setSpacing(16)
            lbl = QLabel("Show:")
            lbl.setStyleSheet(f"color:{TEXT_SEC}; font-size:11px;")
            cb_layout.addWidget(lbl)
            for channel, color in zip(canvas.channels, canvas.colors):
                cb = QCheckBox(channel)
                cb.setChecked(True)
                cb.setStyleSheet(
                    f"""
                    QCheckBox {{ color:{color}; font-size:12px; font-weight:600; }}
                    QCheckBox::indicator {{ width:13px; height:13px; border:1px solid {color}; border-radius:2px; background:#ffffff; }}
                    QCheckBox::indicator:checked {{ background:{color}; border-color:{color}; }}
                """
                )
                cb.stateChanged.connect(
                    lambda state, c=channel, cv=canvas: cv.set_channel_visible(
                        c, bool(state)
                    )
                )
                cb_layout.addWidget(cb)
            cb_layout.addStretch()
            l.addWidget(cb_bar)
        return w

    def load_csv(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Open Telemetry CSV", "", "CSV Files (*.csv);;All Files (*)"
        )
        if not path:
            return
        try:
            self.df = pd.read_csv(path)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to read CSV:\n{e}")
            return
        self.file_label.setText(Path(path).name)
        self.status.showMessage(
            f"Loaded {len(self.df)} rows × {len(self.df.columns)} columns — map columns to continue"
        )
        self.col_dialog = ColumnMapDialog(self.df.columns, self)
        self.col_dialog.mappingConfirmed.connect(self._on_mapping)
        self.col_dialog.show()

    def _on_mapping(self, col_map):
        self.col_map = col_map
        self.process_btn.setEnabled(True)
        self.status.showMessage(
            "Column mapping set — click Process to compute trajectory"
        )

    def process(self):
        if self.df is None or not self.col_map:
            return
        try:
            proc = TelemetryProcessor(self.df, self.col_map)
            self.data = proc.compute(
                noise_gates=self._get_noise_gates(),
                median_kernels=self._get_median_kernels(),
            )
        except Exception as e:
            QMessageBox.critical(self, "Processing Error", str(e))
            return
        self._update_stats()
        self._plot_all()
        self._anim_enable()
        self.status.showMessage(
            f"Trajectory computed — {len(self.data['t'])} samples  |  GPS: {'yes' if self.data['has_gps'] else 'no'}"
        )

    def _update_stats(self):
        d = self.data
        self.stats["Duration"].setValue(d["t"][-1] - d["t"][0])
        n_raw = len(self.df)
        n_proc = len(d["t"])
        if n_proc != n_raw:
            self.stats["Samples"].setIntValue(n_proc, note=f"↑{n_raw}")
        else:
            self.stats["Samples"].setIntValue(n_proc)
        self.stats["Max Speed"].setValue(np.max(d["speed"]))
        self.stats["Max Accel"].setValue(
            np.max(np.sqrt(d["ax"] ** 2 + d["ay"] ** 2 + d["az"] ** 2))
        )
        if not np.all(np.isnan(d["temp"])):
            self.stats["Temp"].setValue(np.nanmean(d["temp"]))

    def _plot_all(self):
        d = self.data
        self.traj_canvas.plot(d, show_gps=False)
        self.accel_canvas.plot(d["t"], [d["ax"], d["ay"], d["az"]], ["ax", "ay", "az"])
        self.gyro_canvas.plot(d["t"], [d["gx"], d["gy"], d["gz"]], ["gx", "gy", "gz"])
        self.speed_canvas.plot(
            d["t"], [d["vx"], d["vy"], d["vz"], d["speed"]], ["Vx", "Vy", "Vz", "|V|"]
        )
        self.temp_canvas.plot(d["t"], [d["temp"]], ["Temp"])
        self._on_temp_alert_changed()
        is_temp = self.tabs.tabText(self.tabs.currentIndex()) == "Temp"
        self.traj_canvas.set_temp_mode(is_temp)

    def _anim_enable(self):
        total = self.traj_canvas._anim_total
        self.anim_slider.setMaximum(total)
        self.anim_slider.setValue(total)
        self.anim_play_btn.setEnabled(True)
        self.anim_reset_btn.setEnabled(True)
        self.anim_slider.setEnabled(True)
        self._anim_frame = total

    def _anim_play_pause(self):
        if self._anim_timer.isActive():
            self._anim_timer.stop()
            self.anim_play_btn.setText("▶  Play")
        else:
            if self._anim_frame >= self.traj_canvas._anim_total:
                self._anim_frame = 1
            self._anim_timer.start(33)
            self.anim_play_btn.setText("⏸  Pause")

    def _anim_reset(self):
        self._anim_timer.stop()
        self.anim_play_btn.setText("▶  Play")
        self._anim_frame = 1
        self.anim_slider.setValue(1)
        self.traj_canvas.anim_step(1)
        self._update_sensor_playhead(1)

    def _anim_tick(self):
        total = self.traj_canvas._anim_total
        self._anim_frame += self._anim_speed
        if self._anim_frame >= total:
            self._anim_frame = total
            self._anim_timer.stop()
            self.anim_play_btn.setText("▶  Play")
        self.anim_slider.setValue(self._anim_frame)
        self.traj_canvas.anim_step(self._anim_frame)
        self._update_sensor_playhead(self._anim_frame)

    def _anim_scrub(self, val):
        if self._anim_timer.isActive():
            self._anim_timer.stop()
            self.anim_play_btn.setText("▶  Play")
        self._anim_frame = val
        self.traj_canvas.anim_step(val)
        self._update_sensor_playhead(val)

    def _update_sensor_playhead(self, frame):
        if self.data is None:
            return
        total = self.traj_canvas._anim_total
        N = len(self.data["t"])
        data_idx = int(round(frame / max(total, 1) * (N - 1)))
        data_idx = max(0, min(data_idx, N - 1))
        t_val = self.data["t"][data_idx]
        for canvas in (
            self.accel_canvas,
            self.gyro_canvas,
            self.speed_canvas,
            self.temp_canvas,
        ):
            canvas.set_playhead(t_val)

    def _on_tab_changed(self, index):
        is_temp = self.tabs.tabText(index) == "Temp"
        self.traj_canvas.set_temp_mode(is_temp)

    def _anim_set_speed(self, idx):
        self._anim_speed = [1, 2, 5, 10, 20][idx]


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    win = MainWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
