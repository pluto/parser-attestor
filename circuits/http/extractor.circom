pragma circom 2.1.9;

include "../utils/bytes.circom";
include "parser/machine.circom";
include "@zk-email/circuits/utils/array.circom";

// TODO:
// - handle CRLF in response data

template ExtractResponse(DATA_BYTES, maxContentLength) {
    signal input data[DATA_BYTES];
    signal output response[maxContentLength];

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
    State[0].parsing_body   <== 0;
    State[0].line_status    <== 0;

    signal dataMask[DATA_BYTES];
    dataMask[0] <== 0;

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate();
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].parsing_start  <== State[data_idx - 1].next_parsing_start;
        State[data_idx].parsing_header <== State[data_idx - 1].next_parsing_header;
        State[data_idx].parsing_body   <== State[data_idx - 1].next_parsing_body;
        State[data_idx].line_status    <== State[data_idx - 1].next_line_status;

        // apply body mask to data
        dataMask[data_idx] <== data[data_idx] * State[data_idx].next_parsing_body;

        // Debugging
        log("State[", data_idx, "].parsing_start ", "= ", State[data_idx].parsing_start);
        log("State[", data_idx, "].parsing_header", "= ", State[data_idx].parsing_header);
        log("State[", data_idx, "].parsing_body  ", "= ", State[data_idx].parsing_body);
        log("State[", data_idx, "].line_status   ", "= ", State[data_idx].line_status);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    log("State[", DATA_BYTES, "].parsing_start ", "= ", State[DATA_BYTES-1].next_parsing_start);
    log("State[", DATA_BYTES, "].parsing_header", "= ", State[DATA_BYTES-1].next_parsing_header);
    log("State[", DATA_BYTES, "].parsing_body  ", "= ", State[DATA_BYTES-1].next_parsing_body);
    log("State[", DATA_BYTES, "].line_status   ", "= ", State[DATA_BYTES-1].next_line_status);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    signal valueStartingIndex[DATA_BYTES];
    signal isZeroMask[DATA_BYTES];
    signal isPrevStartingIndex[DATA_BYTES];
    valueStartingIndex[0] <== 0;
    isZeroMask[0] <== IsZero()(dataMask[0]);
    for (var i=1 ; i<DATA_BYTES ; i++) {
        isZeroMask[i] <== IsZero()(dataMask[i]);
        isPrevStartingIndex[i] <== IsZero()(valueStartingIndex[i-1]);
        valueStartingIndex[i] <== valueStartingIndex[i-1] + i * (1-isZeroMask[i]) * isPrevStartingIndex[i];
    }

    response <== SelectSubArray(DATA_BYTES, maxContentLength)(dataMask, valueStartingIndex[DATA_BYTES-1]+1, DATA_BYTES - valueStartingIndex[DATA_BYTES-1]);
}