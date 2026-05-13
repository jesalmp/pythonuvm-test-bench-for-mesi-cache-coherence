    +access+rwc                   //allow probes to record signals
    -timescale 1ns/1ns            //set simulation time precision
//    -gui                          //launch user interface
    -coverage A                   // record "all" coverage
    -covoverwrite                 // overwrite existing coverage db
    -covfile ./cov_conf.ccf       // feed in coverage configuration file
    -input ../uvm/waves.tcl

//UVM options
    +UVM_VERBOSITY=UVM_LOW
    -uvmhome $UVMHOME

//Add the list of test classes here (uncomment only one)
    //+UVM_TESTNAME=base_test         //-> done
    //+UVM_TESTNAME=five_trans_test   //-> done
    +UVM_TESTNAME=read_miss_icache    //-> done

//file list containing design and TB files to compiled
    -f file_list.f

//define ONE_CORE for single core model
    +define+ONE_CORE="1"
