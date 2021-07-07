#include "ram.hpp"
#include <tlm>

using namespace sc_core;
using namespace tlm;
using namespace sc_dt;


ram::ram(sc_module_name name) :
	sc_module(name),
	cpu_mem_tsoc("cpu_mem_tsoc"),
	dma_read_tsoc("dma_read_tsoc"),
	dma_write_tsoc("dma_write_tsoc"),
  ram_mem(10000000)
{
  std::cout << "REGISTERING B TRANSPORT IN RAM" << std::endl;
	cpu_mem_tsoc.register_b_transport(this, &ram::b_transport_cpu);
	dma_read_tsoc.register_b_transport(this, &ram::b_transport_cpu);
	dma_write_tsoc.register_b_transport(this, &ram::b_transport_cpu);

}

void ram::b_transport_cpu(pl_t& pl, sc_time& offset)
{
	tlm_command    cmd  = pl.get_command();
	uint64         addr = pl.get_address();
	unsigned char *data = pl.get_data_ptr();
	unsigned int   len  = pl.get_data_length();

  //APPROX. CLOCK PERIOD
  sc_time clk_period(10, SC_NS);

	switch(cmd)
    {
		case TLM_WRITE_COMMAND:
      {
        if(addr < 10000000) 
          {
        		ram_mem[addr] = *((sc_uint<32>*) data);
        		//std::cout << "Succesfully wrote: " << std::hex << ram_mem[addr] << " to RAM at location " << addr;
        		//std::cout << " @ " << sc_time_stamp() << std::endl;
      		}
        else 
      		{
        		pl.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
        		SC_REPORT_ERROR("RAM", "TLM bad address");
      		}
        break;
      }
		case TLM_READ_COMMAND:
      {
        if(addr < 10000000) 
          {
        		memcpy(data, &ram_mem[addr], sizeof(ram_mem[addr]));
        		//std::cout << "Succesfully read: " << std::hex << ram_mem[addr] << " from RAM at location " << addr;
        		//std::cout << " @ " << sc_time_stamp() << std::endl;
      		}
        else 
      		{
        		pl.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
        		SC_REPORT_ERROR("RAM", "TLM bad address");
      		}
        break;
      }
		default:
      {
        pl.set_response_status( TLM_COMMAND_ERROR_RESPONSE );
        SC_REPORT_ERROR("RAM", "TLM bad command");
        break;
      }
    }
	//offset configuration
	offset += clk_period;
}

/*
void ram::b_transport_dma_read(pl_t& pl, sc_time& offset)
{
	tlm_command    cmd  = pl.get_command();
	uint64         addr = pl.get_address();
	unsigned char *data = pl.get_data_ptr();
	unsigned int   len  = pl.get_data_length();
	
	switch(cmd)
    {
		case TLM_WRITE_COMMAND:
      {
        if(addr < 2000) 
        	{
            ram_mem[addr] = *((sc_uint<32>*) data);
        	}
        else 
        	{
            pl.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
            SC_REPORT_ERROR("RAM", "TLM bad address");
        	}
      }
		case TLM_READ_COMMAND:
      {
        if(addr < 2000) 
        	{
            data = (unsigned char*) &ram_mem[addr];
        	}
        else 
        	{
            pl.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
            SC_REPORT_ERROR("RAM", "TLM bad address");
        	}
      }
		default:
      {
        pl.set_response_status( TLM_COMMAND_ERROR_RESPONSE );
        SC_REPORT_ERROR("RAM", "TLM bad command");
        break;
      }
    }
	//offset configuration
	offset += sc_time(4, SC_NS);
}

void ram::b_transport_dma_write(pl_t& pl, sc_time& offset)
{
	tlm_command    cmd  = pl.get_command();
	uint64         addr = pl.get_address();
	unsigned char *data = pl.get_data_ptr();
	unsigned int   len  = pl.get_data_length();
	
	switch(cmd)
    {
		case TLM_WRITE_COMMAND:
      {
        if(addr < 2000) 
        	{
            ram_mem[addr] = *((sc_uint<32>*) data);
        	}
        else 
        	{
            pl.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
            SC_REPORT_ERROR("RAM", "TLM bad address");
        	}
      }
		case TLM_READ_COMMAND:
      {
        if(addr < 2000)
        	{
            data = (unsigned char*) &ram_mem[addr];
        	}
        else 
        	{
            pl.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
            SC_REPORT_ERROR("RAM", "TLM bad address");
        	}
      }
		default:
      {
        pl.set_response_status( TLM_COMMAND_ERROR_RESPONSE );
        SC_REPORT_ERROR("RAM", "TLM bad command");
        break;
      }
    }
	//offset configuration
	offset += sc_time(4, SC_NS);
}

tlm_sync_enum ram::nb_transport_fw(pl_t& pl, phase_t& phase, sc_time& offset)
  {
	return TLM_ACCEPTED;
  }



  //Method used for debbuging
  unsigned int ram::transport_dbg(pl_t& pl)
  {
	tlm_command cmd = pl.get_command();
	unsigned char* ptr = pl.get_data_ptr();

	if ( cmd == TLM_READ_COMMAND )
  memcpy(ptr, ram_mem, RAM_SIZE);
	else if ( cmd == TLM_WRITE_COMMAND )
  memcpy(ram_mem, ptr, RAM_SIZE);

	return RAM_SIZE;
  }
*/
