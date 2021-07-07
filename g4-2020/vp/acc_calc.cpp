#define SC_INCLUDE_FX

#include "acc_calc.hpp"
#include <tlm>
#include <tlm_utils/tlm_quantumkeeper.h>
#include <sstream>
#include <cmath>

using namespace sc_core;
using namespace sc_dt;
using namespace std;
using namespace tlm;

//bit width of the numbers used for fixed point calculation
#define FP_WIDTH 10

//position of the fixed point
#define FP_POS 4

//APPROX. CLOCK PERIOD
sc_time clk_period(10, SC_NS);


//mask for radius/pixel distinction
#define RAD_PIX_MASK   0x80000000
#define VALID_PIX_MASK 0x80000000

//the radius of the circle used for the detection
sc_int<10> det_radius;

//data type used for fixed point calculation
typedef sc_fixed_fast<FP_WIDTH, FP_POS> num_t;


SC_HAS_PROCESS(acc_calc);

//counters used to count the number of completed transfers
//their default values will be -1, which means they arent initialized
sc_int<32> mm2s_transfer_counter = -1;
sc_int<32> s2mm_transfer_counter = -1;

//indicator that mm2s part has finished transfer and the s2mm can start
bool transfer_finished = false;

//indicator that the s2mm has finished all transfers, so that the throughput measurement halts
bool end_of_measurement = false;

//mutex for ensuring that access to critical parts of code is resolved
sc_mutex mtx;

//Burst sizes for s2mm and mm2s channels
sc_uint<5> mm2s_burst_size = 16;
sc_uint<5> s2mm_burst_size = 16;

//the buffer used to store the mm2s burst package
std::vector<sc_dt::sc_uint<32>> mm2s_burst_buffer;

acc_calc::acc_calc(sc_module_name name) : sc_module(name), reg_conf_tsoc("reg_conf_tsoc"),
                                          dma_read_isoc("dma_read_isoc"), mm2s_dmacr(MM2S_DMACR_DEF),
                                          mm2s_dmasr(MM2S_DMASR_DEF), mm2s_sa(MM2S_SA_DEF),
                                          mm2s_length(MM2S_LENGTH_DEF), s2mm_dmacr(S2MM_DMACR_DEF),
                                          s2mm_dmasr(S2MM_DMASR_DEF), s2mm_da(S2MM_DA_DEF),
                                          s2mm_length(S2MM_LENGTH_DEF), dma_write_isoc("dma_write_isoc"),
                                          mm2s_ioc_irq("mm2s_ioc_irq_signal"), s2mm_ioc_irq("s2mm_ioc_irq_signal"){

  cout << "MM2S_DMACR = " << mm2s_dmacr << endl; //test
  //register the b_transport method for the target socket
  reg_conf_tsoc.register_b_transport(this, &acc_calc::b_transport);

  //bind the exports with the signals
  mm2s_ioc_irq_pexp.bind(mm2s_ioc_irq);
  s2mm_ioc_irq_pexp.bind(s2mm_ioc_irq);

  //register the main thread
  SC_THREAD(acc_calc_mm2s_process);
  SC_THREAD(acc_calc_s2mm_process);

  //register the throughput measurement thread
  SC_THREAD(throughput_measure_process);

  mm2s_transfer_throughput = 0;
  s2mm_transfer_throughput = 0;
}


