"""
Convert raw telemetry CSV to the format expected by telemetry_gui.py.

Timestamp format (hex value decoded as positional decimal digits):
  rightmost 3 digits = milliseconds (0-999)
  next 2 digits      = seconds      (0-59)
  next 2 digits      = minutes      (0-59)
  remaining digits   = hours

e.g. 0x0014B3FF = 1356799 decimal → "1356799"
  mmm = 799 ms
  ss  =  56 s
  mm  =  13 min
  hh  =   0 h
  → total elapsed = 0h 13m 56s 799ms

Verified: consecutive timestamps 1355799→1356799→...→1359799→1400799
decode to 835799→836799→...→839799→840799 ms — each exactly +1000ms,
correctly handling the MM:SS rollover from 13:59 → 14:00.
"""

import pandas as pd
import numpy as np
import sys
from pathlib import Path

# Acceleration: 1 raw unit = 4 milli-g = 4e-3 * 9.81 m/s²
ACCEL_SCALE = (9.81 / 1000) * 4
ACCEL_X_BIAS_RAW = 60
ACCEL_Y_BIAS_RAW = 39
ACCEL_Z_BIAS_RAW = -57

# Gyroscope: degrees/s → rad/s
DEG2RAD = np.pi / 180.0
GYRO_SCALE = 0.00762963 # 250/32767

def hex_ts_to_ms(hex_str: str) -> float:
    """
    Decode hex timestamp to total milliseconds using positional decimal digit spec:
      right 3 digits = ms, next 2 = seconds, next 2 = minutes, rest = hours.
    """
    val = int(hex_str, 16)
    s   = str(val)
    mmm = int(s[-3:])        if len(s) >= 3 else int(s)
    ss  = int(s[-5:-3])      if len(s) >= 5 else 0
    mm  = int(s[-7:-5])      if len(s) >= 7 else (int(s[:-5]) if len(s) > 5 else 0)
    hh  = int(s[:-7])        if len(s) >  7 else 0
    return float(((hh * 60 + mm) * 60 + ss) * 1000 + mmm)


