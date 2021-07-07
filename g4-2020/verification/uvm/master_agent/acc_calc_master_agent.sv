`ifndef ACC_CALC_MASTER_AGENT_SV
 `define ACC_CALC_MASTER_AGENT_SV

//the agent component is at a higher level of hierarchy
//compared to the driver, monitor and sequencer
//it just instantiates and connects those three components
class acc_calc_master_agent extends uvm_agent;

   //components
   acc_calc_master_driver drv;
   acc_calc_master_monitor mon;
   acc_calc_master_sequencer seqr;

   //virtual interface of the DUV
   virtual interface acc_calc_if vif;

   //configuration
   /*it is optional, since the agents must be active
    in this envrionment
    acc_calc_config cfg;
   */

   //UVM factory registration
   `uvm_component_utils(acc_calc_master_agent)

   //constructor
   function new(string name = "acc_calc_master_agent", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

   //build phase, create the components, set the database
   function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      //Getting from configuration database
      if(!uvm_config_db#(virtual acc_calc_if)::get(this, "", "acc_calc_if", vif))
        `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})

      /*
       if(!uvm_config_db#(acc_calc_config)::get(this, "", "acc_calc_config", cfg))
         `uvm_fatal("NO_CONFIG", {"Config object must be set for: ", get_full_name(), ".cfg"})
       */
      //end

      //Setting to configuration database
      uvm_config_db#(virtual acc_calc_if)::set(this, "*", "acc_calc_if", vif);
      //end

      drv = acc_calc_master_driver::type_id::create("drv", this);
      seqr = acc_calc_master_sequencer::type_id::create("seqr", this);
      mon = acc_calc_master_monitor::type_id::create("mon", this);
   endfunction : build_phase

   //connect phase, connect the TLM ports of the driver and sequencer
   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
   endfunction : connect_phase

endclass : acc_calc_master_agent

`endif
