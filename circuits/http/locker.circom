pragma circom 2.1.9;

include "interpreter.circom";
include "parser/machine.circom";
include "../utils/bytes.circom";
include "../utils/search.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";

template LockRequestLineData(DATA_BYTES, methodLen, targetLen, versionLen) {
    signal input data[DATA_BYTES];
    signal input method[methodLen];
    signal input target[targetLen];
    signal input version[versionLen];

    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//
    component dataASCII = ASCII(DATA_BYTES);
    dataASCII.in <== data;
    //--------------------------------------------------------------------------------------------//

    // Initialze the parser
    component State[DATA_BYTES];
    State[0] = StateUpdate();
    State[0].byte           <== data[0];
    State[0].parsing_start  <== 1;
    State[0].parsing_header <== 0;
    State[0].parsing_field_name <== 0;
    State[0].parsing_field_value <== 0;
    State[0].parsing_body   <== 0;
    State[0].line_status    <== 0;

    signal methodIsEqual[methodLen];
    methodIsEqual[0] <== IsEqual()([data[0],method[0]]);
    methodIsEqual[0] === 1;

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate();
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].parsing_start  <== State[data_idx - 1].next_parsing_start;
        State[data_idx].parsing_header <== State[data_idx - 1].next_parsing_header;
        State[data_idx].parsing_field_name <== State[data_idx-1].next_parsing_field_name;
        State[data_idx].parsing_field_value <== State[data_idx-1].next_parsing_field_value;
        State[data_idx].parsing_body   <== State[data_idx - 1].next_parsing_body;
        State[data_idx].line_status    <== State[data_idx - 1].next_line_status;
        
        if(data_idx < methodLen) {
            methodIsEqual[data_idx] <== IsEqual()([data[data_idx], method[data_idx]]);
            methodIsEqual[data_idx] === 1;
        }

        // Debugging
        log("State[", data_idx, "].parsing_start      ", "= ", State[data_idx].parsing_start);
        log("State[", data_idx, "].parsing_header     ", "= ", State[data_idx].parsing_header);
        log("State[", data_idx, "].parsing_field_name ", "= ", State[data_idx].parsing_field_name);
        log("State[", data_idx, "].parsing_field_value", "= ", State[data_idx].parsing_field_value);
        log("State[", data_idx, "].parsing_body       ", "= ", State[data_idx].parsing_body);
        log("State[", data_idx, "].line_status        ", "= ", State[data_idx].line_status);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    log("State[", DATA_BYTES, "].parsing_start      ", "= ", State[DATA_BYTES-1].next_parsing_start);
    log("State[", DATA_BYTES, "].parsing_header     ", "= ", State[DATA_BYTES-1].next_parsing_header);
    log("State[", DATA_BYTES, "].parsing_field_name ", "= ", State[DATA_BYTES-1].parsing_field_name);
    log("State[", DATA_BYTES, "].parsing_field_value", "= ", State[DATA_BYTES-1].parsing_field_value);
    log("State[", DATA_BYTES, "].parsing_body       ", "= ", State[DATA_BYTES-1].next_parsing_body);
    log("State[", DATA_BYTES, "].line_status        ", "= ", State[DATA_BYTES-1].next_line_status);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
}