def convert(input_path: str, output_path: str):
    df = pd.read_csv(input_path)
    df.columns = df.columns.str.strip()
    n = len(df)

    # ── 1. Decode timestamps ──────────────────────────────────────────────────
    raw_ts_ms = df["gps_utc_time"].apply(hex_ts_to_ms).values

    # Interpolate time for frames sharing the same timestamp.
    # Each group of identical timestamps spans [ts_start, ts_next).
    # Frames within a group are spread evenly across that interval.
    elapsed_s = np.zeros(n)
    t0 = raw_ts_ms[0]

    i = 0
    while i < n:
        # Find end of current group (run of identical timestamps)
        j = i + 1
        while j < n and raw_ts_ms[j] == raw_ts_ms[i]:
            j += 1

        # Interval end: next distinct timestamp, or extrapolate for last group
        if j < n:
            group_end_ms = raw_ts_ms[j]
        else:
            # Last group: use the previous interval length, or 1000ms fallback
            prev_distinct = next(
                (raw_ts_ms[k] for k in range(i - 1, -1, -1)
                 if raw_ts_ms[k] != raw_ts_ms[i]),
                None
            )
            interval = (raw_ts_ms[i] - prev_distinct) if prev_distinct is not None else 1000.0
            group_end_ms = raw_ts_ms[i] + interval

        group_size = j - i
        for k in range(group_size):
            frac = k / group_size  # 0, 1/n, 2/n, ...
            interp_ms = raw_ts_ms[i] + frac * (group_end_ms - raw_ts_ms[i])
            elapsed_s[i + k] = (interp_ms - t0) / 1000.0

        i = j

    # ── 2. Scale sensor values ────────────────────────────────────────────────
    
    print((df["accel_z"].astype(float) - ACCEL_Z_BIAS_RAW) * ACCEL_SCALE)
    
    accel_x = (df["accel_x"].astype(float) - ACCEL_X_BIAS_RAW) * ACCEL_SCALE
    accel_y = (df["accel_y"].astype(float) - ACCEL_Y_BIAS_RAW) * ACCEL_SCALE
    accel_z = (df["accel_z"].astype(float) - ACCEL_Z_BIAS_RAW) * ACCEL_SCALE

    gyro_x = df["gyro_x"].astype(float) * GYRO_SCALE * DEG2RAD
    gyro_y = df["gyro_y"].astype(float) * GYRO_SCALE * DEG2RAD
    gyro_z = df["gyro_z"].astype(float) * GYRO_SCALE * DEG2RAD

    # ── 3. Temperature ────────────────────────────────────────────────────────
    DEFAULT_TEMP = 25.0
    if "temp" in df.columns:
        temp = df["temp"].astype(float)
        if (temp == 0).all():
            temp = np.full(n, DEFAULT_TEMP)
            temp_note = f"all-zero → substituted {DEFAULT_TEMP}°C"
        else:
            temp_note = f"{temp.min():.1f} … {temp.max():.1f} °C"
    else:
        temp = np.full(n, DEFAULT_TEMP)
        temp_note = f"column absent → substituted {DEFAULT_TEMP}°C"

    # ── 4. GPS (not available) ────────────────────────────────────────────────
    lat = np.full(n, np.nan)
    lon = np.full(n, np.nan)
    alt = np.full(n, np.nan)

    # ── 4. Assemble and write output ──────────────────────────────────────────
    out = pd.DataFrame({
        "time":        np.round(elapsed_s, 4),
        "accel_x":     np.round(accel_x, 5),
        "accel_y":     np.round(accel_y, 5),
        "accel_z":     np.round(accel_z, 5),
        "gyro_x":      np.round(gyro_x, 5),
        "gyro_y":      np.round(gyro_y, 5),
        "gyro_z":      np.round(gyro_z, 5),
        "latitude":    lat,
        "longitude":   lon,
        "altitude":    alt,
        "temperature": np.round(temp, 3),
    })
    out.to_csv(output_path, index=False)

    # ── 5. Summary ────────────────────────────────────────────────────────────
    print(f"Converted {n} frames → {output_path}")
    print(f"  Duration : {elapsed_s[-1]:.3f} s")
    print(f"  Accel X  : {accel_x.min():.3f} … {accel_x.max():.3f} m/s²")
    print(f"  Accel Y  : {accel_y.min():.3f} … {accel_y.max():.3f} m/s²")
    print(f"  Accel Z  : {accel_z.min():.3f} … {accel_z.max():.3f} m/s²")
    print(f"  Gyro X   : {np.degrees(gyro_x.min()):.1f} … {np.degrees(gyro_x.max()):.1f} °/s  "
          f"({gyro_x.min():.3f} … {gyro_x.max():.3f} rad/s)")
    print(f"  Gyro Y   : {np.degrees(gyro_y.min()):.1f} … {np.degrees(gyro_y.max()):.1f} °/s")
    print(f"  Gyro Z   : {np.degrees(gyro_z.min()):.1f} … {np.degrees(gyro_z.max()):.1f} °/s")
    print(f"  Temp     : {temp_note}")

    print(f"\n  Time column sample (first 14 rows):")
    for idx in range(min(14, n)):
        print(f"    frame {df['frame_num'].iloc[idx]:3d}  "
              f"raw_ms={raw_ts_ms[idx]:.0f}  elapsed={elapsed_s[idx]:.4f} s")


if __name__ == "__main__":
    if len(sys.argv) == 3:
        inp, out = sys.argv[1], sys.argv[2]
    elif len(sys.argv) == 2:
        inp = sys.argv[1]
        out = str(Path(inp).stem) + "_converted.csv"
    else:
        print("Usage: python convert_telemetry.py <input.csv> [output.csv]")
        sys.exit(1)
    convert(inp, out)