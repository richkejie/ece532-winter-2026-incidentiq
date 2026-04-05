import os
import subprocess

RDL_FILE = "src/registers.rdl"
RTL_OUTPUT_DIR = "gen_rtl"
C_OUTPUT_DIR = "gen_c"
HTML_OUTPUT_DIR = "gen_html"

REG_BASE_ADDR = "0x44A00000"

def generate():
    os.makedirs(RTL_OUTPUT_DIR, exist_ok=True)
    os.makedirs(C_OUTPUT_DIR, exist_ok=True)

    print(f"--- Compiling {RDL_FILE} ---")

    # 1. Generate Verilog RTL
    print("Generating SystemVerilog using PeakRDL...")
    subprocess.run([
        "peakrdl", "regblock", RDL_FILE,
        "-o", RTL_OUTPUT_DIR,
        "--cpuif", "axi4-lite-flat",
        "--default-reset", "arst_n",
        "--addr-width", "32",
        "--hwif-report"
    ])

    # 2. Generate C Header
    print("Generating C Header...")
    subprocess.run([
        "peakrdl", "c-header", RDL_FILE,
        "-o", f"{C_OUTPUT_DIR}/regs.h",
        "--instantiate",                # generate addresses as a struct offset
    ])

    # 3. Generate HTML Documentation
    print("Generating HTML Documentation...")
    subprocess.run([
        "peakrdl", "html", RDL_FILE,
        "-o", HTML_OUTPUT_DIR
    ])

    print("\nDone!")

if __name__ == "__main__":
    generate()