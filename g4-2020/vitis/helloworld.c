#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xil_io.h"
#include "xbasic_types.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xil_cache.h"
#include "sleep.h"
#include "pixel_coord.h"

#include "xdebug.h"

#define DMA_DEV_ID		XPAR_AXIDMA_0_DEVICE_ID

#ifdef XPAR_AXI_7SDDR_0_S_AXI_BASEADDR
#define DDR_BASE_ADDR		XPAR_AXI_7SDDR_0_S_AXI_BASEADDR
#elif XPAR_MIG7SERIES_0_BASEADDR
#define DDR_BASE_ADDR	XPAR_MIG7SERIES_0_BASEADDR
#elif XPAR_MIG_0_BASEADDR
#define DDR_BASE_ADDR	XPAR_MIG_0_BASEADDR
#elif XPAR_PSU_DDR_0_S_AXI_BASEADDR
#define DDR_BASE_ADDR	XPAR_PSU_DDR_0_S_AXI_BASEADDR
#endif

#ifndef DDR_BASE_ADDR
#warning CHECK FOR THE VALID DDR ADDRESS IN XPARAMETERS.H,  \
  DEFAULT SET TO 0x01000000
#define MEM_BASE_ADDR		0x01000000
#else
#define MEM_BASE_ADDR		(DDR_BASE_ADDR + 0x1000000)
#endif

#define RX_INTR_ID			XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR
#define TX_BUFFER_BASE		(MEM_BASE_ADDR + 0x00001000)
#define RX_BUFFER_BASE (MEM_BASE_ADDR + 0x00002000)

#define INTC_DEVICE_ID 		XPAR_PS7_SCUGIC_0_DEVICE_ID

static void RxIntrHandler(void *Callback);
static void DisableIntrSystem();

u32 Init_Function(u32 DeviceId);
u32 DMA_init();
u32 dma_write_pix_array(u32 *TxBufferPtr, u32 *RxBufferPtr, u32 num_of_pixels, u32 base_address); //function for writing pixels and radius into RAM

volatile int Error;
volatile int rx_intr_done;
static XScuGic INTCInst;
static XAxiDma AxiDma;

//the starting location of the transfer buffer
u32 *TxBufferPtr = (u32 *) TX_BUFFER_BASE;
//same for recieving buffer
u32 *RxBufferPtr = (u32 *) RX_BUFFER_BASE;

int main() {
  int status;

  Xil_DCacheDisable();
  Xil_ICacheDisable();
  init_platform();

  xil_printf("\r\nStarting simulation\n");
  status = Init_Function(INTC_DEVICE_ID);

  //the first location in our TxBufferPtr will be the radius
  //the radius of the circle on the test image is 25pix
  u32 radius = 25;
  radius |= 1 << 31; //set the RAD_PIX_MASK
  TxBufferPtr[0] = radius;

  //test coordinates which will be read from the file
  unsigned int x_coordinate;
  unsigned int y_coordinate;
  int num_of_pixels = 0;

  for(int i = 0 ; i < 172; ++i) {
    num_of_pixels++; //increment the number of pixels
    x_coordinate = x_pos_arr[i];
    y_coordinate = y_pos_arr[i];

    u32 packed_data = 0;
    packed_data = x_coordinate;
    packed_data |= (y_coordinate << 10);

    //put the packed data into the buffer
    TxBufferPtr[i + 1] = packed_data;
  }

  xil_printf("num_of_pixels = %d\n", num_of_pixels * 360);


  //call the function to start the DMA with the pixels
  dma_write_pix_array(TxBufferPtr, RxBufferPtr, num_of_pixels, XPAR_AXI_DMA_0_BASEADDR);

  //sleep for 5 sec
  sleep(5);
  u32 *acc_matrix = (u32 *)calloc(90000, sizeof(u32));

  u32 res_x;
  u32 res_y;
  for(int i = 0; i < (num_of_pixels * 360); ++i) {
	  res_x = RxBufferPtr[i] & 0x000003FF;
	  res_y = (RxBufferPtr[i] & 0x000FFC00) >> 10;

	  acc_matrix[300 * res_y + res_x] += 1;
  }

  int max_el = 0;
  int xm, ym;
  for(int i = 0; i < (300 * 300); ++i) {
	  if(max_el < acc_matrix[i]) {
		  max_el = acc_matrix[i];
		  xm = i % 300;
		  ym = i / 300;
		  xil_printf("i = %d\n", i);
	  }
  }

  free(acc_matrix);

  //print out the expected results
  xil_printf("Simulation finished\n\nRESULTS:\n");
  xil_printf("Expected position of circle center : x = 150, y = 150\n");
  xil_printf("Calculated position of circle center : x = %d, y = %d", xm, ym);

  cleanup_platform();
  Xil_DCacheDisable();
  Xil_ICacheDisable();

  DisableIntrSystem();

  return 0;
}

