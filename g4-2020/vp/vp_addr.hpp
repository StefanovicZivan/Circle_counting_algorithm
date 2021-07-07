#ifndef _VP_ADDR_H_
#define _VP_ADDR_H_


//Base address for DMA
const sc_dt::uint64 VP_ADDR_AXI = 0x43C00000;
//Address offsets for DMA registers
const sc_dt::uint64 MM2S_DMACR_OFFSET  = 0;
const sc_dt::uint64 MM2S_DMASR_OFFSET  = 4;  //04 hex
const sc_dt::uint64 MM2S_SA_OFFSET     = 24; //18 hex
const sc_dt::uint64 MM2S_LENGTH_OFFSET = 40; //28 hex
const sc_dt::uint64 S2MM_DMACR_OFFSET  = 48; //30 hex
const sc_dt::uint64 S2MM_DMASR_OFFSET  = 52; //34 hex
const sc_dt::uint64 S2MM_DA_OFFSET     = 72; //48 hex
const sc_dt::uint64 S2MM_LENGTH_OFFSET = 88; //58 hex
//End address
const sc_dt::uint64 VP_ADDR_END = VP_ADDR_AXI + 89;


#endif
