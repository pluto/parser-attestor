pragma circom 2.1.9;

include "interpreter.circom";
include "parser/machine.circom";
include "../utils/bytes.circom";
include "../utils/search.circom";
include "circomlib/circuits/gates.circom";
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
    State[0].parsing_field_name <== 0;
    State[0].parsing_field_value <== 0;
    State[0].parsing_body   <== 0;
    State[0].line_status    <== 0;

    signal dataMask[DATA_BYTES];
    dataMask[0] <== 0;

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate();
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].parsing_start  <== State[data_idx - 1].next_parsing_start;
        State[data_idx].parsing_header <== State[data_idx - 1].next_parsing_header;
        State[data_idx].parsing_field_name <== State[data_idx-1].next_parsing_field_name;
        State[data_idx].parsing_field_value <== State[data_idx-1].next_parsing_field_value;
        State[data_idx].parsing_body   <== State[data_idx - 1].next_parsing_body;
        State[data_idx].line_status    <== State[data_idx - 1].next_line_status;

        // apply body mask to data
        dataMask[data_idx] <== data[data_idx] * State[data_idx].next_parsing_body;

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

template ExtractHeaderValue(DATA_BYTES, headerNameLength, maxValueLength) {
    signal input data[DATA_BYTES];
    signal input header[headerNameLength];

    signal output value[maxValueLength];

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

    signal headerMatch[DATA_BYTES];
    headerMatch[0] <== 0;
    signal isHeaderNameMatch[DATA_BYTES];
    isHeaderNameMatch[0] <== 0;
    signal readCRLF[DATA_BYTES];
    readCRLF[0] <== 0;
    signal valueMask[DATA_BYTES];
    valueMask[0] <== 0;

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate();
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].parsing_start  <== State[data_idx - 1].next_parsing_start;
        State[data_idx].parsing_header <== State[data_idx - 1].next_parsing_header;
        State[data_idx].parsing_field_name <== State[data_idx-1].next_parsing_field_name;
        State[data_idx].parsing_field_value <== State[data_idx-1].next_parsing_field_value;
        State[data_idx].parsing_body   <== State[data_idx - 1].next_parsing_body;
        State[data_idx].line_status    <== State[data_idx - 1].next_line_status;

        // apply value mask to data
        // TODO: change r
        headerMatch[data_idx] <== HeaderFieldNameMatch(DATA_BYTES, headerNameLength)(data, header, 100, data_idx);
        readCRLF[data_idx] <== IsEqual()([State[data_idx].line_status, 2]);
        isHeaderNameMatch[data_idx] <== Mux1()([isHeaderNameMatch[data_idx-1] * (1-readCRLF[data_idx]), 1], headerMatch[data_idx]);
        valueMask[data_idx] <== MultiAND(3)([data[data_idx], isHeaderNameMatch[data_idx], State[data_idx].parsing_field_value]);

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

    signal valueStartingIndex[DATA_BYTES];
    signal isZeroMask[DATA_BYTES];
    signal isPrevStartingIndex[DATA_BYTES];
    valueStartingIndex[0] <== 0;
    isZeroMask[0] <== IsZero()(valueMask[0]);
    for (var i=1 ; i<DATA_BYTES ; i++) {
        isZeroMask[i] <== IsZero()(valueMask[i]);
        isPrevStartingIndex[i] <== IsZero()(valueStartingIndex[i-1]);
        valueStartingIndex[i] <== valueStartingIndex[i-1] + i * (1-isZeroMask[i]) * isPrevStartingIndex[i];
    }

    value <== SelectSubArray(DATA_BYTES, maxValueLength)(valueMask, valueStartingIndex[DATA_BYTES-1]+1, maxValueLength);
}
