#!/usr/bin/env python3

import sys
import csv
import json
import os
from datetime import datetime, timezone, date
from zoneinfo import ZoneInfo
from pathlib import Path

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QFileDialog, QSplitter, QTableWidget,
    QTableWidgetItem, QHeaderView, QStatusBar, QGroupBox,
)
from PyQt6.QtWebEngineWidgets import QWebEngineView
from PyQt6.QtCore import Qt, QUrl


def parse_hex(s: str) -> int:
    s = s.strip()
    return int(s, 16) if s.startswith(("0x", "0X")) else int(s)


TORONTO_TZ = ZoneInfo("America/Toronto")
_TODAY = date.today()

def decode_timestamp(hex_val: int) -> str:
    if hex_val == 0:
        return "-"
    ms  = hex_val % 1000;  rem = hex_val // 1000
    ss  = rem % 100;       rem //= 100
    mm  = rem % 100;       hh  = rem // 100
    utc_dt = datetime(_TODAY.year, _TODAY.month, _TODAY.day,
                      hh % 24, mm, ss, ms * 1000, tzinfo=timezone.utc)
    local_dt = utc_dt.astimezone(TORONTO_TZ)
    return local_dt.strftime("%H:%M:%S.") + f"{local_dt.microsecond // 1000:03d}"


def decode_gps(hex_val: int, is_longitude: bool = False) -> float | None:
    if hex_val == 0:
        return None
    degrees = hex_val // 1000000
    minutes = (hex_val % 1000000) / 10000.0
    dd = degrees + minutes / 60.0
    return -dd if is_longitude else dd


