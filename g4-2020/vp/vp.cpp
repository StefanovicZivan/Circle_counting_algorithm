#include "vp.hpp"
#include <tlm_utils/tlm_quantumkeeper.h>
#include <iostream>

using namespace sc_core;
using namespace sc_core;
using namespace tlm;

vp::vp(sc_module_name name) :
	sc_module(name),
	ac("acc_calc"),
	ic("interconnect"),
	r("ram")
{
	//registering b_transports for the target sockets
	cpu_bus_tsoc.register_b_transport(this, &vp::b_transport_bus);
	cpu_mem_tsoc.register_b_transport(this, &vp::b_transport_mem);

	//socket binding
	vp_mem_isoc.bind(r.cpu_mem_tsoc);
	vp_bus_isoc.bind(ic.cpu_bus_tsoc);
	ic.axi_dma_isoc.bind(ac.reg_conf_tsoc);
	ac.dma_read_isoc(r.dma_read_tsoc);
	ac.dma_write_isoc(r.dma_write_tsoc);
	
	//binding port with the export from the IP module
  mm2s_irq_vp_pexp(ac.mm2s_ioc_irq_pexp);
  s2mm_irq_vp_pexp(ac.s2mm_ioc_irq_pexp);

	SC_REPORT_INFO("VP", "Platform is constructed"); 
}
void vp::b_transport_mem(pl_t& pl, sc_time& delay)
{
	vp_mem_isoc->b_transport(pl, delay);
	//SC_REPORT_INFO("VP", "Mem transaction passes ...");
}

void vp::b_transport_bus(pl_t& pl, sc_time& delay)
{
	vp_bus_isoc->b_transport(pl, delay);
	//SC_REPORT_INFO("VP", "Bus transaction passes ...");
}


