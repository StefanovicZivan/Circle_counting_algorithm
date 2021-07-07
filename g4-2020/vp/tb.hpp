#ifndef _TB_HPP_
#define _TB_HPP_

#include <tlm_utils/simple_initiator_socket.h>
#include <systemc>
#include <iostream>
#include <string>

using namespace std; 

class tb : public sc_core::sc_module {
public:
    tb(sc_core::sc_module_name);

    //the initiator sockets from the cpu
    tlm_utils::simple_initiator_socket<tb> cpu_bus_isoc;
    tlm_utils::simple_initiator_socket<tb> cpu_mem_isoc;

    //port for the interrupt exports
    sc_core::sc_in<bool> mm2s_irq_in;
    sc_core::sc_in<bool> s2mm_irq_in;

    //fields required to read data from the command line
    string image_path;
    string rad;
protected:

    void test(); //the main tb process that generates the payloads

    typedef tlm::tlm_base_protocol_types::tlm_payload_type pl_t;

    //the interrupt methods that are sensitive to the ports
    void mm2s_irq_method();
    void s2mm_irq_method();
};

#endif

