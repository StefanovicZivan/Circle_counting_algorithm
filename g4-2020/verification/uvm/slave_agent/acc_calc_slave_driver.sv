`ifndef ACC_CALC_SLAVE_DRIVER_SV
 `define ACC_CALC_SLAVE_DRIVER_SV

//this driver will only drive the m00_axis_tready signal
//the rest of the signals are driven by acc_calc_ip
class acc_calc_slave_driver extends uvm_driver#(acc_calc_slave_seq_item);

   //UVM factory registration
   `uvm_component_utils(acc_calc_slave_driver);

   //virtual interface of the DUV
   virtual interface acc_calc_if vif;

   //constructor
   function new(string name = "acc_calc_slave_driver", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

   //connect phase, get the interface from the configuration database
   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      if(!uvm_config_db#(virtual acc_calc_if)::get(this, "", "acc_calc_if", vif))
        `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
   endfunction : connect_phase

   //main phase, signal driving happens here
   task main_phase(uvm_phase phase);
      //forever repeat the handshake protocol with the sequencer
      forever begin
         //fetch sequence item from the sequencer
         seq_item_port.get_next_item(req);

         //drive the transaction
         drive_tr();

         //finish the handshake
         seq_item_port.item_done();
      end
   endtask : main_phase

   extern virtual task drive_tr();
endclass : acc_calc_slave_driver

//task for driving transactions
task acc_calc_slave_driver::drive_tr();
   //wait for reset to go high
   while(vif.aresetn != 1'b1)
     @(posedge vif.aclk);

   //if a delay is specified
   if(req.delay > 0) begin
      //deassert the tready signal
      vif.m00_axis_tready <= 1'b0;
      repeat(req.delay)
        @(posedge vif.aclk);
   end

   //assert tready signal
   #0.1;                        // minimal delay, to ensure that the rising edge
                                // of tready is ignored, as would in real hardware,
                                // and the handshake happens on the next clock cycle
   vif.m00_axis_tready <= 1'b1;

   //wait for tvalid
   //set inactivity timer of 1000ns, to break the forever loop
   //in the sequence
   fork
      @(posedge vif.aclk iff vif.m00_axis_tvalid == 1);

      begin
         #5000ns;
         //if the inactivity timer activates, set the delay to > 10
         //which signalizes that there is no activity
         //since the constraint randomizes delay to be < 10
         req.delay = 100;
      end
   join_any
   disable fork;

   //we have a response, record the data
   req.m00_axis_tdata = vif.m00_axis_tdata;

   //record the m00_axis_tlast signal asserted by the DUV
   req.m00_axis_tlast = vif.m00_axis_tlast;

endtask : drive_tr

`endif