def load_telemetry(filepath: str) -> list[dict]:
    rows = []
    with open(filepath, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                lat = decode_gps(parse_hex(row["gps_latitude"]))
                lon = decode_gps(parse_hex(row["gps_longitude"]), is_longitude=True)
                ts  = decode_timestamp(parse_hex(row["gps_utc_time"]))
                rows.append({
                    "frame":   int(row["frame_num"]),
                    "ts":      ts,
                    "lat":     lat,
                    "lon":     lon,
                    "has_gps": lat is not None and lon is not None,
                })
            except (ValueError, KeyError):
                continue
    return rows

MAP_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body, #map {{ width:100%; height:100%; background:#ffffff; }}
  .leaflet-popup-content-wrapper {{
    background:#ffffff; color:#111111;
    border:1px solid #dddddd; border-radius:4px;
    font-family:'Segoe UI',Arial,sans-serif; font-size:12px;
    box-shadow:0 2px 8px rgba(0,0,0,0.1);
  }}
  .leaflet-popup-tip {{ background:#ffffff; }}
  .leaflet-popup-content {{ margin:10px 14px; line-height:1.7; }}
  .lbl {{ color:#888888; font-size:10px; text-transform:uppercase; letter-spacing:0.4px; }}
  .val {{ color:#111111; font-weight:600; }}
</style>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>
<div id="map"></div>
<script>
const POINTS     = {points_json};
const TRAJECTORY = {trajectory_json};

const map = L.map('map', {{ zoomControl:true, attributionControl:false }});
L.tileLayer('https://{{s}}.basemaps.cartocdn.com/light_all/{{z}}/{{x}}/{{y}}{{r}}.png', {{
  maxZoom:20, subdomains:'abcd'
}}).addTo(map);

if (TRAJECTORY.length > 1) {{
  L.polyline(TRAJECTORY, {{ color:'#2980b9', weight:3, opacity:0.8, lineJoin:'round' }}).addTo(map);
}}

const mkIcon = (color, size) => L.divIcon({{
  className:'',
  html:`<div style="width:${{size}}px;height:${{size}}px;border-radius:50%;
        background:${{color}};border:2px solid white;
        box-shadow:0 1px 4px rgba(0,0,0,0.3);"></div>`,
  iconSize:[size,size], iconAnchor:[size/2,size/2]
}});

const iconNormal = mkIcon('#27ae60', 8);
const iconStart  = mkIcon('#e8761a', 14);
const iconEnd    = mkIcon('#9b59b6', 14);

POINTS.forEach((p, i) => {{
  const icon = i === 0 ? iconStart : (i === POINTS.length - 1 ? iconEnd : iconNormal);
  const popup = `<div>
    <div class="lbl">Frame</div><div class="val">#${{p.frame}}</div>
    <hr style="border-color:#eeeeee;margin:5px 0"/>
    <div class="lbl">Timestamp</div><div class="val">${{p.ts}}</div>
    <hr style="border-color:#eeeeee;margin:5px 0"/>
    <div class="lbl">Latitude</div><div class="val">${{p.lat.toFixed(6)}}°</div>
    <div class="lbl">Longitude</div><div class="val">${{p.lon.toFixed(6)}}°</div>
  </div>`;
  L.marker([p.lat, p.lon], {{icon}}).addTo(map).bindPopup(popup);
}});

if (TRAJECTORY.length > 0)
  map.fitBounds(L.latLngBounds(TRAJECTORY).pad(0.15));
</script>
</body>
</html>
"""


def build_map_html(rows: list[dict]) -> str:
    gps = [r for r in rows if r["has_gps"]]
    points     = [{"frame": r["frame"], "ts": r["ts"], "lat": r["lat"], "lon": r["lon"]} for r in gps]
    trajectory = [[r["lat"], r["lon"]] for r in gps]
    return MAP_HTML.format(
        points_json=json.dumps(points),
        trajectory_json=json.dumps(trajectory),
    )

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

QLabel#title    { font-size:18px; font-weight:600; color:#111111; }
QLabel#subtitle { font-size:12px; color:#777777; }

QGroupBox {
  border:1px solid #dddddd; border-radius:4px; margin-top:10px; padding:6px;
  font-size:11px; color:#777777;
}
QGroupBox::title { subcontrol-origin:margin; left:8px; padding:0 4px; color:#777777; }

QTableWidget {
  background:#ffffff; border:1px solid #dddddd; border-radius:4px;
  gridline-color:#eeeeee; font-size:12px;
}
QTableWidget::item { padding:4px 8px; color:#111111; }
QTableWidget::item:selected { background:#e8f0fe; color:#111111; }
QHeaderView::section {
  background:#f9f9f9; color:#555555; border:none;
  border-bottom:1px solid #dddddd; padding:6px 8px;
  font-size:11px; font-weight:600;
}
QStatusBar {
  background:#f9f9f9; color:#777777;
  border-top:1px solid #dddddd; font-size:11px;
}
QSplitter::handle { background:#dddddd; width:4px; height:4px; }
QSplitter::handle:hover { background:#aaaaaa; }
"""

class TelemetryViewer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.rows: list[dict] = []
        self._setup_ui()

    def _setup_ui(self):
        self.setWindowTitle("Telemetry GPS Viewer")
        self.setMinimumSize(1100, 700)
        self.setStyleSheet(STYLE)

        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        header = QWidget()
        header.setFixedHeight(64)
        header.setStyleSheet("background:#ffffff; border-bottom:1px solid #dddddd;")
        hl = QHBoxLayout(header)
        hl.setContentsMargins(20, 0, 20, 0)

        title = QLabel("Telemetry GPS Viewer")
        title.setObjectName("title")
        self.subtitle = QLabel("No file loaded")
        self.subtitle.setObjectName("subtitle")

        open_btn = QPushButton("Open CSV")
        open_btn.setObjectName("primary")
        open_btn.setFixedWidth(110)
        open_btn.clicked.connect(self.open_file)

        hl.addWidget(title)
        hl.addSpacing(16)
        hl.addWidget(self.subtitle)
        hl.addStretch()
        hl.addWidget(open_btn)
        root.addWidget(header)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(1)

        self.map_view = QWebEngineView()
        self.map_view.setMinimumWidth(400)
        self._load_empty_map()
        splitter.addWidget(self.map_view)

        side = QWidget()
        side.setMinimumWidth(220)
        side.setStyleSheet("background:#ffffff;")
        side_layout = QVBoxLayout(side)
        side_layout.setContentsMargins(12, 12, 12, 12)
        side_layout.setSpacing(12)

        legend = QGroupBox("Legend")
        ll = QVBoxLayout(legend)
        ll.setSpacing(6)
        ll.setContentsMargins(10, 16, 10, 10)
        for color, label in [
            ("#e8761a", "Start point"),
            ("#9b59b6", "End point"),
            ("#27ae60", "GPS point"),
            ("#2980b9", "Trajectory"),
        ]:
            row_w = QWidget()
            rh = QHBoxLayout(row_w)
            rh.setContentsMargins(0, 0, 0, 0)
            dot = QLabel("●")
            dot.setStyleSheet(f"color:{color}; font-size:16px;")
            lbl = QLabel(label)
            lbl.setStyleSheet("font-size:12px; color:#111111;")
            rh.addWidget(dot)
            rh.addWidget(lbl)
            rh.addStretch()
            ll.addWidget(row_w)
        side_layout.addWidget(legend)

        tbl_group = QGroupBox("GPS Frames")
        tbl_vl = QVBoxLayout(tbl_group)
        tbl_vl.setContentsMargins(4, 16, 4, 4)

        self.table = QTableWidget()
        self.table.setColumnCount(3)
        self.table.setHorizontalHeaderLabels(["Frame", "Latitude", "Longitude"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        tbl_vl.addWidget(self.table)
        side_layout.addWidget(tbl_group, stretch=1)

        splitter.addWidget(side)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([800, 300])
        splitter.setCollapsible(0, False)
        splitter.setCollapsible(1, False)
        root.addWidget(splitter, stretch=1)

        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status.showMessage("Ready — open a telemetry CSV to begin")

    def _load_empty_map(self):
        self.map_view.setHtml("""<!DOCTYPE html><html><head><meta charset="utf-8"/>
<style>
  html,body { margin:0; background:#ffffff; display:flex; align-items:center;
    justify-content:center; height:100vh; font-family:'Segoe UI',Arial,sans-serif; }
  .msg { color:#cccccc; text-align:center; }
  .icon { font-size:56px; margin-bottom:12px; }
  .text { font-size:16px; font-weight:400; color:#aaaaaa; }
</style></head><body>
<div class="msg">
  <div class="icon">&#x1F5FA;</div>
  <div class="text">Open a CSV file to view the GPS trajectory</div>
</div>
</body></html>""")

    def open_file(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Open Telemetry CSV", str(Path.home()),
            "CSV Files (*.csv);;All Files (*)"
        )
        if path:
            self.load_file(path)

    def load_file(self, path: str):
        try:
            self.rows = load_telemetry(path)
        except Exception as e:
            self.status.showMessage(f"Error: {e}")
            return

        gps_rows = [r for r in self.rows if r["has_gps"]]
        valid_ts = [r for r in self.rows if r["ts"] != "-"]
        time_str = ""
        if valid_ts:
            time_str = f"  ·  {valid_ts[0]['ts']} → {valid_ts[-1]['ts']}"
        self.subtitle.setText(
            f"{Path(path).name}  ·  {len(self.rows)} frames  ·  {len(gps_rows)} GPS fixes{time_str}"
        )

        self.map_view.setHtml(build_map_html(self.rows), QUrl("about:blank"))

        self.table.setRowCount(len(gps_rows))
        for i, r in enumerate(gps_rows):
            self.table.setItem(i, 0, QTableWidgetItem(str(r["frame"])))
            self.table.setItem(i, 1, QTableWidgetItem(f"{r['lat']:.6f}"))
            self.table.setItem(i, 2, QTableWidgetItem(f"{r['lon']:.6f}"))

        self.status.showMessage(
            f"Loaded {len(self.rows)} frames · {len(gps_rows)} GPS points"
        )

def main():
    os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--no-sandbox")
    app = QApplication(sys.argv)
    app.setApplicationName("Telemetry GPS Viewer")
    win = TelemetryViewer()
    if len(sys.argv) > 1 and Path(sys.argv[1]).exists():
        win.load_file(sys.argv[1])
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()