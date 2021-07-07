`ifndef ACC_CALC_MASTER_GROUP2_SEQ_SV
 `define ACC_CALC_MASTER_GROUP2_SEQ_SV

//for group2, we want to generate a few scenarios

//in the verification plan :
//check 2.1 - fill the input buffer with 16 pixels
//check 2.2 - fill the buffer with random number of data, less than 16, with proper tlast generation
//check 2.4 - write data into input buffer with various delays
//check 2.6 - attempt to write to buffer while it is full, or a valid tlast was set

class acc_calc_master_group2_seq extends acc_calc_master_base_seq;

   //random number of transactions for check 2.2 and 2.4
   rand int unsigned num_of_buffer_tr; // 2.2
   rand int unsigned num_of_random_tr; // 2.4

   //constraint for 2.2
   constraint c_buff_length {
      num_of_buffer_tr < 16;
      num_of_buffer_tr >= 1;
   }

   //constraint for 2.4, change as necessary
   constraint c_rand_tr {
      num_of_random_tr < 30;
      num_of_random_tr > 16;
   }

   //UVM factory registration
   `uvm_object_utils(acc_calc_master_group2_seq)

   //constructor
   function new(string name = "acc_calc_master_group2_seq");
      super.new(name);
   endfunction : new

   virtual task body();
      //check 2.1
      //send a random radius
      `uvm_do_with(req, {req.s00_axis_tdata[31] == 1'b1;
                         req.s00_axis_tdata[9 : 0] < 201;
                         req.delay == 0; req.s00_axis_tlast == 1'b0;})
      repeat(16) begin
         `uvm_do_with(req, {req.s00_axis_tdata[31] == 1'b0; req.delay == 0; req.s00_axis_tlast == 1'b0;})
      end

      //check 2.2 and 2.6
      //since this part of the code will start right after the check 2.1 happens, when the buffer is filled up
      for(int i = 0; i < num_of_buffer_tr; i++) begin
         if(i == num_of_buffer_tr - 1)
           `uvm_do_with(req, {req.s00_axis_tdata[31] == 1'b0; req.delay == 0; req.s00_axis_tlast == 1'b1;})
         else
           `uvm_do_with(req, {req.s00_axis_tdata[31] == 1'b0; req.delay == 0; req.s00_axis_tlast == 1'b0;})
      end

      //check 2.4
      //we need to send the radius again, since tlast was asserted for 2.2

      `uvm_do_with(req, {req.s00_axis_tdata[31] == 1'b1;
                         req.s00_axis_tdata[9 : 0] < 201;
                         req.s00_axis_tlast == 1'b0;})
      for(int i = 0; i < num_of_random_tr; i++) begin
         if(i == num_of_random_tr - 1)
           `uvm_do_with(req, {req.s00_axis_tdata[31] == 1'b0; req.s00_axis_tlast == 1'b1;})
         else
           `uvm_do_with(req, {req.s00_axis_tdata[31] == 1'b0; req.s00_axis_tlast == 1'b0;})
      end

   endtask : body
endclass // acc_calc_master_group2_seq

`endif
