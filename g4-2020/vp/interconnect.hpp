#ifndef _ICT_HPP_
#define _ICT_HPP_

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/simple_initiator_socket.h>

class interconnect : public sc_core::sc_module
{
public:
	interconnect(sc_core::sc_module_name);

	//Target socket connected to CPU
	tlm_utils::simple_target_socket<interconnect> cpu_bus_tsoc;
	//Initiator socket connected to DMA
	tlm_utils::simple_initiator_socket<interconnect> axi_dma_isoc;

protected:
	//Defines the type of transaction
	typedef tlm::tlm_base_protocol_types::tlm_payload_type pl_t;

	//Initiator communicates with the target memory using the blocking transport interface
	void b_transport(pl_t&, sc_core::sc_time&);

	//Method for displayng transactions
	void msg(const pl_t&);
};

#endif
