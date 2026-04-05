#!/usr/bin/env python3
"""
Bluetooth UART receiver decodes packets into a CSV file
run with:
    python bluetooth_receiver_packet_test.py
"""

import os
import csv
import struct
import signal
import sys
import time
from datetime import datetime

import serial

# config stuff
PORT            = os.environ.get("BT_PORT", "COM5")
BAUD            = int(os.environ.get("BT_BAUD", "9600"))
OUTPUT          = os.environ.get("BT_OUTPUT", f"packets_{datetime.now():%Y%m%d_%H%M%S}.csv")
NO_DATA_TIMEOUT = float(os.environ.get("BT_TIMEOUT", "2.0"))   # seconds before reconnect attempt
RECONNECT_DELAY = float(os.environ.get("BT_RECONNECT_DELAY", "2.0"))  # seconds between retries

# constants
SYNC         = bytes([0x55, 0xAA])
PACKET_WORDS = 10
FRAME_LEN    = 2 + PACKET_WORDS * 4   # 42 bytes

CSV_COLUMNS = [
    "frame_num",
    "gps_utc_time",
    "gps_latitude",
    "gps_longitude",
    "gps_north",
    "gps_east",
    "gps_ground_speed",
    "accel_x",
    "accel_y",
    "accel_z",
    "gyro_x",
    "gyro_y",
    "gyro_z",
    "temp",
    "crash",
]


# signed 16 bit conversion
def to_signed16(val: int) -> int:
    """Convert unsigned 16-bit value to signed."""
    if val >= 0x8000:
        return val - 0x10000
    return val

# signed 12 bit conversion
def to_signed12(val: int) -> int:
    """Convert unsigned 12-bit value to signed."""
    val &= 0xFFF
    if val >= 0x800:
        return val - 0x1000
    return val


# packet decoder
def decode_packet(frame_num: int, words: list[int]) -> dict:
    """
    decode words into fields, word 0 is first written
    """
    # word 0
    # temperature is [15:3]
    temp = ((words[0] & 0xFFFA) >> 3) / 16

    # word 1 gyro_y [31:16], gyro_x [15:0]
    gyro_x = to_signed16(words[1] & 0xFFFF)
    gyro_y = to_signed16((words[1] >> 16) & 0xFFFF)

    # word 2 gyro_z [15:0]
    gyro_z = to_signed16(words[2] & 0xFFFF)

    # word 3 accel_y [31:16] accel_x [15:0]
    accel_x = to_signed12(words[3] & 0xFFF)
    accel_y = to_signed12((words[3] >> 16) & 0xFFF)

    # word 4 accel_z [15:0]
    accel_z = to_signed12(words[4] & 0xFFF)

    # word 5 gps_ground_speed
    gps_ground_speed = words[5]

    # word 6, crash[31], 29'b0, north[1], east[0]
    gps_east  = words[6] & 0x1
    gps_north = (words[6] >> 1) & 0x1
    crash     = "CRASH" if (words[6] >> 31) & 0x1 else "no crash"

    # word 7 gps_longitude
    gps_longitude = words[7]

    # word 8 gps_latitude
    gps_latitude = words[8]

    # word 9 gps_utc_time
    gps_utc_time = words[9]

    return {
        "frame_num":        frame_num,
        "gps_utc_time":     f"0x{gps_utc_time:08X}",
        "gps_latitude":     f"0x{gps_latitude:08X}",
        "gps_longitude":    f"0x{gps_longitude:08X}",
        "gps_north":        gps_north,
        "gps_east":         gps_east,
        "gps_ground_speed": f"0x{gps_ground_speed:08X}",
        "accel_x":          accel_x,
        "accel_y":          accel_y,
        "accel_z":          accel_z,
        "gyro_x":           gyro_x,
        "gyro_y":           gyro_y,
        "gyro_z":           gyro_z,
        "temp":             temp,
        "crash":            crash,
    }


