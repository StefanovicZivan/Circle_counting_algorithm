#ifndef _RAM_HPP_
#define _RAM_HPP_

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>
#include <vector>

//Size of RAM is modeled as 1/4 of RAM's actual size (512MB), which is 128MB 
//If the size of locations in RAM is 32bit, there are aproximatelly 33,5 million locations
#define RAM_SIZE 33554432

class ram : public sc_core::sc_module
{
public:
	//constructor
	ram(sc_core::sc_module_name);

	//All sockets are target because RAM never initiates transaction
	tlm_utils::simple_target_socket<ram> cpu_mem_tsoc;
	tlm_utils::simple_target_socket<ram> dma_read_tsoc;
	tlm_utils::simple_target_socket<ram> dma_write_tsoc;

	typedef tlm::tlm_base_protocol_types::tlm_payload_type pl_t;

	void b_transport_cpu(pl_t&, sc_core::sc_time&);
  void b_transport_dma_read(pl_t&, sc_core::sc_time&);
  void b_transport_dma_write(pl_t&, sc_core::sc_time&);
  
protected:
  std::vector<sc_dt::sc_uint<32>> ram_mem;
};

#endif
