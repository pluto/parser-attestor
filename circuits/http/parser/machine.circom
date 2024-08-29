pragma circom 2.1.9;

include "language.circom";
include "../../utils/array.circom";

template StateUpdate() {
    signal input parsing_start; // Bool flag for if we are in the start line 
    signal input parsing_header; // Flag + Counter for what header line we are in
    signal input parsing_body;
    signal input read_clrf; // Bool flag to say whether we just read a CLRF
    signal input byte_pair[2];

    signal output next_parsing_start;
    signal output next_parsing_header;
    signal output next_parsing_body;
    signal output next_read_clrf;

    signal state[3] <== [parsing_start, parsing_header, parsing_body];
    component stateToMask    = StateToMask();
    stateToMask.state   <== state;

    component Syntax = Syntax();

    component pairIsCLRF = IsEqualArray(2);
    pairIsCLRF.in      <== [byte_pair, Syntax.CLRF];
    log("pairIsCLRF: ", pairIsCLRF.out);

    component stateChange = ScalarArrayMul(3);
    stateChange.array   <== stateToMask.mask;
    stateChange.scalar  <== pairIsCLRF.out;
    log("stateChange[0]: ", stateChange.out[0]);
    log("stateChange[1]: ", stateChange.out[1]);
    log("stateChange[2]: ", stateChange.out[2]);

    component nextState   = ArrayAdd(3);
    nextState.lhs       <== state;
    nextState.rhs       <== stateChange.out;

    next_parsing_start <== nextState.out[0];
    next_parsing_header <== nextState.out[1];
    next_parsing_body <== nextState.out[2];
    next_read_clrf  <== pairIsCLRF.out;

}

template StateToMask() {
    signal input state[3];
    signal output mask[3];

    mask <== [- state[0], state[0] - state[1], state[2]];
}