static void RxIntrHandler(void *Callback) {
  //this is the interrupt method for the S2MM interrupt
  u32 IrqStatus;
  XAxiDma *AxiDmaInst = (XAxiDma *) Callback;
  u32 S2MM_DMACR_reg;

  //read the irq status from s2mm_dmacr
  IrqStatus = Xil_In32(XPAR_AXI_DMA_0_BASEADDR + 52);

  //clear the irq status from the register
  Xil_Out32(XPAR_AXI_DMA_0_BASEADDR + 52, IrqStatus | 0x00007000);

  rx_intr_done = 1;

  xil_printf("Interrupt caught!\n");
}

// Initialize System  function
u32 Init_Function(u32 DeviceId)
{
	XScuGic_Config *IntcConfig;
	int status;
	IntcConfig = XScuGic_LookupConfig(DeviceId);
	status = XScuGic_CfgInitialize(&INTCInst, IntcConfig, IntcConfig->CpuBaseAddress);
	if(status != XST_SUCCESS) return XST_FAILURE;
	status = XScuGic_SelfTest(&INTCInst);
	if (status != XST_SUCCESS)
    {
      return XST_FAILURE;
      printf("error");
    }

	//DMA enable and connect interrupt
	DMA_init();

	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                               (Xil_ExceptionHandler)XScuGic_InterruptHandler,&INTCInst);
	Xil_ExceptionEnable();

	return XST_SUCCESS;

}

u32 DMA_init() {
  int Status;
  u32 reset = 0x00000004;
  u32 S2MM_DMACR_reg;

  //reset the dma
	Xil_Out32(XPAR_AXI_DMA_0_BASEADDR,  reset); // writing to MM2S_DMACR register

	XScuGic_SetPriorityTriggerType(&INTCInst, RX_INTR_ID, 0xA8, 0x3);

	/*
	 * Connect the device driver handler that will be called when an
	 * interrupt for the device occurs, the handler defined above performs
	 * the specific interrupt processing for the device.
	 */
	Status = XScuGic_Connect(&INTCInst, RX_INTR_ID, (Xil_InterruptHandler)RxIntrHandler, NULL);
	if (Status != XST_SUCCESS) {
		return Status;
	}
	XScuGic_Enable(&INTCInst, RX_INTR_ID);

  //DMA configuration
  u32 IOC_IRQ_EN = 1 << 12;
  u32 ERR_IRQ_EN = 1 << 14;
  S2MM_DMACR_reg = Xil_In32(XPAR_AXI_DMA_0_BASEADDR + 48); //read the s2mm_dmacr reg from the dma

  u32 enable_interrupt = S2MM_DMACR_reg | IOC_IRQ_EN | ERR_IRQ_EN;;
  //set the S2MM DMACR register
  Xil_Out32(XPAR_AXI_DMA_0_BASEADDR + 48, enable_interrupt);

  //initialize flags before transfer test
  rx_intr_done = 0;
  Error = 0;
  return 0;
}


u32 dma_write_pix_array(u32 *TxBufferPtr, u32 *RxBufferPtr, u32 num_of_pixels, u32 base_address) {
  u32 MM2S_DMACR_reg, S2MM_DMACR_reg;
  u32 RS_MASK = 0x1;


  //read the control registers
  MM2S_DMACR_reg = Xil_In32(base_address);
  S2MM_DMACR_reg = Xil_In32(base_address + 48);

  //set the RS bits in the control registers
  Xil_Out32(base_address, MM2S_DMACR_reg | RS_MASK);
  Xil_Out32(base_address + 48, S2MM_DMACR_reg | RS_MASK);

  //set the source and destination address registers
  Xil_Out32(base_address + 24, (UINTPTR) TxBufferPtr);
  Xil_Out32(base_address + 72, (UINTPTR) RxBufferPtr);

  //calculate the amount of data in bytes to be transfered/recieved
  u32 tx_pkt_length = num_of_pixels * 4 + 1;
  u32 rx_pkt_length = num_of_pixels * 360 * 4;

  //set the length registers accordingly
  Xil_Out32(base_address + 40, tx_pkt_length);
  Xil_Out32(base_address + 88, rx_pkt_length);

  return 0;
}

static void DisableIntrSystem() {
  XScuGic_Disconnect(&INTCInst, RX_INTR_ID);
}
