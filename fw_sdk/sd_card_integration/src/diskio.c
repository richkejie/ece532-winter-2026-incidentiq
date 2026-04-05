/*-----------------------------------------------------------------------*/
/* Low level disk I/O module for FatFs - AXI Quad SPI SD Card            */
/* Adapted from ChaN skeleton for MicroBlaze + Xilinx AXI Quad SPI       */
/*-----------------------------------------------------------------------*/

#include "ff.h"
#include "diskio.h"
#include "xspi.h"
#include "xparameters.h"

#include "xil_printf.h"

/*-----------------------------------------------------------------------*/
/* Definitions                                                           */
/*-----------------------------------------------------------------------*/

#define DEV_SD      0   /* SD card is physical drive 0 */

/* SPI device */
#define SPI_DEVICE_ID   XPAR_SPI_0_DEVICE_ID

/* SD card SPI commands */
#define CMD0    (0x40 | 0)   /* GO_IDLE_STATE */
#define CMD8    (0x40 | 8)   /* SEND_IF_COND */
#define CMD17   (0x40 | 17)  /* READ_SINGLE_BLOCK */
#define CMD24   (0x40 | 24)  /* WRITE_BLOCK */
#define CMD55   (0x40 | 55)  /* APP_CMD prefix */
#define CMD58   (0x40 | 58)  /* READ_OCR */
#define ACMD41  (0x80 | 41)  /* SD_SEND_OP_COND (prefixed with 0x80 to indicate ACMD) */

BYTE SD_CMD0[6] = {0x40, 0x00, 0x00, 0x00, 0x00, 0x95}; // reset command, puts SD card into SPI mode
BYTE SD_CMD8[6] = {0x48, 0x00, 0x00, 0x01, 0xAA, 0x87}; // check voltage range
BYTE SD_CMD55[6] = {0x77, 0x00, 0x00, 0x00, 0x00, 0x00};
BYTE SD_CMD41[6] = {0x69, 0x40, 0x00, 0x00, 0x00, 0x00};

/* Card type flags */
#define CT_MMC      0x01
#define CT_SD1      0x02
#define CT_SD2      0x04
#define CT_SDHC     0x08  /* SDHC/SDXC uses block addressing */

static XSpi SpiInstance;
static volatile DSTATUS disk_stat = STA_NOINIT;
static BYTE card_type;

/*-----------------------------------------------------------------------*/
/* SPI Primitives                                                        */
/*-----------------------------------------------------------------------*/

static void cs_low(void) {
    XSpi_SetSlaveSelect(&SpiInstance, 1);
//	XSpi_SetSlaveSelect(&SpiInstance, 0xFFFFFFFE);
}

static void cs_high(void) {
    XSpi_SetSlaveSelect(&SpiInstance, 0);
//	XSpi_SetSlaveSelect(&SpiInstance, 0xFFFFFFFF);
}

/* Send one byte over SPI and return the received byte */
static BYTE spi_txrx(BYTE out) {
    BYTE in = 0xFF;
    XSpi_Transfer(&SpiInstance, &out, &in, 1);
    return in;
}

/* Send 0xFF bytes to clock the SD card without sending data */
static void spi_send_ff(int count) {
    while (count--) spi_txrx(0xFF);
}

/*-----------------------------------------------------------------------*/
/* Send SD Command and return R1 response                                */
/*-----------------------------------------------------------------------*/

static BYTE send_cmd(BYTE cmd, DWORD arg) {
//	xil_printf("send_cmd: start\n\r");
    BYTE crc, res;
    int timeout;

    /* ACMD: send CMD55 first */
    if (cmd & 0x80) {
        cmd &= 0x7F;
        res = send_cmd(CMD55, 0);
        if (res > 1) return res;
    }

    /* Select card */
    cs_high();
    spi_txrx(0xFF);
    cs_low();
    spi_txrx(0xFF);

    /* Send command packet */
    spi_txrx(cmd);
    spi_txrx((BYTE)(arg >> 24));
    spi_txrx((BYTE)(arg >> 16));
    spi_txrx((BYTE)(arg >> 8));
    spi_txrx((BYTE)(arg));

    /* CRC - only required for CMD0 and CMD8, dummy for rest */
    crc = 0x01;
    if (cmd == CMD0) crc = 0x95;
    if (cmd == CMD8) crc = 0x87;
    spi_txrx(crc);

    /* Wait for valid R1 response (up to 10 attempts) */
    timeout = 10;
    do {
        res = spi_txrx(0xFF);
//        xil_printf("send_cmd response byte: 0x%02X\n\r", res);
    } while ((res & 0x80) && --timeout);

//    xil_printf("send_cmd: end\n\r");
    return res;
}

