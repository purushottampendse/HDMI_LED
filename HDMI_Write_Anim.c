/*
 * HDMI_Write_Anim.c
 *
 *  Created on: 29 Jul 2024
 *      Author: pps
 */


/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdint.h>
#include "xil_assert.h"
#include "xscugic.h"
#include "xvtc.h"
#include "xgpiops.h"
#include "sleep.h"
#include "xtime_l.h"

#include "xaxivdma.h"
#include "xparameters.h"
#include "xparameters_ps.h"

#include "xil_cache.h"
#include "xil_io.h"


#define VIDEO_NUM_FRAMES 5
#define FRAME_SIZE (1280*720*3)
#define FRAME_WIDTH          1280
#define FRAME_HEIGHT         720
#define FRAME_BYTES_PER_PIXEL 3

#define VTC_LED				55u
#define PLOCKED_LED			54u

#define HW_REG(n) *(volatile unsigned int *) (XPAR_NEOPIXEL_DATAFLOW_0_S00_AXI_BASEADDR + 4*n)
#define  MAX_PIXEL_NUM  256

#define SRC_SIZE 256*3

#define ANIM_NUM_FRAMES 3
uint32_t LED_MATRIX_ARRAY[ANIM_NUM_FRAMES][MAX_PIXEL_NUM];

uint32_t reg_no;

typedef enum {
	VIDEO_DISCONNECTED = 0,
	VIDEO_STREAMING = 1,
	VIDEO_PAUSED = 2
} VideoState_t;

XScuGic XScuGicInst;
XVtc XVtcInst;
XGpioPs XGpioPsInst;

XVtc_Timing VtcDetectorTiming;
VideoState_t VideoState = VIDEO_DISCONNECTED;

XAxiVdma_Config *VdmaConfig;
XAxiVdma_DmaSetup VdmaWrite_Config;
XAxiVdma_FrameCounter VdmaFrameCounter_Config;
int32_t curFrame;
int32_t stride;
XAxiVdma Vdma;
uint8_t FrameCntIsZero = 0;
XTime StartTime = 0, CurrTime = 0;

int8_t FrameBuf[VIDEO_NUM_FRAMES][FRAME_SIZE] __attribute__((aligned(0x20)));
int8_t *FramePtr[VIDEO_NUM_FRAMES];

void IntcInit();
void VideoCaptureInit();
void XGpioPsCallbackHandler(void *CallBackRef, u32 Bank, u32 Status);
void MyAssertCallback(const char8 *File, s32 Line);
void VideoStart();
void VideoStop();
void XVtcLockCallbackHandler(void *CallBackRef, u32 PendingIntr);
void PrintFrameBufferData(int8_t FrameBuf[VIDEO_NUM_FRAMES][FRAME_SIZE], int32_t num_bytes_to_print);
void FrameCntIntrCallback(void *InstPtr, uint32_t InterruptTypes);
void NeoPixelRead();

int main(void) {
	Xil_AssertSetCallback(MyAssertCallback);

	IntcInit();
	VideoCaptureInit();	// HPD set high here.

	while(1) {
		uint8_t ChannelBusy = XAxiVdma_ChannelIsBusy(&(Vdma.WriteChannel));
		if ((FrameCntIsZero == 1) && (ChannelBusy == 0)) {
			XTime_GetTime(&CurrTime);

			VideoStop();

			/* Disable interrupts */
			XScuGic_Disable(&XScuGicInst, XPAR_FABRIC_VTC_0_VEC_ID);
			XScuGic_Disable(&XScuGicInst, XPAR_FABRIC_AXIVDMA_0_VEC_ID);

			VideoState = VIDEO_DISCONNECTED;

			uint32_t ElapsedTimeMs = ((CurrTime - StartTime) * 1000) / (COUNTS_PER_SECOND);
			xil_printf("Frames received in %ums\n", ElapsedTimeMs);



			/* Start sending frames */

			print("PY-START");
			sleep(1); // To allow python to detect PY-START purely.
			for (int i = 1; i < 2 ; i++){
				for( int j= 1; j<(FRAME_SIZE); j++){
					outbyte(FrameBuf[i][j]);
					usleep(100);

				}
			}

			print("PY-STOP");
			NeoPixelRead();

			while(1);
		}
	}
}

