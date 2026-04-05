#!/usr/bin/env python3
"""
parse_packets.py
Reads a binary file of 10 x 40-byte GPS+IMU packets and writes a CSV.

Word layout (word 0 first):
  word 0:  placeholder (all zeros)
  word 1:  gyro_y [31:16] | gyro_x [15:0]
  word 2:  0x0000 [31:16] | gyro_z [15:0]
  word 3:  accel_y [31:16] | accel_x [15:0]
  word 4:  0x0000 [31:16] | accel_z [15:0]
  word 5:  gps_ground_speed [31:0]
  word 6:  0...0 [31:2] | north [1] | east [0]
  word 7:  gps_longitude [31:0]
  word 8:  gps_latitude [31:0]
  word 9:  gps_utc_time [31:0]

Usage:
    python parse_packets.py <input.bin> [output.csv]
"""

import csv
import struct
import sys
import os

# ── CONFIG ────────────────────────────────────────────────────────────────────
PACKET_WORDS = 10
PACKET_SIZE  = PACKET_WORDS * 4   # 40 bytes
NUM_PACKETS  = 4
ENDIAN       = '<'                # '>' big-endian | '<' little-endian
# ── END CONFIG ────────────────────────────────────────────────────────────────

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
]


def to_signed16(val: int) -> int:
    if val >= 0x8000:
        return val - 0x10000
    return val


def decode_packet(frame_num: int, words: list) -> dict:
    # word 0: placeholder (ignore)

    # word 1: gyro_y [31:16] | gyro_x [15:0]
    gyro_x = to_signed16(words[1] & 0xFFFF)
    gyro_y = to_signed16((words[1] >> 16) & 0xFFFF)

    # word 2: 0x0000 | gyro_z [15:0]
    gyro_z = to_signed16(words[2] & 0xFFFF)

    # word 3: accel_y [31:16] | accel_x [15:0]
    accel_x = to_signed16(words[3] & 0xFFFF)
    accel_y = to_signed16((words[3] >> 16) & 0xFFFF)

    # word 4: 0x0000 | accel_z [15:0]
    accel_z = to_signed16(words[4] & 0xFFFF)

    # word 5: gps_ground_speed
    gps_ground_speed = words[5]

    # word 6: {30'b0, north, east}
    gps_east  = words[6] & 0x1
    gps_north = (words[6] >> 1) & 0x1

    # word 7: gps_longitude
    gps_longitude = words[7]

    # word 8: gps_latitude
    gps_latitude = words[8]

    # word 9: gps_utc_time
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
    }


def parse_file(input_path: str, output_path: str) -> None:
    expected_bytes = PACKET_SIZE * NUM_PACKETS

    with open(input_path, 'rb') as f:
        raw = f.read()

    if len(raw) < expected_bytes:
        raise ValueError(
            f"File too short: expected {expected_bytes} bytes, got {len(raw)}"
        )
    if len(raw) > expected_bytes:
        print(f"Warning: file has {len(raw)} bytes; only the first "
              f"{expected_bytes} will be parsed.")

    fmt = ENDIAN + '10I'   # 10 unsigned 32-bit words

    with open(output_path, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=CSV_COLUMNS)
        writer.writeheader()

        print(f"{'Frame':>7}  {'UTC Time':>10}  {'Lat':>10}  {'Lon':>10}  "
              f"{'N':>1} {'E':>1}  {'Speed':>10}  "
              f"{'AX':>6} {'AY':>6} {'AZ':>6}  "
              f"{'GX':>6} {'GY':>6} {'GZ':>6}")
        print("-" * 105)

        for i in range(NUM_PACKETS):
            chunk = raw[i * PACKET_SIZE:(i + 1) * PACKET_SIZE]
            words = list(struct.unpack(fmt, chunk))
            row = decode_packet(i + 1, words)
            writer.writerow(row)

            print(f"{row['frame_num']:>7}  "
                  f"{row['gps_utc_time']:>10}  "
                  f"{row['gps_latitude']:>10}  "
                  f"{row['gps_longitude']:>10}  "
                  f"{row['gps_north']:>1} {row['gps_east']:>1}  "
                  f"{row['gps_ground_speed']:>10}  "
                  f"{row['accel_x']:>6} {row['accel_y']:>6} {row['accel_z']:>6}  "
                  f"{row['gyro_x']:>6} {row['gyro_y']:>6} {row['gyro_z']:>6}")

    print(f"\nDone. {NUM_PACKETS} packets saved to {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python parse_packets.py <input.bin> [output.csv]")
        sys.exit(1)

    input_file  = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else \
                  os.path.splitext(input_file)[0] + ".csv"

    parse_file(input_file, output_file)