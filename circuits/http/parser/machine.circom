pragma circom 2.1.9;

include "language.circom";
include "../../utils/array.circom";

template StateUpdate() {
    signal input parsing_start; // Bool flag for if we are in the start line 
    signal input parsing_header; // Flag + Counter for what header line we are in
    signal input parsing_body;
    signal input line_status; // Flag that counts up to 4 to read a double CLRF
    signal input byte;

    signal output next_parsing_start;
    signal output next_parsing_header;
    signal output next_parsing_body;
    signal output next_line_status;

    component Syntax = Syntax();

    //---------------------------------------------------------------------------------// 
    // Check if what we just read is a CL / RF
    component readCL = IsEqual();
    readCL.in      <== [byte, Syntax.CL];
    component readRF = IsEqual();
    readRF.in      <== [byte, Syntax.RF];

        signal notCLAndRF <== (1 - readCL.out) * (1 - readRF.out);
    //---------------------------------------------------------------------------------//

    //---------------------------------------------------------------------------------//
    // Check if we had read previously CL / RF or multiple
    component prevReadCL     = IsEqual();
    prevReadCL.in          <== [line_status, 1];
    log("prevReadCL: ", prevReadCL.out);
    component prevReadCLRF   = IsEqual();
    prevReadCLRF.in        <== [line_status, 2];
    log("prevReadCLRF: ", prevReadCLRF.out);
    component prevReadCLRFCL = IsEqual();
    prevReadCLRFCL.in      <== [line_status, 3];
    log("prevReadCLRFCL: ", prevReadCLRFCL.out);

    signal readCLRF     <== prevReadCL.out * readRF.out;
    log("readCLRF: ", readCLRF);
    signal readCLRFCLRF <== prevReadCLRFCL.out * readRF.out;
    log("readCLRFCLRF: ", readCLRFCLRF);
    //---------------------------------------------------------------------------------//

    //---------------------------------------------------------------------------------//
    // Take current state and CLRF info to update state
    signal state[3] <== [parsing_start, parsing_header, parsing_body];
    component stateChange    = StateChange();
    stateChange.readCLRF <== readCLRF;
    stateChange.readCLRFCLRF <== readCLRFCLRF;
    stateChange.state   <== state;

    component nextState   = ArrayAdd(3);
    nextState.lhs       <== state;
    nextState.rhs       <== stateChange.out;
    //---------------------------------------------------------------------------------//

    next_parsing_start  <== nextState.out[0];
    next_parsing_header <== nextState.out[1];
    next_parsing_body   <== nextState.out[2]; 
    next_line_status    <== line_status + readCL.out + readCLRF + readCLRFCLRF - line_status * notCLAndRF;

}

template StateChange() {
    signal input readCLRF;
    signal input readCLRFCLRF;
    signal input state[3];
    signal output out[3];

    signal disableParsingStart <== readCLRF * state[0];
    signal disableParsingHeader <== readCLRFCLRF * state[1];

    out <== [-disableParsingStart, disableParsingStart - disableParsingHeader, disableParsingHeader];
}