void IntcInit() {
	print("In IntcInit()\n");

	XScuGic_Config *XScuGicCfg;
	int32_t RetCode;

	/* Setup the SCU GIC */
	XScuGicCfg = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
	RetCode = XScuGic_CfgInitialize(&XScuGicInst, XScuGicCfg,
			XScuGicCfg->CpuBaseAddress);
	Xil_AssertVoid(RetCode == XST_SUCCESS);

	RetCode = XScuGic_SelfTest(&XScuGicInst);
	Xil_AssertVoid(RetCode == XST_SUCCESS);

	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
					(Xil_ExceptionHandler) XScuGic_InterruptHandler,
					&XScuGicInst);

	/* Enable VTC Interrupt @ XPAR_FABRIC_VTC_0_VEC_ID */
	XScuGic_SetPriorityTriggerType(&XScuGicInst, XPAR_FABRIC_VTC_0_VEC_ID, 0xA0, 0x3u);
	RetCode = XScuGic_Connect(&XScuGicInst, XPAR_FABRIC_VTC_0_VEC_ID,
			(XInterruptHandler) XVtc_IntrHandler, &XVtcInst);
	Xil_AssertVoid(RetCode == XST_SUCCESS);
	XScuGic_Enable(&XScuGicInst, XPAR_FABRIC_VTC_0_VEC_ID);

	/* Enable VTC Interrupt @ XPAR_FABRIC_VTC_0_VEC_ID */
	XScuGic_SetPriorityTriggerType(&XScuGicInst, XPAR_FABRIC_AXIVDMA_0_VEC_ID, 0xA0, 0x3u);
	RetCode = XScuGic_Connect(&XScuGicInst, XPAR_FABRIC_AXIVDMA_0_VEC_ID,
			(XInterruptHandler) XAxiVdma_WriteIntrHandler, &Vdma);
	Xil_AssertVoid(RetCode == XST_SUCCESS);
	XScuGic_Enable(&XScuGicInst, XPAR_FABRIC_AXIVDMA_0_VEC_ID);

	/* Enable GPIO Interrupt @ XPS_GPIO_INT_ID */
	XScuGic_SetPriorityTriggerType(&XScuGicInst, XPAR_PS7_GPIO_0_INTR, 0x50, 0x3u);
	RetCode = XScuGic_Connect(&XScuGicInst, XPAR_PS7_GPIO_0_INTR,
			(XInterruptHandler) XGpioPs_IntrHandler, &XGpioPsInst);
	Xil_AssertVoid(RetCode == XST_SUCCESS);
	XScuGic_Enable(&XScuGicInst, XPAR_PS7_GPIO_0_INTR);

	Xil_ExceptionEnable();
}

void VideoCaptureInit() {
	XGpioPs_Config *XGpioPsCfg;
	int32_t RetCode;

	/* Initialize GPIO PS which interfaces with the LEDs, BTNs, HPD and pLocked. */
	XGpioPsCfg = XGpioPs_LookupConfig(XPAR_PS7_GPIO_0_DEVICE_ID);
	RetCode = XGpioPs_CfgInitialize(&XGpioPsInst, XGpioPsCfg, XGpioPsCfg->BaseAddr);
	Xil_AssertVoid(RetCode == XST_SUCCESS);

	/* HPD at bit 8 and LEDs at bits 0 to 3 */
	XGpioPs_SetDirection(&XGpioPsInst, 2u, 0x10F);
	XGpioPs_SetOutputEnable(&XGpioPsInst, 2u, 0x10F);

	/* All LEDs and HPD off */
	XGpioPs_Write(&XGpioPsInst, 2u, 0x0u);

	/* Attach GPIO PS Interrupt callback */
	XGpioPs_SetCallbackHandler(&XGpioPsInst, &XGpioPsInst,(XGpioPs_Handler)XGpioPsCallbackHandler);

	/* pLocked at bit 9 detects rising or falling edge. All 3 arguments must be b'1 for the pin. */
	XGpioPs_SetIntrType(&XGpioPsInst, 2u, (1u << 9), (1u << 9), (1u << 9));

	/* Enable the pLocked interrupt */
	XGpioPs_IntrEnable(&XGpioPsInst, 2u, (1u << 9));

	/* HPD high */
    XGpioPs_Write(&XGpioPsInst, 2u, 0x100u);
//    sleep(3);
}