//definition of the b_transport method for register configuration
void acc_calc::b_transport(pl_t& payload, sc_time& offset) {
  tlm_command    cmd  = payload.get_command();
  uint64         addr = payload.get_address();
  unsigned char* data = payload.get_data_ptr();
  switch(cmd) {
  case TLM_WRITE_COMMAND:
    {
      //extract the configuration out of the payload
      sc_uint<32> conf;
      conf = *((sc_uint<32>*) data);
      switch(addr) {
      case MM2S_DMACR_OFFSET:
        //1st bit, bits 5 to 11, and the 15th bit are read only and shall be ignored
        //the 1st bit is always 1, while the others are 0
        conf &= ~(0x1 << 15);   //keep 15th bit at 0
        conf &= ~(0x7F << 5);    //keep bits 5-11 at 0
        conf |= (0x1 << 1);     //keep 1st bit at 1

        //load the configuration into the register
        mm2s_dmacr = conf;
        //cout << showbase;
        //cout << "MM2S_DMACR CHANGED TO: " << hex << mm2s_dmacr << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case MM2S_DMASR_OFFSET:
        //bits 12-14 are write to clear, while the rest are RO and shall be ignored
        conf |= 0xFFFF8FFF; //ignore the RO bits by turning them to 1
        conf ^= 0x00007000; //turn the R/WC bits to the inverse value


        mm2s_dmasr &= conf; //the RO bits will be neutral for &, while 1 for R/WC when inverted, will clear the bit

        //this part of the code creates an error, because multiple threads are driving the signal
        /*
          if(!(mm2s_dmasr & (1 << 12)))
          mm2s_ioc_irq.write(false); //if the bit is deasserted, no interrupt signal is generated
        */

        //cout << showbase;
        //cout << "MM2S_DMASR CHANGED TO: " << hex << mm2s_dmasr << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case MM2S_SA_OFFSET:
        //load the source addres into the mm2s_sa register
        mm2s_sa = conf;
        //cout << showbase;
        //cout << "MM2S_SA CHANGED TO: " << hex << mm2s_sa << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case MM2S_LENGTH_OFFSET:
        //bits 26-31 are reserved and RO and shall be ignored (default value 0)
        conf &= 0x03FFFFFF;
        mm2s_length = conf;
        //cout << showbase;
        //cout << "MM2S_LENGTH CHANGED TO: " << hex << mm2s_length << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_DMACR_OFFSET:
        //same as mm2s_dmacr
        conf &= ~(0x1 << 15);
        conf &= ~(0x7F << 5);
        conf |= (0x1 << 1);

        s2mm_dmacr = conf;
        //cout << showbase;
        //cout << "S2MM_DMACR CHANGED TO: " << hex << s2mm_dmacr << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_DMASR_OFFSET:
        //same as s2mm_dmasr
        conf |= 0xFFFF8FFF;
        conf ^= 0x00007000;

        s2mm_dmasr &= conf;

        //this part of the code creates an error, because multiple threads are driving the signal
        /*
          if(!(s2mm_dmasr & (1 << 12)))
          s2mm_ioc_irq.write(false); //if the bit is deasserted, no interrupt signal is generated
        */

        //cout << showbase;
        //cout << "S2MM_DMACR CHANGED TO: " << hex << s2mm_dmasr << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_DA_OFFSET:
        //same as mm2s_sa
        s2mm_da = conf;
        //cout << showbase;
        //cout << "S2MM_DA CHANGED TO: " << hex << s2mm_da << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_LENGTH_OFFSET:
        //same as mm2s_length
        conf &= 0x03FFFFF;
        s2mm_length = conf;
        //cout << showbase;
        //cout << "S2MM_LENGTH CHANGED TO: " << hex << s2mm_length << endl;
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      default:
        //invalid address case
        payload.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
        cout << "DMA bad address." << endl;
        break;
      }

      //end of case TLM_WRITE_COMMAND
      break;
    }

  case TLM_READ_COMMAND:
    {
      //all registers are readable
      switch(addr) {
      case MM2S_DMACR_OFFSET:
        memcpy(data, &mm2s_dmacr, sizeof(mm2s_dmacr));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case MM2S_DMASR_OFFSET:
        memcpy(data, &mm2s_dmasr, sizeof(mm2s_dmasr));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case MM2S_SA_OFFSET:
        memcpy(data, &mm2s_sa, sizeof(mm2s_sa));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case MM2S_LENGTH_OFFSET:
        memcpy(data, &mm2s_length, sizeof(mm2s_length));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_DMACR_OFFSET:
        memcpy(data, &s2mm_dmacr, sizeof(s2mm_dmacr));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_DMASR_OFFSET:
        memcpy(data, &s2mm_dmasr, sizeof(s2mm_dmasr));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_DA_OFFSET:
        memcpy(data, &s2mm_da, sizeof(s2mm_da));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      case S2MM_LENGTH_OFFSET:
        memcpy(data, &s2mm_da, sizeof(s2mm_length));
        payload.set_response_status(TLM_OK_RESPONSE);
        break;

      default:
        payload.set_response_status(TLM_ADDRESS_ERROR_RESPONSE);
        cout << "DMA bad address" << endl;
      }

      //end of case TLM_READ_COMMAND
      break;
    }

  default:
    payload.set_response_status(TLM_COMMAND_ERROR_RESPONSE);
    SC_REPORT_ERROR("DMA", "TLM bad command");
    break;
  }

  msg(payload);
  offset += clk_period;
}


