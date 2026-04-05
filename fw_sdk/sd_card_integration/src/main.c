/*
 * main.c
 *
 *  Created on: Mar 12, 2026
 *      Author: IncidentIQ
 */
#include "xparameters.h"
#include "xstatus.h"
#include "xuartlite.h"
#include "xuartlite_l.h"
#include "sleep.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xgpio.h"

// SD card
#include "ff.h" // FatFs
#include "platform.h"
#include "xil_io.h"
#include "xil_printf.h"
#include <stdio.h>

// interrupts
#include "xil_exception.h"
#include "xintc.h"

// register address declaration
#define REG_BASE            0x44A00000

#define REG_WRITE_PTR       			(REG_BASE + 0x00)
#define REG_READ_PTR       	 			(REG_BASE + 0x04)
#define REG_STATUS          			(REG_BASE + 0x08)
#define REG_CD_NON_FATAL_ACCEL_THRESH	(REG_BASE + 0x10)
#define REG_CD_FATAL_ACCEL_THRESH		(REG_BASE + 0x14)
#define REG_CD_ANGULAR_SPEED_THRESH 	(REG_BASE + 0x18)
#define REG_CD_EN 						(REG_BASE + 0x1C)
#define REG_CD_STATE_RST 				(REG_BASE + 0x20)
#define REG_POLLING_MODULE_EN 			(REG_BASE + 0x24)
#define REG_DATA_PACKAGER_EN 			(REG_BASE + 0x28)

// packet parameters
#define DATA_BRAM_BASE      0xC0000000
#define PACKET_WORDS        10
#define PACKET_BYTES        (PACKET_WORDS * 4)
#define PTR_MASK            0x7FF

#define SYNC_BYTE_0         0x55
#define SYNC_BYTE_1         0xAA

// declare buffer for storing latest 200 packets
#define HISTORY_SIZE        200

typedef struct {
    u32 words[PACKET_WORDS];
} Packet;

static Packet history[HISTORY_SIZE];
static int    history_head  = 0;
static int    history_count = 0;
static int    crash_count   = 0;

// file system variables
static FATFS fatfs; // filesystem object
static FIL file;    // file object
static FRESULT res;

// interrupt parameters
#define INTC_DEVICE_ID XPAR_INTC_0_DEVICE_ID
#define CRASH_INTR_ID XPAR_MICROBLAZE_0_AXI_INTC_SYSTEM_CRASH_INTERRUPT_IN_INTR

XIntc InterruptController;
volatile int cd_intc = 0;


// interrupt handler start
void CrashInterruptHandler(void *CallbackRef) {
  xil_printf("Interrupt detected! (crash detected)\r\n");
  if (cd_intc == 0x0) {
	  cd_intc = 1;
  }
}

// setup 
int SetupInterruptSystem(XIntc *IntcInstancePtr) {
  int Status;

  // interrupt controller driver initialization 
  Status = XIntc_Initialize(IntcInstancePtr, INTC_DEVICE_ID);
  if (Status != XST_SUCCESS)
    return XST_FAILURE;

  // tie the handler to an interrupt ID
  Status = XIntc_Connect(IntcInstancePtr, CRASH_INTR_ID,
                         (XInterruptHandler)CrashInterruptHandler, (void *)0);
  if (Status != XST_SUCCESS)
    return XST_FAILURE;

  // interrupt controller started
  Status = XIntc_Start(IntcInstancePtr, XIN_REAL_MODE);
  if (Status != XST_SUCCESS)
    return XST_FAILURE;

  // interrupt enabled for the crash signal
  XIntc_Enable(IntcInstancePtr, CRASH_INTR_ID);

  // microblaze exception table initialized
  Xil_ExceptionInit();

  Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                               (Xil_ExceptionHandler)XIntc_InterruptHandler,
                               IntcInstancePtr);

  // exceptions now enabled
  Xil_ExceptionEnable();

  return XST_SUCCESS;
}


static void send_byte(u32 reg_base, u8 val)
{
    XUartLite_SendByte(reg_base, val);
}

static void send_word(u32 reg_base, u32 word)
{
    send_byte(reg_base, (word >>  0) & 0xFF);
    send_byte(reg_base, (word >>  8) & 0xFF);
    send_byte(reg_base, (word >> 16) & 0xFF);
    send_byte(reg_base, (word >> 24) & 0xFF);
}

