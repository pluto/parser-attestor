pragma circom 2.1.9;

include "../interpreter.circom";
include "../../utils/array.circom";

// TODO: should use a MAX_HEADER_NAME_LENGTH and a MAX_HEADER_VALUE_LENGTH
template LockHeader(DATA_BYTES, MAX_STACK_HEIGHT, HEADER_NAME_LENGTH, HEADER_VALUE_LENGTH) {
    // ------------------------------------------------------------------------------------------------------------------ //
    // ~~ Set sizes at compile time ~~
    // Total number of variables in the parser for each byte of data
    /* 5 is for the variables:
        next_parsing_start
        next_parsing_header
        next_parsing_field_name
        next_parsing_field_value
        State[i].next_parsing_body
    */
    var TOTAL_BYTES_HTTP_STATE    = DATA_BYTES * (5 + 1); // data + parser vars
    var PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;
    var TOTAL_BYTES_ACROSS_NIVC   = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1) + 1;
    // ------------------------------------------------------------------------------------------------------------------ //

    // ------------------------------------------------------------------------------------------------------------------ //
    // ~ Unravel from previous NIVC step ~
    // Read in from previous NIVC step (HttpParseAndLockStartLine or HTTPLockHeader)
    signal input step_in[TOTAL_BYTES_ACROSS_NIVC]; 
    signal output step_out[TOTAL_BYTES_ACROSS_NIVC];

    signal data[DATA_BYTES];
    for (var i = 0 ; i < DATA_BYTES ; i++) {
        data[i] <== step_in[i];
    }

    // TODO: Better naming for these variables
    signal input header[HEADER_NAME_LENGTH];
    signal input value[HEADER_VALUE_LENGTH];

    component headerNameLocation = FirstStringMatch(DATA_BYTES, HEADER_NAME_LENGTH);
    headerNameLocation.data      <== data;
    headerNameLocation.key       <== header;

    component headerFieldNameValueMatch;
    headerFieldNameValueMatch             =  HeaderFieldNameValueMatch(DATA_BYTES, HEADER_NAME_LENGTH, HEADER_VALUE_LENGTH);
    headerFieldNameValueMatch.data        <== data;
    headerFieldNameValueMatch.headerName  <== header;
    headerFieldNameValueMatch.headerValue <== value;
    headerFieldNameValueMatch.index       <== headerNameLocation.position;

    // TODO: Make this assert we are parsing header!!!
    // This is the assertion that we have locked down the correct header
    headerFieldNameValueMatch.out === 1;

    // ------------------------------------------------------------------------------------------------------------------ //
    // ~ Write out to next NIVC step
    for (var i = 0 ; i < DATA_BYTES ; i++) {
        // add plaintext http input to step_out
        step_out[i] <== step_in[i];

        // add parser state
        step_out[DATA_BYTES + i * 5]     <== step_in[DATA_BYTES + i * 5];
        step_out[DATA_BYTES + i * 5 + 1] <== step_in[DATA_BYTES + i * 5 + 1];
        step_out[DATA_BYTES + i * 5 + 2] <== step_in[DATA_BYTES + i * 5 + 2];
        step_out[DATA_BYTES + i * 5 + 3] <== step_in[DATA_BYTES + i * 5 + 3];
        step_out[DATA_BYTES + i * 5 + 4] <== step_in[DATA_BYTES + i * 5 + 4];
    }
        // Pad remaining with zeros
    for (var i = TOTAL_BYTES_HTTP_STATE ; i < TOTAL_BYTES_ACROSS_NIVC ; i++ ) {
        step_out[i] <== 0;
    }
}

// TODO: Handrolled template that I haven't tested YOLO.
template FirstStringMatch(dataLen, keyLen) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal output position;

    var matched = 0;
    var counter = 0;
    component stringMatch[dataLen - keyLen];
    component hasMatched[dataLen - keyLen];
    for (var idx = 0 ; idx < dataLen - keyLen ; idx++) {
        stringMatch[idx] = IsEqualArray(keyLen);
        stringMatch[idx].in[0] <== key;
        for (var key_idx = 0 ; key_idx < keyLen ; key_idx++) {
            stringMatch[idx].in[1][key_idx] <== data[idx + key_idx] * (1 - matched);
        }
        hasMatched[idx] = IsEqual();
        hasMatched[idx].in <== [stringMatch[idx].out, 1];
        matched += hasMatched[idx].out;
        counter += (1 - matched); // TODO: Off by one? Move before?
    }
    position <== counter;
}


