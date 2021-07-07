`ifndef ACC_CALC_MASTER_MONITOR_SV
 `define ACC_CALC_MASTER_MONITOR_SV

class acc_calc_master_monitor extends uvm_monitor;

   //control fields
   bit checks_enable = 1;
   bit coverage_enable = 1;

   //TLM port for monitor - scoreboard communication
   uvm_analysis_port#(acc_calc_master_seq_item) item_collected_port;

   //UVM factory registration
   `uvm_component_utils_begin(acc_calc_master_monitor)
      `uvm_field_int(checks_enable, UVM_DEFAULT)
      `uvm_field_int(coverage_enable, UVM_DEFAULT)
   `uvm_component_utils_end

   //virtual interface of the DUV
   virtual interface acc_calc_if vif;

   //coverage groups
   //we will monitor the coverage of the DUV input data
   //we will divide the sent x coordinate and y coordinate
   //ranges into 3 bins, and set illegal bins for invalid values

   //cover group for x and y coordinate values
   covergroup cg_input_coordinate_values;
      option.comment = "Cover group for x and y coordinate values of the input data";
      cp_x_values: coverpoint vif.s00_axis_tdata[9 : 0] {
                                                         bins low = {[0 : 266]};
                                                         bins med = {[267 : 533]};
                                                         bins high = {[534 : 800]};
                                                         illegal_bins out_of_border = {[801 : 1023]};
                                                         }
      cp_y_values: coverpoint vif.s00_axis_tdata[19 : 10] {
                                                           bins low = {[0 : 266]};
                                                           bins med = {[267 : 533]};
                                                           bins high = {[534 : 800]};
                                                           illegal_bins out_of_border = {[801 : 1023]};
                                                           }
   endgroup // cg_values

   //constructor
   function new(string name = "acc_calc_master_monitor", uvm_component parent = null);
      super.new(name, parent);

      //create the TLM port
      item_collected_port = new("item_collected_port", this);

      //create the coverage group, if allowed
      if(coverage_enable)
        this.cg_input_coordinate_values = new();
   endfunction : new

   //connect phase, fetch virtual interface from config. database here
   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      if(!uvm_config_db#(virtual acc_calc_if)::get(this, "", "acc_calc_if", vif))
        `uvm_fatal("NO_VIF", {"virtual interface must be set: ", get_full_name(), ".vif"})
   endfunction : connect_phase

   //main phase, monitor DUV slave interface here
   task main_phase(uvm_phase phase);
      //sequence items, for storing signal values in a transaction form
      acc_calc_master_seq_item trans_collected, trans_clone;
      trans_collected = acc_calc_master_seq_item::type_id::create("trans_collected");

      //monitor DUV signals and store in a transaction
      forever begin
         //wait for aresetn to go high
         while(vif.aresetn !== 1'b1)
           @(posedge vif.aclk);

         //wait for master(DMA) to set the valid and data signal
         //measure the delay
         fork
            //fork1 detects tvalid signal
            @(posedge vif.s00_axis_tvalid);

            //fork2 counts the delay until tvalid is detected
            begin
               forever begin
                  @(posedge vif.aclk);
                  trans_collected.delay++;
               end
            end
         join_any

         //once fork1 finishes, disable fork2
         disable fork;

         //minimal delay so that the driver can set up the signals
         //before the monitor reads them, to avoid race
         #5;

         //store the data and tlast signal
         trans_collected.s00_axis_tdata = vif.s00_axis_tdata;
         trans_collected.s00_axis_tlast = vif.s00_axis_tlast;

         //wait for DUV response
         @(posedge vif.aclk iff vif.s00_axis_tready == 1);

         //sample for coverage
         if(coverage_enable) begin
            if(trans_collected.s00_axis_tdata[31] == 1'b0)
              cg_input_coordinate_values.sample();
         end

         //clone the transaction and send it through the TLM port
         $cast(trans_clone, trans_collected.clone());
         item_collected_port.write(trans_clone);

         //report detected AXI DMA master transaction
         `uvm_info(get_full_name(), $sformatf("Master monitor detected... \n%s", trans_clone.sprint()), UVM_MEDIUM)

         //reset the delay in trans_collected, since it is created before the forever loop
         trans_collected.delay = 0;

         /*ADD OPTIONAL CHECKS HERE*/
      end
   endtask : main_phase

endclass : acc_calc_master_monitor

`endif