/*-----------------------------------------------------------------------*/
/* Get Drive Status                                                      */
/*-----------------------------------------------------------------------*/

DSTATUS disk_status(BYTE pdrv) {
    if (pdrv != DEV_SD) return STA_NOINIT;
    return disk_stat;
}

/*-----------------------------------------------------------------------*/
/* Initialize a Drive                                                    */
/*-----------------------------------------------------------------------*/

DSTATUS disk_initialize(BYTE pdrv) {
	int timeout;
	BYTE resp;
	BYTE Dummy[10] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

//	xil_printf("disk_initialize: start\n\r");
    if (pdrv != DEV_SD) return STA_NOINIT;
//    xil_printf("disk_initialize: pdrv == DEV_SD\n\r");

    /* Initialize AXI Quad SPI driver */
    XSpi_Config *cfg = XSpi_LookupConfig(SPI_DEVICE_ID);
    if (!cfg) return STA_NOINIT;

    if (XSpi_CfgInitialize(&SpiInstance, cfg, cfg->BaseAddress) != XST_SUCCESS)
        return STA_NOINIT;
//    xil_printf("disk_initialize: successfully initialized AXI Quad SPI driver\n\r");

    XSpi_SetOptions(&SpiInstance, XSP_MASTER_OPTION | XSP_MANUAL_SSELECT_OPTION);
    XSpi_Start(&SpiInstance);
    XSpi_IntrGlobalDisable(&SpiInstance); /* Use polled mode */

    /* Send >=74 clock pulses with CS high to wake up SD card */
//    xil_printf("disk_initialize: asserting CS for 80 cycles\n\r");
    cs_high();
    XSpi_Transfer(&SpiInstance, Dummy, NULL, 10); /* keep MOSI high for 80 clocks */

    /* assert CS low and send CMD0 */
    timeout = 16;
//    xil_printf("disk_initialize: de-assert CS and send SD_CMD0; timeout after (%d) tries\n\r", timeout);
    cs_low();
    XSpi_Transfer(&SpiInstance, SD_CMD0, &resp, 6);
    /* Wait for valid R1 response */
    while ((resp != 0x01) && (timeout>0)) {
    	resp = spi_txrx(0xFF);
//    	xil_printf("disk_initialize: SD_CMD0 response byte: 0x%02X\n\r", resp);
    	timeout--;
    }
	if (resp != 0x01) {
		return STA_NOINIT; /* Card not responding */
	}
//	xil_printf("disk_initialize: SD_CMD0 sent successfully\n\r");

	/* send CMD8 */
	timeout = 16;
//	xil_printf("disk_initialize: send SD_CMD8; timeout after (%d) tries\n\r", timeout);
	XSpi_Transfer(&SpiInstance, SD_CMD8, &resp, 6);
	/* Wait for valid R1 response */
	while ((resp != 0x01) && (timeout>0)) {
		resp = spi_txrx(0xFF);
//		xil_printf("disk_initialize: SD_CMD8 response byte: 0x%02X\n\r", resp);
		timeout--;
	}
	if (resp != 0x01) {
//		xil_printf("disk_initialize: SD_CMD8 not recognized, older SD card\n\r");
	} else {
//		xil_printf("disk_initialize: SD_CMD8, received R1 response\n\r");
		for (int i = 0; i < 4; i++) {
			resp = spi_txrx(0xFF);
//			xil_printf("disk_initialize: SD_CMD8 response byte: 0x%02X\n\r", resp);
		}
	}

	/* initialization loop */
sd_init_loop:
//	xil_printf("disk_initialize: beginning initialization loop\n\r");
	/* send CMD55 */
	timeout = 16;
//	xil_printf("disk_initialize: send SD_CMD55; timeout after (%d) tries\n\r", timeout);
	XSpi_Transfer(&SpiInstance, SD_CMD55, &resp, 6);
	/* Wait for valid R1 response */
	while (!((resp == 0x01) || (resp == 0x05) || (resp == 0x00)) && (timeout>0)) {
		resp = spi_txrx(0xFF);
//		xil_printf("disk_initialize: SD_CMD55 response byte: 0x%02X\n\r", resp);
		timeout--;
	}
	if ((resp == 0x01) || (resp == 0x00)) {
//		xil_printf("disk_initialize: SD_CMD55 success\n\r");
	} else if (resp == 0x05) {
//		xil_printf("disk_initialize: SD_CMD55 returned 0x05, older SD card\n\r");
	} else {
		return STA_NOINIT; /* Card not responding */
	}

	/* send CMD41 */
	timeout = 16;
//	xil_printf("disk_initialize: send SD_CMD41; timeout after (%d) tries\n\r", timeout);
	XSpi_Transfer(&SpiInstance, SD_CMD41, &resp, 6);
	/* Wait for valid R1 response */
	while (!((resp == 0x01) || (resp == 0x00)) && (timeout>0)) {
		resp = spi_txrx(0xFF);
//		xil_printf("disk_initialize: SD_CMD41 response byte: 0x%02X\n\r", resp);
		timeout--;
	}
	if (resp == 0x01) {
//		xil_printf("disk_initialize: SD_CMD41 success, still in idle, repeat initialization loop\n\r");
		goto sd_init_loop;
	} else if (resp == 0x00) {
//		xil_printf("disk_initialize: SD_CMD41 success, in ready state\n\r");
	} else {
		return STA_NOINIT; /* Card not responding */
	}


//    card_type = 0;
//    int timeout = 2000;
////    int timeout = 50000;
//
//    /* Put card into SPI mode with CMD0 */
//    if (send_cmd(CMD0, 0) != 0x01) {
//        return STA_NOINIT; /* Card not responding */
//    }
//    xil_printf("disk initialize: h2\n\r");
//
//    /* Check for SDv2 with CMD8 */
////    if (send_cmd(CMD8, 0x1AA) == 0x01) {
//    if (0) {
//    	xil_printf("disk initialize: send_cmd(CMD8, 0x1AA) returned 0x01\n\r");
//        /* SDv2: read 4-byte R7 response */
//        BYTE ocr[4];
//        for (int i = 0; i < 4; i++) ocr[i] = spi_txrx(0xFF);
//
//        if (ocr[2] == 0x01 && ocr[3] == 0xAA) {
//            /* Card supports 2.7-3.6V range, activate init */
//            while (--timeout && send_cmd(ACMD41, 0x40000000));
//
//            if (timeout && send_cmd(CMD58, 0) == 0) {
//                for (int i = 0; i < 4; i++) ocr[i] = spi_txrx(0xFF);
//                /* Check CCS bit to determine SDHC */
//                card_type = (ocr[0] & 0x40) ? CT_SD2 | CT_SDHC : CT_SD2;
//            }
//        }
//    } else {
//    	xil_printf("disk initialize: send_cmd(CMD8, 0x1AA) did not return 0x01\n\r");
//        /* SDv1 or MMC */
//        BYTE cmd;
//        if (send_cmd(ACMD41, 0) <= 1) {
//            card_type = CT_SD1;
//            cmd = ACMD41;
//        } else {
//            card_type = CT_MMC;
//            cmd = (0x40 | 1); /* CMD1 for MMC */
//        }
//        while (--timeout && send_cmd(cmd, 0));
//    }
//
//    cs_high();
//    spi_txrx(0xFF);
//
//    if (!timeout) return STA_NOINIT;
//    xil_printf("disk initialize: h3\n\r");
//
    disk_stat = 0; /* Initialization successful */
//    xil_printf("disk initialize: end\n\r");
    return disk_stat;
}

