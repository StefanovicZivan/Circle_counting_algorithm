#ifndef _ACC_CALC_HPP_
#define _ACC_CALC_HPP_

/*
  Module : Accumulator calculator IP + AXI DMA

  Description : The IP communicates with the DRAM memory in the PS
  through the AXI DMA, receiving non black pixels from a picture
  with extracted edges, and sending to the DRAM the calculated
  circle coordinates around the pixel for the given radius
*/

#include <tlm>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/simple_initiator_socket.h>
#include "vp_addr.hpp"

//REGISTER DEFAULT VALUES (RESET VALUES)
#define MM2S_DMACR_DEF  0x00010002
#define MM2S_DMASR_DEF  0x00010001
#define MM2S_SA_DEF     0x00000000
#define MM2S_LENGTH_DEF 0x00000000
#define S2MM_DMACR_DEF  0x00010002
#define S2MM_DMASR_DEF  0x00010001
#define S2MM_DA_DEF     0x00000000
#define S2MM_LENGTH_DEF 0x00000000
//REGISTER DEFAULT VALUES END

//REGISTER MASKS FOR SPECIFIC CONTROL/STATUS BITS
#define RS_MASK         (0x1 << 0)
#define RESET_MASK      (0x1 << 2)
#define IOC_IRQ_EN_MASK (0x1 << 12)
#define HALTED_MASK     (0x1 << 0)
#define IDLE_MASK       (0x1 << 1)
#define IOC_IRQ_MASK    (0x1 << 12)
#define LENGTH_MASK     (0x3FFFFFF)
//REGISTER MASKS END

//WIDTH OF THE MEMORY MAPPED READ/WRITE DATA, CAN ONLY BE k*(4 bytes)
#define MEMORY_MAPPED_READ_DATA_WIDTH  4
#define MEMORY_MAPPED_WRITE_DATA_WIDTH 4

//WIDTH OF THE BUFFER LENGTH REGISTER, CAN BE 8-26 BITS
#define BUFFER_LENGTH_REGISTER_WIDTH 26


class acc_calc : public sc_core::sc_module {
public:
  //Constructor
  acc_calc(sc_core::sc_module_name);

  //Target socket for register configuration
  tlm_utils::simple_target_socket<acc_calc> reg_conf_tsoc;

  //Initiator socket for direct memory access (read channel)
  tlm_utils::simple_initiator_socket<acc_calc> dma_read_isoc;

  //Initiator socket for direct memory access (write channel)
  tlm_utils::simple_initiator_socket<acc_calc> dma_write_isoc;

  //MM2S & S2MM Interrupt on Completion signal
  sc_core::sc_signal<bool> mm2s_ioc_irq;
  sc_core::sc_signal<bool> s2mm_ioc_irq;

  //the exports for the signals
  sc_core::sc_export<sc_core::sc_signal_in_if<bool>> mm2s_ioc_irq_pexp;
  sc_core::sc_export<sc_core::sc_signal_in_if<bool>> s2mm_ioc_irq_pexp;

protected:
  //REGISTER LIST
  //Memory Mapped to Stream registers
  //MM2S DMA control register
  sc_dt::sc_uint<32> mm2s_dmacr;
  //MM2S DMA status register
  sc_dt::sc_uint<32> mm2s_dmasr;
  //MM2S source address register (lower 32bits)
  sc_dt::sc_uint<32> mm2s_sa;
  //MM2S length register (num. of bytes to transfer)
  sc_dt::sc_uint<32> mm2s_length;


  //Stream to Memory Mapped registers
  //S2MM DMA control register
  sc_dt::sc_uint<32> s2mm_dmacr;
  //S2MM DMA status register
  sc_dt::sc_uint<32> s2mm_dmasr;
  //S2MM destination address register (lower 32bits)
  sc_dt::sc_uint<32> s2mm_da;
  //S2MM length register (num. of bytes to transfer)
  sc_dt::sc_uint<32> s2mm_length;
  //REGISTER LIST END

  //the IP internal register that accepts the mm2s data
  sc_dt::sc_uint<32> mm2s_data;

  //the IP internal register that sends the s2mm data
  sc_dt::sc_uint<32> s2mm_data;

  typedef tlm::tlm_base_protocol_types::tlm_payload_type pl_t;

  //Counter variable for throughput measurement
  sc_dt::uint64 mm2s_transfer_throughput;
  sc_dt::uint64 s2mm_transfer_throughput;

  //blocking transport method for the register conf. socket
  void b_transport(pl_t&, sc_core::sc_time&);

  //main threads - will impement a infinite loop with a quantumkeeper
  void acc_calc_mm2s_process();
  void acc_calc_s2mm_process();

  //feedback method for debugging
  void msg(const pl_t&);

  //throughput measurement thread
  void throughput_measure_process();
};

#endif
