pragma circom 2.1.9;

include "parser/language.circom";
include "../utils/array.circom";

/* TODO: 
Notes --
- This is a pretty efficient way to simply check what the method used in a request is by checking
the first `DATA_LENGTH` number of bytes. 
- Certainly this could be more modular.
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