void XGpioPsCallbackHandler(void *CallBackRef, u32 Bank, u32 Status) {
	int32_t RetCode;
	XGpioPs *XGpioPsInstPtr = (XGpioPs*)CallBackRef;

	if (Bank == 2u) {
		if (((Status >> 9) & 0x1u) == 1) {
			uint32_t PixelClkLocked = (XGpioPs_Read(XGpioPsInstPtr, Bank) >> 9) & 0x1u;
			if (PixelClkLocked) {
				/* Feedback pixel locked signal on LED 0 */
				XGpioPs_WritePin(&XGpioPsInst, PLOCKED_LED, 0x1u);

				/* VTC Initialization and Configuration */
				XVtc_Config *XVtcCfg;

				XVtcCfg = XVtc_LookupConfig(XPAR_V_TC_0_DEVICE_ID);
				RetCode = XVtc_CfgInitialize(&XVtcInst, XVtcCfg, XVtcCfg->BaseAddress);
				if (RetCode != XST_SUCCESS) {
					print("ERROR: VTC init failed.\n");
				}

				RetCode = XVtc_SelfTest(&XVtcInst);
				if (RetCode != XST_SUCCESS) {
					print("ERROR: VTC self test failed.\n");
				}

				XVtc_RegUpdateEnable(&XVtcInst);
				XVtc_SetCallBack(&XVtcInst, XVTC_HANDLER_LOCK, &XVtcLockCallbackHandler, &XVtcInst);
				XVtc_IntrEnable(&XVtcInst, XVTC_IXR_LO_MASK | XVTC_IXR_LOL_MASK);
				XVtc_EnableDetector(&XVtcInst);

				/* Ready for VTC interrupt */
				XScuGic_Enable(&XScuGicInst, XPAR_FABRIC_VTC_0_VEC_ID);
			}
			else {
				/* Feedback pixel locked signal on LED 0 */
				XGpioPs_WritePin(&XGpioPsInst, PLOCKED_LED, 0x0u);

				/* VTC stop or de-init */
				VideoStop();

				/* Disable VTC interrupt */
				XScuGic_Disable(&XScuGicInst,XPAR_FABRIC_VTC_0_VEC_ID );

				VideoState = VIDEO_DISCONNECTED;
			}
		}
	}
}

void XVtcLockCallbackHandler(void *CallBackRef, u32 PendingIntr) {
	/* This callback is executed on both LOCK and LOCK LOSS events.
	 * Check if LOCK event occurred. Do nothing on LOSS event. */
	XVtc *XVtcInstPtr = (XVtc*)CallBackRef;

	if ((XVtc_GetDetectionStatus(XVtcInstPtr) & XVTC_STAT_LOCKED_MASK)) {
		XGpioPs_WritePin(&XGpioPsInst, VTC_LED, 0x1u);

		XVtc_GetDetectorTiming(XVtcInstPtr, &VtcDetectorTiming);
		VideoState = VIDEO_PAUSED;

		/* Video Start */
		VideoStart();

		XVtc_IntrDisable(XVtcInstPtr, XVTC_IXR_LO_MASK);
		XVtc_IntrClear(XVtcInstPtr, XVTC_IXR_LO_MASK);
	}
	else {
		XGpioPs_WritePin(&XGpioPsInst, VTC_LED, 0x0u);
	}
}

void MyAssertCallback(const char8 *File, s32 Line) {
	xil_printf("Assert failed in file %s at line %d\n", File, Line);
}

void VideoStart(){
	int32_t RetCode;
	int32_t i;

	/*VDMA Initialization and Configuration */
	VdmaConfig = XAxiVdma_LookupConfig(XPAR_AXIVDMA_0_DEVICE_ID);
	RetCode	= XAxiVdma_CfgInitialize(&Vdma, VdmaConfig, VdmaConfig->BaseAddress);
	Xil_AssertVoid(RetCode == XST_SUCCESS);

	/*VDMA setup for write channel*/
	VdmaWrite_Config.VertSizeInput = VtcDetectorTiming.VActiveVideo;
	VdmaWrite_Config.HoriSizeInput = VtcDetectorTiming.HActiveVideo * FRAME_BYTES_PER_PIXEL;
	VdmaWrite_Config.Stride = FRAME_WIDTH * FRAME_BYTES_PER_PIXEL;
	VdmaWrite_Config.FrameDelay = 0 ;
	VdmaWrite_Config.EnableCircularBuf = 1;
	VdmaWrite_Config.EnableSync = 0;
	VdmaWrite_Config.PointNum = 0;
	VdmaWrite_Config.EnableVFlip = 0;
	/*PPS modification for frame counter*/
	VdmaWrite_Config.EnableFrameCounter = 1;

	/*PPS code for VDMA frame counter configuration*/
	VdmaFrameCounter_Config.WriteFrameCount = 60;
	VdmaFrameCounter_Config.ReadDelayTimerCount = 0;
	VdmaFrameCounter_Config.ReadFrameCount = 1; // REMINDER: OR short-circuit in XAxiVdma_SetFrameCounter
	VdmaFrameCounter_Config.WriteDelayTimerCount = 0;

	/* Set frame bruffer addresses in the VdmaWrite_Config structure */
	for (i = 0; i < VIDEO_NUM_FRAMES; i++){
		VdmaWrite_Config.FrameStoreStartAddr[i] = (UINTPTR)FrameBuf[i];
	}

	/* Configure the DMA channel using the VdmaWrite_Config structure */
	RetCode = XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_WRITE, &(VdmaWrite_Config));
	if (RetCode != XST_SUCCESS){
		print("Write channel config failed\n");
		return;
	}

	/* Set frame bruffer addresses in VDMA using the VdmaWrite_Config structure */
	RetCode = XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_WRITE, VdmaWrite_Config.FrameStoreStartAddr);
	if (RetCode != XST_SUCCESS){
		print("Write channel set buffer address failed\n");
		return;
	}


