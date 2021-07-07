#include "interconnect.hpp"
#include "vp_addr.hpp"
#include <string>
#include <sstream>

using namespace std;
using namespace tlm;
using namespace sc_core;
using namespace sc_dt;

interconnect::interconnect(sc_module_name name) : sc_module(name)
{
	//Target socket is connected to blocking trasport interface
	cpu_bus_tsoc.register_b_transport(this, &interconnect::b_transport);
}

void interconnect::b_transport(pl_t& pl, sc_core::sc_time& offset)
{
	uint64 addr = pl.get_address();
	uint64 taddr;
  //APPROX. CLOCK PERIOD
  sc_time clk_period(10, SC_NS);
  
	//Defining the transaction duration
	offset += clk_period;

	//Checking if addr is in DMA register address range
	if(addr >= VP_ADDR_AXI && addr < VP_ADDR_END)
	{
		//Translating the base address to local
		taddr = addr & 0x000000FF;
		pl.set_address(taddr);
		axi_dma_isoc->b_transport(pl, offset);
		msg(pl);
	}

	/*Setting the base address again so that translation of addresses
	wouldn't affect the component that initiated transcation*/
	pl.set_address(addr);
}

void interconnect::msg(const pl_t& pl)
{
	//transactions
}

