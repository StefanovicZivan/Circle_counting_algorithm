#ifndef _VP_HPP_
#define _VP_HPP_

#include <systemc>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/simple_initiator_socket.h>

#include "acc_calc.hpp"
#include "interconnect.hpp"
#include "ram.hpp"

class vp : sc_core::sc_module
{
public:
    vp(sc_core::sc_module_name);
    tlm_utils::simple_target_socket<vp> cpu_bus_tsoc;
    tlm_utils::simple_target_socket<vp> cpu_mem_tsoc;

    //the exports for the interrupts
    sc_core::sc_export<sc_core::sc_signal_in_if<bool>> mm2s_irq_vp_pexp;
    sc_core::sc_export<sc_core::sc_signal_in_if<bool>> s2mm_irq_vp_pexp;

protected:
    tlm_utils::simple_initiator_socket<vp> vp_bus_isoc;
    tlm_utils::simple_initiator_socket<vp> vp_mem_isoc;

    acc_calc ac;
    interconnect ic;
    ram r;

    typedef tlm::tlm_base_protocol_types::tlm_payload_type  pl_t;
    void b_transport_bus(pl_t&, sc_core::sc_time&);
    void b_transport_mem(pl_t&, sc_core::sc_time&);
};

#endif