# frame parser
class FrameParser:
    def __init__(self):
        self._buf = bytearray()
        self.frame_count = 0

    def feed(self, data: bytes) -> list[dict]:
        self._buf.extend(data)
        frames = []

        while True:
            idx = self._buf.find(SYNC)
            if idx == -1:
                if len(self._buf) > 1:
                    self._buf = self._buf[-1:]
                break
            if idx > 0:
                self._buf = self._buf[idx:]
            if len(self._buf) < FRAME_LEN:
                break

            raw = bytes(self._buf[:FRAME_LEN])
            self._buf = self._buf[FRAME_LEN:]

            words = list(struct.unpack_from("<10I", raw, 2))
            self.frame_count += 1
            frames.append({"num": self.frame_count, "words": words})

        return frames


# main
def open_port():
    """try to open the serial port"""
    try:
        ser = serial.serial_for_url(PORT, baudrate=BAUD, timeout=0.5)
        print(f"Opened {PORT} at {BAUD} baud")
        return ser
    except serial.SerialException as e:
        print(f"RECONNECT: Could not open {PORT}: {e}")
        return None


def main():
    ser = None
    while ser is None:
        ser = open_port()
        if ser is None:
            time.sleep(RECONNECT_DELAY)

    parser = FrameParser()

    csvfile = open(OUTPUT, "w", newline="")
    writer = csv.DictWriter(csvfile, fieldnames=CSV_COLUMNS)
    writer.writeheader()

    print(f"Writing to {OUTPUT}")
    print("Waiting for frames\n")
    print(f"{'Frame':>7}  {'UTC Time':>10}  {'Lat':>10}  {'Lon':>10}  "
          f"{'N':>1} {'E':>1}  {'Speed':>10}  "
          f"{'AX':>6} {'AY':>6} {'AZ':>6}  "
          f"{'GX':>6} {'GY':>6} {'GZ':>6}  {'Temp':>6}  {'Crash':>8}")
    print("-" * 125)

    def shutdown(*_):
        csvfile.close()
        try:
            ser.close()
        except Exception:
            pass
        print(f"\nDone. {parser.frame_count} frames saved to {OUTPUT}")
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)

    last_data_time = time.monotonic()

    while True:
        # reconnect if no data received for too long
        if time.monotonic() - last_data_time > NO_DATA_TIMEOUT:
            print(f"RECONNECT: No data for {NO_DATA_TIMEOUT}s, reopening {PORT}...")
            try:
                ser.close()
            except Exception:
                pass
            ser = None
            while ser is None:
                time.sleep(RECONNECT_DELAY)
                ser = open_port()
            last_data_time = time.monotonic()
            continue

        # normal read
        try:
            chunk = ser.read(ser.in_waiting or 1)
        except serial.SerialException as e:
            print(f"RECONNECT: Read error ({e}), will reopen port")
            try:
                ser.close()
            except Exception:
                pass
            ser = None
            while ser is None:
                time.sleep(RECONNECT_DELAY)
                ser = open_port()
            last_data_time = time.monotonic()
            continue

        if not chunk:
            continue

        last_data_time = time.monotonic()

        for f in parser.feed(chunk):
            row = decode_packet(f["num"], f["words"])
            writer.writerow(row)
            csvfile.flush()

            # Pretty-print to terminal
            print(f"{row['frame_num']:>7}  "
                  f"{row['gps_utc_time']:>10}  "
                  f"{row['gps_latitude']:>10}  "
                  f"{row['gps_longitude']:>10}  "
                  f"{row['gps_north']:>1} {row['gps_east']:>1}  "
                  f"{row['gps_ground_speed']:>10}  "
                  f"{row['accel_x']:>6} {row['accel_y']:>6} {row['accel_z']:>6}  "
                  f"{row['gyro_x']:>6} {row['gyro_y']:>6} {row['gyro_z']:>6}  "
                  f"{row['temp']:>6}  "
                  f"{row['crash']:>8}")


if __name__ == "__main__":
    main()