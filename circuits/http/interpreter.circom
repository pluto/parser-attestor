pragma circom 2.1.9;

include "parser/language.circom";
include "../utils/array.circom";

/* TODO:
Notes --
- This is a pretty efficient way to simply check what the method used in a request is by checking
  the first `DATA_LENGTH` number of bytes.
- Could probably change this to a template that checks if it is one of the given methods
  so we don't check them all in one
*/
template YieldMethod(DATA_LENGTH) {
    signal input bytes[DATA_LENGTH];
    signal output MethodTag;

    component RequestMethod = RequestMethod();
    component RequestMethodTag = RequestMethodTag();

    component IsGet = IsEqualArray(3);
    for(var byte_idx = 0; byte_idx < 3; byte_idx++) {
        IsGet.in[0][byte_idx] <== bytes[byte_idx];
        IsGet.in[1][byte_idx] <== RequestMethod.GET[byte_idx];
    }
    signal TagGet <== IsGet.out * RequestMethodTag.GET;

    component IsPost = IsEqualArray(4);
    for(var byte_idx = 0; byte_idx < 4; byte_idx++) {
        IsPost.in[0][byte_idx] <== bytes[byte_idx];
        IsPost.in[1][byte_idx] <== RequestMethod.POST[byte_idx];
    }
    signal TagPost <== IsPost.out * RequestMethodTag.POST;

    MethodTag <== TagGet + TagPost;
}

// https://www.rfc-editor.org/rfc/rfc9112.html#name-field-syntax
template HeaderFieldNameValueMatch(dataLen, nameLen, valueLen) {
    signal input data[dataLen];
    signal input headerName[nameLen];
    signal input headerValue[valueLen];
    signal input r;
    signal input index;

    component syntax = Syntax();

    signal output value[valueLen];

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

    component syntax = Syntax();

    // is name matches
    signal headerNameMatch <== SubstringMatchWithIndex(dataLen, nameLen)(data, headerName, r, index);

    // next byte to name should be COLON
    signal endOfHeaderName <== IndexSelector(dataLen)(data, index + nameLen);
    signal isNextByteColon <== IsEqual()([endOfHeaderName, syntax.COLON]);

    // header name matches
    signal output out;
    out <== headerNameMatch * isNextByteColon;
}