//method for displaying transactions
void acc_calc::msg(const pl_t& pl) {
  std::stringstream ss1;
  std::stringstream ss2;
  ss1 << hex << pl.get_address();
  sc_uint<32> val = *((sc_uint<32>*)pl.get_data_ptr());
  ss2 << hex << val;

  string cmd = pl.get_command() == TLM_READ_COMMAND ? "read " : "write ";
  string regname;

  switch(pl.get_address()) {
  case MM2S_DMACR_OFFSET:
    regname = "MM2S_DMACR";
    break;

  case MM2S_DMASR_OFFSET:
    regname = "MM2S_DMASR";
    break;

  case MM2S_SA_OFFSET:
    regname = "MM2S_SA";
    break;

  case MM2S_LENGTH_OFFSET:
    regname = "MM2S_LENGTH";
    break;

  case S2MM_DMACR_OFFSET:
    regname = "S2MM_DMACR";
    break;

  case S2MM_DMASR_OFFSET:
    regname = "S2MM_DMASR";
    break;

  case S2MM_DA_OFFSET:
    regname = "S2MM_DA";
    break;

  case S2MM_LENGTH_OFFSET:
    regname = "S2MM_LENGTH";
    break;

  default:
    regname = "no reg";
    break;
  }

  string msg = cmd + "value: " + ss2.str() + " at/to address: " + ss1.str();
  msg += " " + regname;
  msg += " @ " + sc_time_stamp().to_string();

  SC_REPORT_INFO("DMA", msg.c_str());
}


