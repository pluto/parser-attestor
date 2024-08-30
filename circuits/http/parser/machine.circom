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
    // Check if what we just read is a CR / LF
    component readCR = IsEqual();
    readCR.in      <== [byte, Syntax.CR];
    component readLF = IsEqual();
    readLF.in      <== [byte, Syntax.LF];

        signal notCRAndLF <== (1 - readCR.out) * (1 - readLF.out);
    //---------------------------------------------------------------------------------//

    //---------------------------------------------------------------------------------//
    // Check if we had read previously CR / LF or multiple
    component prevReadCR     = IsEqual();
    prevReadCR.in          <== [line_status, 1];
    component prevReadCRLF   = IsEqual();
    prevReadCRLF.in        <== [line_status, 2];
    component prevReadCRLFCR = IsEqual();
    prevReadCRLFCR.in      <== [line_status, 3];

    signal readCRLF     <== prevReadCR.out * readLF.out;
    signal readCRLFCRLF <== prevReadCRLFCR.out * readLF.out;
    //---------------------------------------------------------------------------------//

    //---------------------------------------------------------------------------------//
    // Take current state and CRLF info to update state
    signal state[3] <== [parsing_start, parsing_header, parsing_body];
    component stateChange    = StateChange();
    stateChange.readCRLF <== readCRLF;
    stateChange.readCRLFCRLF <== readCRLFCRLF;
    stateChange.state   <== state;

    component nextState   = ArrayAdd(3);
    nextState.lhs       <== state;
    nextState.rhs       <== stateChange.out;
    //---------------------------------------------------------------------------------//

    next_parsing_start  <== nextState.out[0];
    next_parsing_header <== nextState.out[1];
    next_parsing_body   <== nextState.out[2]; 
    next_line_status    <== line_status + readCR.out + readCRLF + readCRLFCRLF - line_status * notCRAndLF;

}

template StateChange() {
    signal input readCRLF;
    signal input readCRLFCRLF;
    signal input state[3];
    signal output out[3];

    signal disableParsingStart <== readCRLF * state[0];
    signal disableParsingHeader <== readCRLFCRLF * state[1];

    out <== [-disableParsingStart, disableParsingStart - disableParsingHeader, disableParsingHeader];
}