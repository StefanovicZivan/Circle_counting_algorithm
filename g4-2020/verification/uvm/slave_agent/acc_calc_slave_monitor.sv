`ifndef ACC_CALC_SLAVE_MONITOR_SV
 `define ACC_CALC_SLAVE_MONITOR_SV

class acc_calc_slave_monitor extends uvm_monitor;

   //control fields
   bit checks_enable = 1;
   bit coverage_enable = 1;

   int unsigned num_of_transactions;

   //TLM port for monitor - scoreboard communication
   uvm_analysis_port#(acc_calc_slave_seq_item) item_collected_port;

   //factory registation
   `uvm_component_utils_begin(acc_calc_slave_monitor)
      `uvm_field_int(checks_enable, UVM_DEFAULT)
      `uvm_field_int(coverage_enable, UVM_DEFAULT)
   `uvm_component_utils_end

   //virtual interface of the DUV
   virtual interface acc_calc_if vif;

   //coverage groups
   //we will monitor the DUV output data
   //we will check the ranges of the results
   //as well as checking for the INVALID_PIX_MASK

   covergroup cg_output_coordinate_values;
      option.comment = "Cover group for x and y coordinate values of the output data";
      cp_a_values: coverpoint vif.m00_axis_tdata[9 : 0] {
                                                         option.auto_bin_max = 4;
                                                         }
      cp_b_values: coverpoint vif.m00_axis_tdata[19 : 10] {
                                                           option.auto_bin_max = 4;
                                                           }
     cp_invalid_values: coverpoint vif.m00_axis_tdata[31] {
                                                           bins invalid_value = {1};
                                                           bins valid_value = {0};
                                                           }
      cx_a_valid: cross cp_a_values, cp_invalid_values {
         ignore_bins invalid_a_values = binsof(cp_invalid_values) intersect {1};
         bins valid_a_values = binsof(cp_invalid_values) intersect {0};
      }

      cx_b_valid: cross cp_b_values, cp_invalid_values {
         ignore_bins invalid_b_values = binsof(cp_invalid_values) intersect {1};
         bins valid_b_values = binsof(cp_invalid_values) intersect {0};
      }
   endgroup // cg_output_coordinate_values

   //constructor
   function new(string name = "acc_calc_slave_monitor", uvm_component parent = null);
      super.new(name, parent);

      //create the TLM port
      item_collected_port = new("item_collected_port", this);

      //create coverage groups if allowed
      if(coverage_enable)
        this.cg_output_coordinate_values = new();
   endfunction : new

   //connect phase, fetch virtual interface from config. database here
   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      if(!uvm_config_db#(virtual acc_calc_if)::get(this, "", "acc_calc_if", vif))
        `uvm_fatal("NO_VIF", {"virtual interface must be set: ", get_full_name(), ".vif"})
   endfunction : connect_phase

   //main phase, monitor DUV signals here
   task main_phase(uvm_phase phase);
      //sequence items, for storing signal values in a transaction form
      acc_calc_slave_seq_item tr_collected, tr_clone;
      tr_collected = acc_calc_slave_seq_item::type_id::create("tr_collected");

      //monitor DUV signals and store in a transaction
      forever begin
         //wait for aresetn to go high
         while(vif.aresetn !== 1'b1)
           @(posedge vif.aclk);

         //wait for the DMA and DUV handshake
         //i.e. a clock edge when tready and tvalid are both asserted
         fork
            @(posedge vif.aclk iff (vif.m00_axis_tready == 1 && vif.m00_axis_tvalid == 1));

            //this fork will do optional protocol checks
            begin
               if(checks_enable) begin
                  //the master is not permitted to deassert the tvalid signal before the handshake occurs

                  @(posedge vif.m00_axis_tvalid);

                  //tvalid is asserted, check if a positive edge of clk happens with tvalid == 0 and tready == 1
                  //before the first fork disables this one
                  @(posedge vif.aclk iff (vif.m00_axis_tready == 1 && vif.m00_axis_tvalid == 0));
                  `uvm_error(get_full_name(), "Protocol error: DUV master deasserted tvalid before handshake")

                  //wait for a handshake to terminate this fork
                  forever
                    @(posedge vif.aclk);
               end
            end
         join_any
         disable fork;


         //record the data and tlast signal
         tr_collected.m00_axis_tdata = vif.m00_axis_tdata;
         tr_collected.m00_axis_tlast = vif.m00_axis_tlast;

         //sample for coverage
         if(coverage_enable)
           cg_output_coordinate_values.sample();

         `uvm_info(get_full_name(), "Handshake finished", UVM_HIGH)
         //clone the transaction and send it through the TLM port
         $cast(tr_clone, tr_collected.clone());
         item_collected_port.write(tr_clone);

         //report the transaction
         `uvm_info(get_full_name(), $sformatf("Slave monitor detected... \n%s", tr_clone.sprint()), UVM_MEDIUM)
         num_of_transactions++;
      end

   endtask : main_phase

endclass : acc_calc_slave_monitor

`endif