//main thread for the read from memory channel
void acc_calc::acc_calc_mm2s_process() {
  tlm_utils::tlm_quantumkeeper qk;
  qk.reset();

  while(1) {
    if(mm2s_dmacr & RESET_MASK) {
      cout << "MM2S HAS INITIATED RESET!" << endl;
      //reset all registers except dmacr to default value
      mm2s_dmasr  = MM2S_DMASR_DEF;
      mm2s_sa     = MM2S_SA_DEF;
      mm2s_length = MM2S_LENGTH_DEF;
      mm2s_transfer_counter = -1; //reset the counter
      mm2s_burst_buffer.clear(); //empty the buffer
      mm2s_burst_size = 16; //reset the burst size

      //reset the s2mm channel
      s2mm_dmacr  = S2MM_DMACR_DEF;
      s2mm_dmasr  = S2MM_DMASR_DEF;
      s2mm_da     = S2MM_DA_DEF;
      s2mm_length = S2MM_LENGTH_DEF;

      //critical section
      if(mtx.trylock() != -1) {
        //both processes have access to these variables at this time
        transfer_finished = false;
        s2mm_transfer_counter = -1;

        mm2s_dmacr  = MM2S_DMACR_DEF; //make sure that transfer_finished is false, then reset the register
        mtx.unlock();
      }
    } else {
      //check if run/stop bit is asserted
      if(mm2s_dmacr & RS_MASK) {
        //deassert the halted bit
        mm2s_dmasr &= (~HALTED_MASK);
        //check if the length register is non-zero
        if((mm2s_length & LENGTH_MASK) >= 4) {
          //initial load for the counter - number of memory locations to be read: 1 location is 4 bytes
          if(mm2s_transfer_counter == -1) {
            mm2s_transfer_counter = 0; //initialize the counter
            mm2s_burst_buffer.clear(); //empty the buffer
            mm2s_burst_size = 16; //reset the burst size
          }

          //start a transfer then let the IP calculate the points which will be sent through S2MM
          if(!transfer_finished) {
            //define the payload
            pl_t mm2s_pl;
            uint64 raddress = (uint64) (mm2s_sa + mm2s_transfer_counter);
            mm2s_pl.set_data_ptr((unsigned char*) &mm2s_data);

            mm2s_pl.set_command(TLM_READ_COMMAND);
            mm2s_pl.set_address(raddress);
            mm2s_pl.set_data_length(1);

            //Initial DMA latency = 6 clock cycles for MM2S channel
            if(mm2s_transfer_counter == 0)
              qk.set_and_sync(6 * clk_period);

            sc_time loct = qk.get_local_time(); //local offset time of the process
            dma_read_isoc -> b_transport(mm2s_pl, loct);
            //increment the throughput measurement variable
            mm2s_transfer_throughput++;
            qk.set_and_sync(loct);

            ++mm2s_transfer_counter;

            //end condition
            if(mm2s_transfer_counter == ((int) ((mm2s_length & LENGTH_MASK) / 4))) {
              cout << "TRANSFER COUNTER REACHED THE END!" << endl;
              mm2s_dmacr ^= RS_MASK; //stop the dma

              mm2s_dmasr |= IOC_IRQ_MASK; //assert the interrupt-on-completion bit
              mm2s_ioc_irq.write(true);

              //in case the last burst isn't equal to 16
              //i.e. the length of the transfer divided by 16 gives a remainder
              //set the burst size to the current spots in the buffer
              //so the control will be given to the s2mm, and avoid losing data
              mm2s_burst_size = mm2s_burst_buffer.size() + 1;
            }

            if(mm2s_data & RAD_PIX_MASK) {
              det_radius = mm2s_data & 0x000003FF; //extract 10bit radius from data
            }
            else {
              //in case the data contains pixel information, store it into the buffer
              mm2s_burst_buffer.push_back(mm2s_data);

              //check if the buffer is full
              if(mm2s_burst_buffer.size() == mm2s_burst_size) {
                transfer_finished = true;
              }
            }

            // cout << "DET_RADIUS : " << det_radius << endl;
            //cout << "MM2S BURST SIZE : " << mm2s_burst_size << endl;
            //cout << "TRANSFER_FINISHED : " << transfer_finished << endl;
          }
        }
      } else {
        //if it is deasserted then the DMA halts
        mm2s_dmasr |= HALTED_MASK;
        mm2s_transfer_counter = -1; 
      } //end of run/stop if case
    } //end of reset if case

    //if the IOC IRQ bit is deasserted, write false to interrupt signal
    if(!(mm2s_dmasr & IOC_IRQ_MASK))
      mm2s_ioc_irq.write(false);

    qk.inc(clk_period);
    //cout << "MM2S INCREMENTED PERIOD" << endl;
    if(qk.need_sync()) {
      qk.sync();
      //SC_REPORT_INFO("MM2S DMA", string("Synced @ " + sc_time_stamp().to_string()).c_str());
    }
  } //end of while(1)
}