int main()
{
	init_platform();

    int status;

    xil_printf("Starting up...\r\n");

    // set up interrupt handler
    if (SetupInterruptSystem(&InterruptController) != XST_SUCCESS) {
		xil_printf("ERROR: Interrupt Setup Failed. Check your Device ID.\r\n");
		return XST_FAILURE;
	}

    // UARTLite init for BT Module
    xil_printf("Initialize Bluetooth Module...\r\n");
    XUartLite Uart;
    status = XUartLite_Initialize(&Uart, XPAR_UARTLITE_0_DEVICE_ID);
    if (status != XST_SUCCESS) return -1;

    // GPIO init for BT Module (pull reset high)
    xil_printf("Pull Bluetooth Module reset pin high...\r\n");
	XGpio Gpio;
	status = XGpio_Initialize(&Gpio, XPAR_AXI_GPIO_0_DEVICE_ID);
	if (status != XST_SUCCESS) return -1;
	XGpio_SetDataDirection(&Gpio, 1, 0x0);
	XGpio_DiscreteWrite(&Gpio, 1, 0x1);

	// Enable Crash Detection
	xil_printf("Enable Crash Detection...\r\n");
	u32 cd_angular_speed_thresh = 8000;
	Xil_Out32(REG_CD_ANGULAR_SPEED_THRESH, cd_angular_speed_thresh);
	u32 cd_accel_thresh = 80;
	Xil_Out32(REG_CD_FATAL_ACCEL_THRESH, cd_accel_thresh);
	u32 cd_non_fatal_accel_thresh = 1000;
	Xil_Out32(REG_CD_NON_FATAL_ACCEL_THRESH, cd_non_fatal_accel_thresh);

	// Enable Polling Module
	xil_printf("Reset Polling Module...\r\n");
	Xil_Out32(REG_POLLING_MODULE_EN, 0x00000001);

	// Enable Data Packager
	xil_printf("Enabling Data Packager...\r\n");
	Xil_Out32(REG_DATA_PACKAGER_EN, 0x00000001);

	xil_printf("Enabling Polling Module...\r\n");
	Xil_Out32(REG_POLLING_MODULE_EN, 0x00000000);

	u32 cd_state_rst = 0x0;
	Xil_Out32(REG_CD_STATE_RST, cd_state_rst);

	u32 cd_en_flag = 0x1;
	Xil_Out32(REG_CD_EN, cd_en_flag);

	usleep(100000);

	// Initialize read pointer
	xil_printf("Initializing read pointer...\r\n");
    u32 read_ptr = 0x0;
    Xil_Out32(REG_READ_PTR, read_ptr);

    // SD CARD INIT, mount and open file once, leave open for the duration of program
	xil_printf("Mounting SD card...\r\n");
	res = f_mount(&fatfs, "0:", 1);
	if (res != FR_OK) {
		xil_printf("ERROR: f_mount failed (%d)\r\n", res);
		return XST_FAILURE;
	}
	xil_printf("Filesystem mounted OK\r\n");

	res = f_open(&file, "0:CRASHES.TXT", FA_CREATE_ALWAYS | FA_WRITE);
	if (res != FR_OK) {
		xil_printf("ERROR: f_open failed (%d)\r\n", res);
		f_mount(NULL, "0:", 0);
		return XST_FAILURE;
	}
	xil_printf("File opened OK\r\n");

	xil_printf("CD_FATAL_ACCEL_THRESH = 0x%08x\r\n", Xil_In32(REG_CD_FATAL_ACCEL_THRESH));
	xil_printf("CD_NON_FATAL_ACCEL_THRESH = 0x%08x\r\n", Xil_In32(REG_CD_NON_FATAL_ACCEL_THRESH));
	xil_printf("CD_ANGULAR_SPEED_THRESH = 0x%08x\r\n", Xil_In32(REG_CD_ANGULAR_SPEED_THRESH));

    xil_printf("Setup complete, entering main loop...\r\n");

	
    while (1) {
        u32 write_ptr = Xil_In32(REG_WRITE_PTR) & PTR_MASK;
        u32 hw_status = Xil_In32(REG_STATUS);
        u8  buf_empty = hw_status & 0x1;
        u8  buf_full  = (hw_status >> 1) & 0x1;
        u32 available = (write_ptr - read_ptr) & PTR_MASK;

        if (available >= PACKET_BYTES) {
            u32 packet[PACKET_WORDS];

            // read from BRAM
            for (int i = 0; i < PACKET_WORDS; i++) {
                u32 addr = DATA_BRAM_BASE + ((read_ptr + i * 4) & PTR_MASK);
                packet[i] = Xil_In32(addr);
            }
			
			// when a crash interrupt occurs 
            if (cd_intc > 0) {
				xil_printf("CRASH OCCURRED, logging...\r\n");

				// reset crash detection hardware
				Xil_Out32(REG_CD_STATE_RST, 0x1);
				usleep(100);
				Xil_Out32(REG_CD_STATE_RST, 0x0);

				// flag crash bit in this packet
				packet[6] |= 0x80000000;

				cd_intc = 0;
				crash_count++;
				xil_printf("Crash count: %d\r\n", crash_count);
			}

            // update circular buffer with packet
			for (int i = 0; i < PACKET_WORDS; i++)
				history[history_head].words[i] = packet[i];
			history_head = (history_head + 1) % HISTORY_SIZE;
			if (history_count < HISTORY_SIZE) history_count++;

			// flush to SD card when buffer is full
			if (history_count == HISTORY_SIZE) {
				xil_printf("Buffer full, writing to SD...\r\n");

				UINT bw;
				for (int i = 0; i < HISTORY_SIZE; i++) {
					int idx = (history_head + i) % HISTORY_SIZE;
					f_write(&file, history[idx].words, PACKET_BYTES, &bw);
				}

				f_sync(&file);
				xil_printf("Write complete\r\n");

				// reset buffer
				history_head  = 0;
				history_count = 0;
			}

            // bluetooth transmission protocol
            // send 2 byte preamble marker
            send_byte(Uart.RegBaseAddress, SYNC_BYTE_0);
            send_byte(Uart.RegBaseAddress, SYNC_BYTE_1);
            // send 40 byte packet
            for (int i = 0; i < PACKET_WORDS; i++) {
                send_word(Uart.RegBaseAddress, packet[i]);
            }

            // advance read pointer
            read_ptr = (read_ptr + PACKET_BYTES) & PTR_MASK;
            Xil_Out32(REG_READ_PTR, read_ptr);
        }

        usleep(1000);
    }

    cleanup_platform();
	return 0;
}


