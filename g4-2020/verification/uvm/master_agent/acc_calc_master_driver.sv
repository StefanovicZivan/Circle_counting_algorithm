`ifndef ACC_CALC_MASTER_DRIVER_SV
 `define ACC_CALC_MASTER_DRIVER_SV

//this driver will immitate the AXI DMA master channel
//i.e. it will drive the slave interface of acc_calc_ip
class acc_calc_master_driver extends uvm_driver#(acc_calc_master_seq_item);

   //UVM factory registation
   `uvm_component_utils(acc_calc_master_driver)

   //virtual interface of the DUV
   virtual interface acc_calc_if vif;

   //constructor
   function new(string name = "acc_calc_master_driver", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

   //connect phase, get the interface from the conf. database
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
endclass : acc_calc_master_driver

//task for driving transactions
task acc_calc_master_driver::drive_tr();
   //wait for aresetn to go high
   while(vif.aresetn != 1'b1)
     @(posedge vif.aclk);

   //if a delay is specified, wait
   if(req.delay > 0) begin
      repeat(req.delay)
        @(posedge vif.aclk);
   end

   //set the data signals and the valid signal
   vif.s00_axis_tdata <= req.s00_axis_tdata;
   vif.s00_axis_tvalid <= 1'b1;

   //set the tlast signal
   vif.s00_axis_tlast <= req.s00_axis_tlast;
   //@(posedge vif.aclk);

   //wait for tready to go high
   @(posedge vif.aclk iff vif.s00_axis_tready == 1);

   //deassert the tvalid and tlast signal
   vif.s00_axis_tvalid <= 1'b0;
   vif.s00_axis_tlast <= 1'b0;


endtask : drive_tr

`endif