//main thread for the write to memory channel
void acc_calc::acc_calc_s2mm_process() {
  tlm_utils::tlm_quantumkeeper qk;
  qk.reset();

  while(1) {
    if(s2mm_dmacr & RESET_MASK) {
      //reset all registers to the default value
      s2mm_dmasr  = S2MM_DMASR_DEF;
      s2mm_length = S2MM_LENGTH_DEF;
      s2mm_da     = S2MM_DA_DEF;
      s2mm_transfer_counter = -1;

      //reset the other channel
      mm2s_dmasr  = MM2S_DMASR_DEF;
      mm2s_sa     = MM2S_SA_DEF;
      mm2s_length = MM2S_LENGTH_DEF;
      mm2s_dmacr  = MM2S_DMACR_DEF;

      if(mtx.trylock() != -1) {
        //both processes have access to these variables
        mm2s_transfer_counter = -1;
        transfer_finished = false;

        s2mm_dmacr  = S2MM_DMACR_DEF; //stop the reset when assured that everything is default
        mtx.unlock();
      }
    } else {
      //check if the run/stop bit is asserted
      if(s2mm_dmacr & RS_MASK) {
        //cout << "RS MASK FOR S2MM HAS BEEN SET CORRECTLY" << endl;
        //deassert the halted bit
        s2mm_dmasr &= (~HALTED_MASK);
        //check if the length register is non-zero
        if((s2mm_length & LENGTH_MASK) >= 4) {
          //cout << "LENGTH REGISTER HAS BEEN SET FOR S2MM CORRECTLY" << endl;
          //initial load of the counter - same principle as for mm2s
          if(s2mm_transfer_counter == -1)
            s2mm_transfer_counter = 0;

          //cout << "IN FRONT OF IF(TRANSFER_FINISHED) S2MM" << endl;

          //if the read transfer is finished, commence the calculation
          if(transfer_finished) {
            double pi_const = M_PI / 180.0; //quantization of pi/180 constant

            //initial acc_calc IP delay after waiting for buffer to fill up = 3 cycles
            if(mm2s_burst_buffer.size() == mm2s_burst_size)
              qk.set_and_sync(3 * clk_period);

            sc_uint<32> mm2s_data_from_buffer;
            mm2s_data_from_buffer = mm2s_burst_buffer.back();
            mm2s_burst_buffer.pop_back();


            //extract the data from the received package
            sc_int<10> x_pos = mm2s_data_from_buffer & 0x000003FF;
            sc_int<10> y_pos = (mm2s_data_from_buffer & 0x000FFC00) >> 10;

            //cout << "X_POS EXTRACTED : " << x_pos << endl;
            //cout << "Y_POS EXTRACTED : " << y_pos << endl;
            //cout << "PI_CONST : " << pi_const << endl;

            //cout << "IN FRONT OF LOOP!" << endl;
            //computation loop for each white pixel
            for(int theta = 0; theta < 360; theta++) {
              //cout << "THETA = " << dec << theta << endl;
              s2mm_data = 0; //reset the data register
              double trig_exp = theta * pi_const; //the expression in the sine and cosine functions
              //cout << "TRIG_EXP = THETA * PI = " << trig_exp << endl;
              num_t cos_result = cos(trig_exp); //cosine and sine can give negative values, hence the signed data type
              num_t sin_result = sin(trig_exp);

              //quantization happens here
              sc_int<10> r1 = (sc_int<10>) (det_radius * cos_result);
              sc_int<10> r2 = (sc_int<10>) (det_radius * sin_result);

              //check for possible underflow or if the pixel is out of bounds, if underflow occurs the result should be ignored
              if((x_pos < r1) || (y_pos < r2)) {
                s2mm_data |= VALID_PIX_MASK;
              } else {
                //we won't check for overflow here, because we need the exact dimensions of the image
                //this will be done in the driver, and we will assume that the picture is below a given max. size
                //for example we will say that the maximum size of the input image is 800x800
                //so we can easily catch overflow in the zone 801 to 1023 (because the result is 10bit)
                s2mm_data = (sc_uint<32>) (x_pos - r1);
                s2mm_data |= ((sc_uint<32>) (y_pos - r2)) << 10;

                //cout << "CALCULATED X : " << (unsigned int) (x_pos - r1) << endl;
                //cout << "CALCULATED Y : " << (unsigned int) (y_pos - r2) << endl;
              }
              //create payload
              pl_t s2mm_pl;
              uint64 waddress = (uint64) (s2mm_da + ((sc_uint<32>) s2mm_transfer_counter));

              s2mm_pl.set_command(TLM_WRITE_COMMAND);
              s2mm_pl.set_address(waddress);
              s2mm_pl.set_data_ptr((unsigned char*) &s2mm_data);
              s2mm_pl.set_data_length(1);

              //The initial latency of the DMA for the s2mm channel = 39 cycles

              if(s2mm_transfer_counter == 0)
                qk.set_and_sync(39 * clk_period);


              sc_time loct = qk.get_local_time();
              dma_write_isoc -> b_transport(s2mm_pl, loct);
              //increase the throughput variable, used for measurement
              s2mm_transfer_throughput++;
              qk.set_and_sync(loct);

              //The checking of this counter should be done at the start of the loop
              //in order to evaluate whether the s2mm_length register is set correctly to
              //360 * 4bytes
              ++s2mm_transfer_counter;

              //After every burst cycle, there is 6 cycles of latency for RAM access


              if((s2mm_transfer_counter % s2mm_burst_size) == 0)
                qk.set_and_sync(6 * clk_period);

            }

            if(s2mm_transfer_counter == (s2mm_length / 4)) {
              //s2mm channel has sent all bytes of data
              cout << "S2MM ENTERED ENDING CONDITION" << endl;
              s2mm_dmacr ^= RS_MASK;
              s2mm_dmasr |= IOC_IRQ_MASK;
              s2mm_length = S2MM_LENGTH_DEF;
              s2mm_transfer_counter = -1;
              s2mm_ioc_irq.write(true); //send the interrupt signal

              //stop the throughput measurement
              end_of_measurement = true;
            }

            //if the burst buffer is emptied, give control to the mm2s process
            if(mm2s_burst_buffer.size() == 0)
              transfer_finished = false;
          }
        }
      } else {
        //if the dma halts
        //s2mm_transfer_counter = -1; this line is irrelevant for the purpose of this project

        s2mm_dmasr |= HALTED_MASK;

        //possible code issue
        /*if(transfer_finished)
          transfer_finished = false;*/
      }
    }

    //if the IOC IRQ bit is deasserted, write false to interrupt signal
    if(!(s2mm_dmasr & IOC_IRQ_MASK))
      s2mm_ioc_irq.write(false);

    //after every iteration of while loop, increment local time
    qk.inc(clk_period);
    if(qk.need_sync()) {
      qk.sync();
      //SC_REPORT_INFO("S2MM DMA", string("Synced @ " + sc_time_stamp().to_string()).c_str());
    }
  } //end of while(1)
}


