pragma circom 2.1.9;

include "parser/language.circom";
include "../utils/search.circom";
include "../utils/array.circom";

template inStartLine() {
    signal input parsing_start;
    signal output out;

    signal isBeginning <== IsEqual()([parsing_start, 1]);
    signal isMiddle <== IsEqual()([parsing_start, 2]);
    signal isEnd <== IsEqual()([parsing_start, 3]);

    out <== isBeginning + isMiddle + isEnd;
}

template inStartMiddle() {
    signal input parsing_start;
    signal output out;

    out <== IsEqual()([parsing_start, 2]);
}

template inStartEnd() {
    signal input parsing_start;
    signal output out;

    out <== IsEqual()([parsing_start, 3]);
}

// TODO: This likely isn't really an "Intepreter" thing
template MethodMatch(dataLen, methodLen) {
    signal input data[dataLen];
    signal input method[methodLen];

    signal input r;
    signal input index;

    signal isMatch <== SubstringMatchWithIndex(dataLen, methodLen)(data, method, r, index);
    isMatch === 1;
}

// https://www.rfc-editor.org/rfc/rfc9112.html#name-field-syntax
template HeaderFieldNameValueMatch(dataLen, nameLen, valueLen) {
    signal input data[dataLen];
    signal input headerName[nameLen];
    signal input headerValue[valueLen];
    signal input r;
    signal input index;

    component syntax = HttpSyntax();

    // signal output value[valueLen];

    // is name matches
    signal headerNameMatch <== SubstringMatchWithIndex(dataLen, nameLen)(data, headerName, r, index);

    // next byte to name should be COLON
    signal endOfHeaderName <== IndexSelector(dataLen)(data, index + nameLen);
    signal isNextByteColon <== IsEqual()([endOfHeaderName, syntax.COLON]);

    signal headerNameMatchAndNextByteColon <== headerNameMatch * isNextByteColon;

    // field-name: SP field-value
    signal headerValueMatch <== SubstringMatchWithIndex(dataLen, valueLen)(data, headerValue, r, index + nameLen + 2);

    // header name matches + header value matches
    signal output out <== headerNameMatchAndNextByteColon * headerValueMatch;
}

// https://www.rfc-editor.org/rfc/rfc9112.html#name-field-syntax
template HeaderFieldNameMatch(dataLen, nameLen) {
    signal input data[dataLen];
    signal input headerName[nameLen];
    signal input r;
    signal input index;

    component syntax = HttpSyntax();

    // is name matches
    signal headerNameMatch <== SubstringMatchWithIndex(dataLen, nameLen)(data, headerName, r, index);

    // next byte to name should be COLON
    signal endOfHeaderName <== IndexSelector(dataLen)(data, index + nameLen);
    signal isNextByteColon <== IsEqual()([endOfHeaderName, syntax.COLON]);

    // header name matches
    signal output out;
    out <== headerNameMatch * isNextByteColon;
}