`ifndef ACC_CALC_SCOREBOARD_SV
 `define ACC_CALC_SCOREBOARD_SV


//declaring ports here, because there is more than one
`uvm_analysis_imp_decl(_master_tr)
`uvm_analysis_imp_decl(_slave_tr)

class acc_calc_scoreboard extends uvm_scoreboard;

   //control fields
   bit checks_enable = 1;
   bit coverage_enable = 1;

   const real M_PI =  3.14159265358979323846; /* pi value as defined in math.h*/

   //fixed point values of cosine and sine
   //we use 4 bits for the integer part, 6 for the fractal part
   real       sin_val_array[360];           // sine values, in fixed point representation
   real       cos_val_array[360];           // cosine values, 0 - 360 degrees, in 1 degree steps
   real       sin180;

   bit [31 : 0] expected_val_array[360]; // array for storing expected values
   int unsigned expected_num_of_tr;      // expected number of s2mm transactions

   //number of received transactions
   int unsigned num_of_master_tr = 0; // DMA master transactions
   int unsigned num_of_slave_tr = 0;  // DMA slave transactions

   bit buffer_full;             // bit that indicates that the input buffer should not recieve
                                // any new data until the results are calculated for the pixels in the buffer
                            
   bit last_pulse = 1'b0;       //indicates whether the last pulse is sent
   //queues to hold the master/slave AXI DMA transactions
   acc_calc_master_seq_item duv_rcvd_pkt_que[$]; // DUV recieved - DMA is the master
   acc_calc_slave_seq_item duv_sent_pkt_que[$];  // DUV sent - DMA is the slave

   acc_calc_master_seq_item current_pixel; // current pixel for which we are checking the expected values

   int unsigned radius;         // extracted radius from DMA master channel data

   //TLM ports for communication with Master/Slave agent
   uvm_analysis_imp_master_tr#(acc_calc_master_seq_item, acc_calc_scoreboard) master_port;
   uvm_analysis_imp_slave_tr#(acc_calc_slave_seq_item, acc_calc_scoreboard) slave_port;

   //UVM factory registration
   `uvm_component_utils_begin(acc_calc_scoreboard)
      `uvm_field_int(checks_enable, UVM_DEFAULT)
      `uvm_field_int(coverage_enable, UVM_DEFAULT)
   `uvm_component_utils_end

   //constructor
   function new(string name = "acc_calc_scoreboard", uvm_component parent = null);
      super.new(name, parent);

      //construct the TLM ports
      master_port = new("master_port", this);
      slave_port = new("slave_port", this);

      //initialize the cosine and sine arrays
      init_cos_sin_array(cos_val_array, sin_val_array);
   endfunction : new

   //write function of the TLM ports
   //monitor calls this function when sending transactions
   //through the TLM port
   function void write_master_tr(input acc_calc_master_seq_item tr);
      //transaction clone, since we musn't edit the transaction
      //that is passed through the port
      acc_calc_master_seq_item tr_clone;
      $cast(tr_clone, tr.clone());

      if(duv_rcvd_pkt_que.size() == 0)
        buffer_full = 1'b0;

      //check if AXI DMA master channel has sent in a pixel or radius
      if(tr_clone.s00_axis_tdata[31] === 1'b1)
        $cast(radius, tr_clone.s00_axis_tdata[9 : 0]); // cast the 10bit logic to int unsigned
      else
        duv_rcvd_pkt_que.push_back(tr_clone); // store the sequence item that the DMA sent

      num_of_master_tr++;

      //checking is done here
      if(checks_enable) begin
         //CHECK 2.6 - DUV can't recieve any data from the DMA until the previous burst
         buff_full_asrt : assert(buffer_full == 1'b0) begin
            //pass block
            `uvm_info(get_full_name(), "mm2s data recieved correctly", UVM_HIGH)
         end else begin
            //fail block
            `uvm_error(get_full_name(), "DUV recieved new data while the buffer was full or while tlast was set")
         end //end of CHECK 2.6

         //check if the buffer is full
         if(duv_rcvd_pkt_que.size() == 16 || tr_clone.s00_axis_tlast == 1'b1)
           buffer_full = 1'b1;
           
         if(tr_clone.s00_axis_tlast == 1'b1)
           last_pulse = 1'b1;
         else
           last_pulse = 1'b0;
      end
   endfunction : write_master_tr

   function void write_slave_tr(input acc_calc_slave_seq_item tr);
      //transaction clone, since we musn't edit the transaction
      //that is passed through the port
      acc_calc_slave_seq_item tr_clone;
      $cast(tr_clone, tr.clone());

      /*
      //store the sequence items sent by the DUV in a queue
      duv_sent_pkt_que.push_back(tr_clone);
       */

      num_of_slave_tr++;

      //checking is done here
      if(checks_enable) begin
         //CHECK 2.3 - DMA should not recieve result data until the input buffer is full
         //or the tlast is set on the final transaction in the buffer
         if(num_of_slave_tr == 1) begin
           valid_resp_timing_asrt : assert(duv_rcvd_pkt_que.size() == 16 ||
                                           duv_rcvd_pkt_que[duv_rcvd_pkt_que.size() - 1].s00_axis_tlast == 1'b1) begin
              //pass block
              `uvm_info(get_full_name(), "Response timing is valid", UVM_HIGH)
              //set the expected number of s2mm transactions, based on the size of the duv_rcvd_pkt queue size
              expected_num_of_tr = 360 * duv_rcvd_pkt_que.size();
              //push out the first pixel for checking
              current_pixel = duv_rcvd_pkt_que.pop_back();
              ref_model_func(current_pixel.s00_axis_tdata, radius);
           end else begin
              //fail block
              `uvm_error(get_full_name(), "DUV responded before the input buffer is full, or the s00_axis_tlast was set")
              //set the expected number of s2mm transactions to zero, so that the other checks won't be executed
              expected_num_of_tr = 0;
           end
         end //end of if(num_of_slave_tr == 1)

         //if check 2.3 was a success, continue with the other checks
         //we know that it is a success, if expected_num_of_tr > 0
         if(expected_num_of_tr > 0) begin
            //CHECK 1.5 - check if the DUV recognizes negative values coordinates of the circle
            //around the given pixel, and sets the 31st bit in m00_axis_tdata to 1 if it is negative
            //(num_of_slave_tr - 1) shifts [1 : 360] range to [0 : 359]
            //doing % 360 always gives us a range [0 : 359]
            valid_pix_asrt : assert(tr_clone.m00_axis_tdata[31] ==
                                    expected_val_array[(num_of_slave_tr - 1) % 360][31]) begin
               //pass block
               `uvm_info(get_full_name(), "Valid pixel bit is set properly", UVM_HIGH)

               if(tr_clone.m00_axis_tdata[31] !== 1'b1) begin
                  //CHECK 1.3 - check if recieved values are as expected
                  value_asrt : assert(tr_clone.m00_axis_tdata == expected_val_array[(num_of_slave_tr - 1) % 360]) begin
                     //pass block
                     `uvm_info(get_full_name(), "Value matches expected", UVM_HIGH)
                  end else begin
                     //fail block
                     `uvm_error(get_full_name(), $sformatf("Value mismatch for angle %0d; x-coordinate %0d; y-coordinate %0d, radius %0d: expected x = %0d y = %0d; recieved x = %0d y = %0d",
                                                           (num_of_slave_tr - 1) % 360,
                                                           current_pixel.s00_axis_tdata[9 : 0],
                                                           current_pixel.s00_axis_tdata[19 : 10],
                                                           radius,
                                                           expected_val_array[(num_of_slave_tr - 1) % 360][9 : 0],
                                                           expected_val_array[(num_of_slave_tr - 1) % 360][19 : 10],
                                                           tr_clone.m00_axis_tdata[9 : 0],
                                                           tr_clone.m00_axis_tdata[19 : 10]))
                  end //end of CHECK 1.3
               end
            end else begin
               //fail block
               `uvm_error(get_full_name(), $sformatf("Valid pixel bit is not set properly for angle %0d: expected %0b, recieved %0b",
                                                     (num_of_slave_tr - 1) % 360,
                                                     expected_val_array[(num_of_slave_tr - 1) % 360][31],
                                                     tr_clone.m00_axis_tdata[31]))
            end //end of CHECK 1.5

            if(num_of_slave_tr == expected_num_of_tr) begin
               num_of_slave_tr = 0;
               
               if(last_pulse == 1'b1) begin
                 //CHECK 1.4 - check if the DUV sets m00_axis_tlast on every finished buffer
                 master_tlast_asrt : assert(tr_clone.m00_axis_tlast == 1'b1) begin
                    //pass block
                    `uvm_info(get_full_name(), "m00_axis_tlast is set properly", UVM_HIGH)

                    //reset the num_of_slave_tr counter to 0
                    num_of_slave_tr = 0;
                 end else begin
                    //fail block
                    `uvm_error(get_full_name(), "m00_axis_tlast isn't set properly")
                 end //end of CHECK 1.4
               end
            end //end of if(num_of_slave_tr == expected_num_of_tr)
            else begin
               //push out the next pixel to be verified, after 360 verified points
               if(num_of_slave_tr % 360 == 0) begin
                  //call the ref. model function to calculate expected results
                  //based on the current pixel
                  current_pixel = duv_rcvd_pkt_que.pop_back();
                  ref_model_func(current_pixel.s00_axis_tdata, radius);
               end
            end
         end //end of if(expected_num_of_tr > 0)
      end // if (checks_enable)

   endfunction : write_slave_tr

   extern function void ref_model_func(input bit [31 : 0] input_data, input int unsigned radius);
   extern function void init_cos_sin_array(ref real cos_val_array[360], ref real sin_val_array[360]);

endclass : acc_calc_scoreboard

//function used to initialize the sine and cosine arrays in fixed point representation
function void acc_calc_scoreboard::init_cos_sin_array(ref real cos_val_array[360], ref real sin_val_array[360]);
   real theta_rad;
   real cos_value_float, sin_value_float;
   int  cos_value_bin, sin_value_bin;
   real cos_value_fix, sin_value_fix;
   //iterate through 0 - 360 degrees with 1 degree step
   for(int theta = 0; theta < 360; theta++) begin
      //same steps as in the SystemC model
      theta_rad = theta * M_PI / 180;

      //1. calculate cos(theta) and sin(theta) - degrees must be converted to radians
      cos_value_float = $cos(theta_rad); // non quantized
      sin_value_float = $sin(theta_rad); // non quantized

      //now we must convert the floating point to fixed point
      //the DUV uses 6 bits for the fractal part, and 4 for the integer part
      //we multiply by 2^6, round it, and the resulting integer, converted to binary
      //is the fixed point representation, with the point at the correct position

      if(cos_value_float > 0)
        cos_value_bin = $floor(cos_value_float * 64);
      else
        cos_value_bin = $ceil(cos_value_float * 64);

      if(sin_value_float > 0)
        sin_value_bin = $floor(sin_value_float * 64);
      else
        sin_value_bin = $ceil(sin_value_float * 64);

      //now we have a value that can be represented in fixed point
      //the implicit rounding gives us a fixed point value
      //now we just shift the rounded value by the scale, i.e. 2^(-6)
      cos_value_fix = cos_value_bin * 0.015625;
      sin_value_fix = sin_value_bin * 0.015625;

      cos_val_array[theta] = cos_value_fix;
      sin_val_array[theta] = sin_value_fix;

   end // for (int theta = 0; theta < 360; theta++)

   //added due to quantization issues
   cos_val_array[120] = -0.5;
   sin_val_array[330] = -0.484375;
   cos_val_array[300] = 0.5;
   sin_val_array[150] = 0.484375;

endfunction : init_cos_sin_array

//referent model implementation
function void acc_calc_scoreboard::ref_model_func(input bit [31 : 0] input_data, input int unsigned radius);
   int unsigned x_pos, y_pos;   // x and y positions of the recieved white pixel
   int unsigned a_pos, b_pos;   // circle values around the (x,y) center
   bit [9 : 0]  a_pos_bin, b_pos_bin;
   real r1, r2;                 // r1 = rad * cos; r2 = rad * sin
   real r1_r, r2_r;
   bit [31 : 0] expected_value;

   $cast(x_pos, input_data[9 : 0]); // bits 9 : 0 contain the x position
   $cast(y_pos, input_data[19 : 10]); // next 10 bits contain the y position

   //same steps as the SystemC model
   for(int theta = 0; theta < 360; theta++) begin
      //step 1 - calculate radius * cos and radius * sin
      //we multiplied a fixed point value with an integer represented with 10 bits
      //the result will be : 14 bits for integer part, 6 bits for fractal
      r1 = radius * cos_val_array[theta];
      r2 = radius * sin_val_array[theta];

      //calculate x_pos - r1 to check if the result is < 0
      //same for y_pos

      r1_r = x_pos - r1;
      r2_r = y_pos - r2;

      //step 2 - check if the result of x_pos - r1 and y_pos - r2 will be negative
      if((r1_r < 0) || (r2_r < 0)) begin
        expected_value[31] = 1'b1; // set the INVALID_PIX_MASK
      end
      else begin
         //step 3 - calculate x - r1 and y - r2 and round the value to the closest integer
         $cast(a_pos, x_pos - r1); // implicit rounding will be done here
         $cast(b_pos, y_pos - r2);

         //step 4 - convert to binary, and pack the data
         $cast(a_pos_bin, a_pos);
         $cast(b_pos_bin, b_pos);

         expected_value[9 : 0] = a_pos_bin;
         expected_value[19 : 10] = b_pos_bin;
         expected_value[31 : 20] = 12'h000;
      end // else: !if((x_pos < r1) || (y_pos < r2))

      //store the data
      expected_val_array[theta] = expected_value;
   end
endfunction : ref_model_func

`endif
