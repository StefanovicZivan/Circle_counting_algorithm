`ifndef ACC_CALC_ENV_SV
 `define ACC_CALC_ENV_SV

import uvm_pkg::*;
import acc_calc_master_agent_pkg::*;
import acc_calc_slave_agent_pkg::*;


//this class instantiates the agent components
//and the scoreboard, and connects their TLM ports
class acc_calc_env extends uvm_env;

   //agents
   acc_calc_master_agent master_agent;
   acc_calc_slave_agent slave_agent;

   //scoreboard
   acc_calc_scoreboard scoreboard;

   //virtual interface of the DUV
   virtual interface acc_calc_if vif;

   //UVM factory registration
   `uvm_component_utils(acc_calc_env)

   //constructor
   function new(string name = "acc_calc_env", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

   //build phase, get vif from config_db, set vif for agents and scoreboard
   //create the agents and the scoreboard
   function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      //Getting from the configuration database
      if(!uvm_config_db#(virtual acc_calc_if)::get(this, "", "acc_calc_if", vif))
        `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
      //end

      //Setting to the configuration database
      uvm_config_db#(virtual acc_calc_if)::set(this, "master_agent", "acc_calc_if", vif);
      uvm_config_db#(virtual acc_calc_if)::set(this, "slave_agent", "acc_calc_if", vif);
      //end

      //create agents and scoreboard
      scoreboard = acc_calc_scoreboard::type_id::create("scoreboard", this);
      master_agent = acc_calc_master_agent::type_id::create("master_agent", this);
      slave_agent = acc_calc_slave_agent::type_id::create("slave_agent", this);
   endfunction : build_phase

   //connect phase, connect the TLM ports of the agents and scoreboard
   function void connect_phase(uvm_phase phase);
      master_agent.mon.item_collected_port.connect(scoreboard.master_port);
      slave_agent.mon.item_collected_port.connect(scoreboard.slave_port);
   endfunction : connect_phase

endclass : acc_calc_env

`endif