//	XAxiVdma_StartFrmCntEnable(&Vdma, XAXIVDMA_WRITE);

	RetCode = XAxiVdma_SetFrameCounter(&Vdma, &VdmaFrameCounter_Config);
	if (RetCode != XST_SUCCESS){
		xil_printf("Setting frame counters failed: %d\n", RetCode);
		return;
	}

	XAxiVdma_SetCallBack(&Vdma, XAXIVDMA_HANDLER_GENERAL, (XAxiVdma_CallBack)FrameCntIntrCallback, &Vdma, XAXIVDMA_WRITE);
	XAxiVdma_ChannelEnableIntr(&(Vdma.WriteChannel), XAXIVDMA_IXR_FRMCNT_MASK);

	/* Record time at which DMA starts transfers. */
	XTime_GetTime(&StartTime);

	/* Start the DMA channel */
	RetCode = XAxiVdma_DmaStart(&Vdma, XAXIVDMA_WRITE);
	if (RetCode != XST_SUCCESS){
		print("Start Write transfer failed, XST_FAILURE %d\r\n");
		return;
	}

	VideoState = VIDEO_STREAMING;
}

void VideoStop(){
	if (VideoState == VIDEO_PAUSED || VideoState == VIDEO_DISCONNECTED){
		print("Video already paused or disconnected.\n");
		return;
	}

	XAxiVdma_Reset(&Vdma, XAXIVDMA_WRITE);
	while(XAxiVdma_ResetNotDone (&Vdma,XAXIVDMA_WRITE));
	VideoState = VIDEO_PAUSED;

	print("Video Stopped.\n");
	return;
}


void FrameCntIntrCallback(void *InstPtr, uint32_t InterruptTypes) {
	if (InterruptTypes & XAXIVDMA_IXR_FRMCNT_MASK) {
		FrameCntIsZero = 1;
	}
}

void NeoPixelRead(){

	uint32_t Packed_RGB_Data = 0;
	uint8_t LED_GREEN = 0;
	uint8_t LED_BLUE = 0;
	uint8_t LED_RED = 0;
	/*8 bit to 32 bit array*/
	LED_MATRIX_ARRAY[ANIM_NUM_FRAMES][MAX_PIXEL_NUM] = 0;
	for(int frame = 1 ; frame < 4; frame++){
	    // Packing the data
		for (int i = 0; i < SRC_SIZE; i += 3) {
			Packed_RGB_Data = 0;
			LED_GREEN = FrameBuf[frame][i];
			LED_BLUE = FrameBuf[frame][i+1];
			LED_RED = FrameBuf[frame][i+2];
			Packed_RGB_Data |= ((uint32_t)LED_GREEN <<16) ;
			Packed_RGB_Data |= ((uint32_t)LED_RED <<8) ;
			Packed_RGB_Data |= ((uint32_t)LED_BLUE <<0);
			LED_MATRIX_ARRAY[frame-1][i / 3] = Packed_RGB_Data;
		}

	}
	    print( "rgb data ready for transmission\n");

	    HW_REG(256) = 0x0ff;
	    print(" write and read enable signals are made low\n");
	    for(reg_no = 0; reg_no < MAX_PIXEL_NUM; reg_no++){
	    	HW_REG(reg_no) = LED_MATRIX_ARRAY[0][reg_no];
	    	usleep(1);
	    }
	    HW_REG(257) = 0x0ff;
	    print(" write enable signal is asserted\n");
	    sleep(1);

	    HW_REG(256) = 0x0ff;
	    print(" write and read enable signals are made low\n");

	    for(reg_no = 0; reg_no < MAX_PIXEL_NUM; reg_no++){
	    	HW_REG(reg_no) = 0x00000000;
	    	usleep(1);
	    }
	    HW_REG(257) = 0x0ff;
	    print(" write enable signal is asserted\n");
	    sleep(1);

	    HW_REG(256) = 0x0ff;
	    print(" write and read enable signals are made low\n");

	    for(reg_no = 0; reg_no < MAX_PIXEL_NUM; reg_no++){
	    	HW_REG(reg_no) = LED_MATRIX_ARRAY[2][reg_no];
	    	usleep(1);
	    }
	    HW_REG(257) = 0x0ff;
	    print(" write enable signal is asserted\n");
	    print("pixel data written into the fifo\n");

	    usleep(10);

}
