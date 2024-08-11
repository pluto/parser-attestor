pragma circom 2.1.9;

include "circomlib/circuits/comparators.circom";

/*
All tests for this file are located in: `./test/operators.test.ts`

Some of the functions here were based off the circomlib:
https://github.com/iden3/circomlib/blob/cff5ab6288b55ef23602221694a6a38a0239dcc0/circuits/comparators.circom
*/

/*
This function is an indicator for two equal array inputs.

# Inputs:
- `n`: the length of arrays to compare
- `in[2][n]`: two arrays of `n` numbers
- `out`: either `0` or `1`
    - `1` if `in[0]` is equal to `in[1]` as arrays (i.e., component by component)
    - `0` otherwise
*/
template IsEqualArray(n) {
    signal input in[2][n];
    signal output out;

    var accum = 0;
    component equalComponent[n];

    for(var i = 0; i < n; i++) {
        equalComponent[i] = IsEqual();
        equalComponent[i].in[0] <== in[0][i];
        equalComponent[i].in[1] <== in[1][i];
        accum += equalComponent[i].out;
    }

    component totalEqual = IsEqual();
    totalEqual.in[0] <== n;
    totalEqual.in[1] <== accum;
    out <== totalEqual.out;
}


// TODO: There should be a way to have the below assertion come from the field itself.
/*
This function is an indicator for if an array contains an element.

# Inputs:
- `n`: the size of the array to search through
- `in`: a number
- `array[n]`: the array we want to search through
- `out`: either `0` or `1`
    - `1` if `in` is found inside `array`
    - `0` otherwise
*/
template Contains(n) {
    assert(n > 0);
    /*
    If `n = p` for this large `p`, then it could be that this function
    returns the wrong value if every element in `array` was equal to `in`.
    This is EXTREMELY unlikely and iterating this high is impossible anyway.
    But it is better to check than miss something, so we bound it by `2**254` for now.
    */
    assert(n < 2**254);
    signal input in;
    signal input array[n];
    signal output out;

    var accum = 0;
    component equalComponent[n];
    for(var i = 0; i < n; i++) {
        equalComponent[i] = IsEqual();
        equalComponent[i].in[0] <== in;
        equalComponent[i].in[1] <== array[i];
        accum = accum + equalComponent[i].out;
    }

    component someEqual = IsZero();
    someEqual.in <== accum;

    // Apply `not` to this by 1-x
    out <== 1 - someEqual.out;
}