//this throughput measurement thread activates every 1ms to report the throughput
//of each channel
void acc_calc::throughput_measure_process() {
  tlm_utils::tlm_quantumkeeper qk;
  qk.reset();

  sc_time sample_period(1, SC_MS);
  int num_of_measurements = 0;
  std::vector<double> measurement_vector;
  double mm2s_average_throughput = 0;
  double s2mm_average_throughput = 0;
  double max_throughput = 0;

  bool start = false; //used to skip the measurement at 0ms

  //highest throughput is measured once s2mm and mm2s are set and active
  //it is measured in the interval [1ms : 2ms]
  while(end_of_measurement == false) {
    if(start) {
      //formula: (bus_width * num_of_transactions) / (10^6 * 10^(-3))
      //where dividing by 10^6 gives MB/ms, and dividing by 10^(-3) gives MB/s
      measurement_vector.push_back(((double) mm2s_transfer_throughput * 4) / 1000);
      measurement_vector.push_back(((double) s2mm_transfer_throughput * 4) / 1000);

      //reset the variables for a new measurement
      mm2s_transfer_throughput = 0;
      s2mm_transfer_throughput = 0;

      num_of_measurements++;
    }

    if(num_of_measurements == 0)
      start = true;

    qk.inc(sample_period);
    if(qk.need_sync())
      qk.sync();
  }
  //end of measurements - display the maximum throughput
  cout << endl << "MAXIMUM THROUGHPUT MEASUREMENT" << endl;
  for(int i = 0; i < num_of_measurements; i++) {
    if(max_throughput < measurement_vector[2 * i])
      max_throughput = measurement_vector[2 * i];
  }
  cout << "Maximum throughput for MM2S channel : " << max_throughput << " MB/s" << endl;

  for(int i = 0; i < num_of_measurements; i++) {
    if(max_throughput < measurement_vector[2 * i + 1])
      max_throughput = measurement_vector[2 * i + 1];
  }
  cout << "Maximum throughput for S2MM channel : " << max_throughput << " MB/s" << endl;


  //end of measurements - display the average throughput
  for(int i = 0; i < num_of_measurements; i++) {
    mm2s_average_throughput += measurement_vector[2 * i];
    s2mm_average_throughput += measurement_vector[2 * i + 1];
  }
  mm2s_average_throughput /= num_of_measurements;
  s2mm_average_throughput /= num_of_measurements;

  cout << endl << "AVERAGE THROUGHPUT MEASUREMENT" << endl;
  cout << "Average throughput for MM2S channel : " << mm2s_average_throughput << " MB/s" << endl;
  cout << "Average throughput for S2MM channel : " << s2mm_average_throughput << " MB/s" << endl << endl;
}
