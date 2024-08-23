/*
# `utils`
This module consists of helper templates for convencience.
It mostly extends the `bitify` and `comparators` modules from Circomlib.

## Layout
The key ingredients of `utils` are:
 - `ASCII`: Verify if a an input array contains valid ASCII values (e.g., u8 vals).
 - `IsEqualArray`: Check if two arrays are equal component by component.
 - `Contains`: Check if an element is contained in a given array.
 - `ArrayAdd`: Add two arrays together component by component.
 - `ArrayMul`: Multiply two arrays together component by component.
 - `GenericArrayAdd`: Add together an arbitrary amount of arrays.
 - `ScalarArrayMul`: Multiply each array element by a scalar value.
 - `InRange`: Check if a given number is in a given range.
 - `Switch`: Return a scalar value given a specific case.
 - `SwitchArray`: Return an array given a specific case.


## Testing
Tests for this module are located in the file: `./test/utils/utils.test.ts`
*/

pragma circom 2.1.9;

include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/comparators.circom";



/*
This template passes if a given array contains only valid ASCII values (e.g., u8 vals).

# Params:
 - `n`: the length of the array

# Inputs:
 - `in[n]`: array to check
*/
template ASCII(n) {
    signal input in[n];

    component Byte[n];
    for(var i = 0; i < n; i++) {
        Byte[i] = Num2Bits(8);
        Byte[i].in <== in[i];
    }
}

/*
This template is an indicator for two equal array inputs.

# Params:
 - `n`: the length of arrays to compare

# Inputs:
 - `in[2][n]`: two arrays of `n` numbers

# Outputs:
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
This template is an indicator for if an array contains an element.

# Params:
 - `n`: the size of the array to search through

# Inputs:
 - `in`: a number
 - `array[n]`: the array we want to search through

# Outputs:
 - `out`: either `0` or `1`
    - `1` if `in` is found inside `array`
    - `0` otherwise
*/
template Contains(n) {
    assert(n > 0);
    /*
    If `n = p` for this large `p`, then it could be that this template
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

/*
This template adds two arrays component by component.

# Params:
 - `n`: the length of arrays to compare

# Inputs:
 - `in[2][n]`: two arrays of `n` numbers

# Outputs:
 - `out[n]`: the array sum value 
*/
template ArrayAdd(n) {
    signal input lhs[n];
    signal input rhs[n];
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== lhs[i] + rhs[i];
    }
}

/*
This template multiplies two arrays component by component.

# Params:
 - `n`: the length of arrays to compare

# Inputs:
 - `in[2][n]`: two arrays of `n` numbers

# Outputs:
 - `out[n]`: the array multiplication value
*/
template ArrayMul(n) {
    signal input lhs[n];
    signal input rhs[n];
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== lhs[i] * rhs[i];
    }
}

/*
This template multiplies two arrays component by component.

# Params:
 - `m`: the length of the arrays to add
 - `n`: the number of arrays to add

# Inputs:
 - `arrays[m][n]`: `n` arrays of `m` numbers

# Outputs:
 - `out[m]`: the sum of all the arrays
*/
template GenericArrayAdd(m,n) {
    signal input arrays[n][m];
    signal output out[m];

    var accum[m];
    for(var i = 0; i < m; i++) {
        for(var j = 0; j < n; j++) {
            accum[i] += arrays[j][i];
        }
    }
    out <== accum;
}

/*
This template multiplies each component of an array by a scalar value.

# Params:
 - `n`: the length of the array

# Inputs:
 - `array[n]`: an array of `n` numbers

# Outputs:
 - `out[n]`: the scalar multiplied array
*/
template ScalarArrayMul(n) {
    signal input array[n];
    signal input scalar;
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== scalar * array[i];
    }
}

/*
This template checks if a given `n`-bit value is contained in a range of `n`-bit values

# Params:
 - `n`: the number of bits to use

# Inputs:
 - `range[2]`: the lower and upper bound of the array, respectively

# Outputs:
 - `out`: either `0` or `1`
    - `1` if `in` is within the range
    - `0` otherwise
*/
template InRange(n) {
    signal input in;
    signal input range[2];
    signal output out;

    component gte = GreaterEqThan(n);
    gte.in <== [in, range[0]];
    
    component lte = LessEqThan(n);
    lte.in <== [in, range[1]];

    out <== gte.out * lte.out;
}

/*
This template is creates an exhaustive switch statement from a list of branch values.
# Params:
 - `n`: the number of switch cases

# Inputs:
 - `case`: which case of the switch to select
 - `branches[n]`: the values that enable taking different branches in the switch 
    (e.g., if `branch[i] == 10` then if `case == 10` we set `out == `vals[i]`)
 - `vals[n]`: the value that is emitted for a given switch case 
    (e.g., `val[i]` array is emitted on `case == `branch[i]`)

# Outputs
 - `match`: is set to `0` if `case` does not match on any of `branches`
 - `out[n]`: the selected output value if one of `branches` is selected (will be `0` otherwise)
    ^^^^^^ BEWARE OF THIS FACT ABOVE! 
*/
template Switch(n) {
    assert(n > 0);
    signal input case;
    signal input branches[n];
    signal input vals[n];
    signal output match;
    signal output out;


    // Verify that the `case` is in the possible set of branches
    component indicator[n];
    component matchChecker = Contains(n);
    signal temp_val[n];
    var sum;
    for(var i = 0; i < n; i++) {
        indicator[i] = IsZero();
        indicator[i].in <== case - branches[i]; 
        matchChecker.array[i] <== 1 - indicator[i].out;
        temp_val[i] <== indicator[i].out * vals[i];
        sum += temp_val[i];
    }
    matchChecker.in <== 0;
    match <== matchChecker.out;

    out <== sum;
}

/*
This template is creates an exhaustive switch statement from a list of branch values.
# Params:
 - `m`: the number of switch cases
 - `n`: the output array length

# Inputs:

 - `case`: which case of the switch to select
 - `branches[m]`: the values that enable taking different branches in the switch 
    (e.g., if `branch[i] == 10` then if `case == 10` we set `out == `vals[i]`)
 - `vals[m][n]`: the value that is emitted for a given switch case 
    (e.g., `val[i]` array is emitted on `case == `branch[i]`)

# Outputs
 - `match`: is set to `0` if `case` does not match on any of `branches`
 - `out[n]`: the selected output value if one of `branches` is selected (will be `[0,0,...]` otherwise)
    ^^^^^^ BEWARE OF THIS FACT ABOVE! 
*/
template SwitchArray(m, n) {
    assert(m > 0);
    assert(n > 0);
    signal input case;
    signal input branches[m];
    signal input vals[m][n];
    signal output match;
    signal output out[n];


    // Verify that the `case` is in the possible set of branches
    component indicator[m];
    component matchChecker = Contains(m);
    signal component_out[m][n];
    var sum[n];
    for(var i = 0; i < m; i++) {
        indicator[i] = IsZero();
        indicator[i].in <== case - branches[i]; 
        matchChecker.array[i] <== 1 - indicator[i].out;
        for(var j = 0; j < n; j++) {
            component_out[i][j] <== indicator[i].out * vals[i][j];
            sum[j] += component_out[i][j];
        }
    }
    matchChecker.in <== 0;
    match <== matchChecker.out;

    out <== sum;
}