/*-----------------------------------------------------------------------*/
/* Read Sector(s)                                                        */
/*-----------------------------------------------------------------------*/

//DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count) {
//	xil_printf("disk_read: start\n\r");
//	xil_printf("disk_read: sector %d\n\r", (int)sector);
//    if (pdrv != DEV_SD || !count) return RES_PARERR;
//    if (disk_stat & STA_NOINIT) return RES_NOTRDY;
//
//    /* Convert sector to byte address for non-SDHC cards */
//    // we are using SDHC, so ignore this line...
////    if (!(card_type & CT_SDHC)) sector *= 512;
//
//    if (send_cmd(CMD17, sector) == 0) {
//        /* Wait for data token 0xFE */
//        int t = 20000;
//        BYTE tok;
//        do { tok = spi_txrx(0xFF); } while (tok == 0xFF && --t);
//
//        if (tok == 0xFE) {
//            for (int i = 0; i < 512; i++) *buff++ = spi_txrx(0xFF);
//            spi_txrx(0xFF); /* Discard CRC byte 1 */
//            spi_txrx(0xFF); /* Discard CRC byte 2 */
//            cs_high();
//            spi_txrx(0xFF);
//            return RES_OK;
//        }
//    }
//
//    cs_high();
//    spi_txrx(0xFF);
//    return RES_ERROR;
//}

DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count) {
//	xil_printf("disk_read: start\n\r");

	if (pdrv != DEV_SD || !count) return RES_PARERR;
    if (disk_stat & STA_NOINIT) return RES_NOTRDY;

    // SDHC/SDXC use block addressing (sector #),
    // while older SD cards use byte addressing (sector * 512).
//    if (!(card_type & CT_BLOCK)) sector *= 512;

    // Use CMD18 (READ_MULTIPLE_BLOCK) for count > 1,
    // or loop CMD17 (READ_SINGLE_BLOCK) for simplicity.
    while (count--) {

//    	xil_printf("disk_read: sector %d\n\r", (int)sector);

    	if (send_cmd(CMD17, sector) == 0) {
            // Wait for data token 0xFE
            int t = 20000;
            BYTE tok;
            do {
                tok = spi_txrx(0xFF);
            } while (tok == 0xFF && --t);

            if (tok == 0xFE) {
                // Read 512 bytes
                for (int i = 0; i < 512; i++) {
                    *buff++ = spi_txrx(0xFF);
                }
                // Skip 16-bit CRC
                spi_txrx(0xFF);
                spi_txrx(0xFF);

                // Advance to next sector for next loop iteration
                sector++;
            } else {
                // Failed to get 0xFE token
                cs_high();
                spi_txrx(0xFF);
                return RES_ERROR;
            }
        } else {
            // CMD17 failed
            cs_high();
            spi_txrx(0xFF);
            return RES_ERROR;
        }

        // Essential: Toggle CS and provide trailing clocks between blocks
        cs_high();
        spi_txrx(0xFF);
    }

    return RES_OK;
}

/*-----------------------------------------------------------------------*/
/* Write Sector(s)                                                       */
/*-----------------------------------------------------------------------*/

#if FF_FS_READONLY == 0

DRESULT disk_write(BYTE pdrv, const BYTE *buff, LBA_t sector, UINT count) {
    if (pdrv != DEV_SD || !count) return RES_PARERR;
    if (disk_stat & STA_NOINIT) return RES_NOTRDY;

    /* Convert sector to byte address for non-SDHC cards */
//    if (!(card_type & CT_SDHC)) sector *= 512;

    if (send_cmd(CMD24, sector) == 0) {
        spi_txrx(0xFF);
        spi_txrx(0xFE); /* Data token */

        /* Send 512-byte block */
        for (int i = 0; i < 512; i++) spi_txrx(*buff++);

        spi_txrx(0xFF); /* Dummy CRC byte 1 */
        spi_txrx(0xFF); /* Dummy CRC byte 2 */

        /* Check data response token */
        BYTE resp = spi_txrx(0xFF);
        if ((resp & 0x1F) != 0x05) {
            cs_high();
            spi_txrx(0xFF);
            return RES_ERROR;
        }

        /* Wait for card to finish writing (busy = 0x00) */
        int t = 50000;
        while (spi_txrx(0xFF) == 0x00 && --t);

        cs_high();
        spi_txrx(0xFF);
        return t ? RES_OK : RES_ERROR;
    }

    cs_high();
    spi_txrx(0xFF);
    return RES_ERROR;
}

#endif

/*-----------------------------------------------------------------------*/
/* Miscellaneous Functions                                               */
/*-----------------------------------------------------------------------*/

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void *buff) {
    if (pdrv != DEV_SD) return RES_PARERR;
    if (disk_stat & STA_NOINIT) return RES_NOTRDY;

    switch (cmd) {
        case CTRL_SYNC:
            cs_low();
            /* Wait until card is not busy */
            int t = 50000;
            while (spi_txrx(0xFF) != 0xFF && --t);
            cs_high();
            return t ? RES_OK : RES_ERROR;

        case GET_SECTOR_SIZE:
            *(WORD*)buff = 512;
            return RES_OK;

        case GET_BLOCK_SIZE:
            *(DWORD*)buff = 1;
            return RES_OK;

        default:
            return RES_PARERR;
    }
}

/* Required by FatFs - return 0 if no RTC available */
DWORD get_fattime(void) {
    return 0;
}
