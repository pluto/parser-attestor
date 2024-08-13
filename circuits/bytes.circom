pragma circom 2.1.9;

/*
All tests for this file are located in: `./test/bytes.test.ts`

Some of the functions here were based off the circomlib:
https://github.com/iden3/circomlib/blob/cff5ab6288b55ef23602221694a6a38a0239dcc0/circuits/bitify.circom
*/

/*
This function reads in a unsigned 8-bit integer and converts it to an array of bits.

# Inputs:
- `in`: a number
- `array[n]`: the array we want to search through
- `out`: either `0` or `1`
    - `1` if `in` is found inside `array`
    - `0` otherwise

# Constraints:
- `in`: must be between `0` and `2**8 - 1`
*/
// template U8ToBits() {
//     signal input in;
//     signal byte[8];
//     var lc1 = 0;

//     // log("input to u8ToByte: ", in);

//     var e2 = 1;
//     for (var i = 0; i < 8; i++) {
//         byte[i] <-- (in >> i) & 1;
//         byte[i] * (byte[i] - 1) === 0;
//         lc1 += byte[i] * e2;
//         e2 = e2 + e2;
//     }
//     lc1 === in;
// }

/*
This function reads in an array of unsigned numbers that will be constrained to be valid unsigned 8-bit integers.

# Inputs:
- `n`: the length of the ASCII string (as integers) to verify
- `in[n]`: a list of numbers

# Constraints:
- `in[n]`: each element of this array must be between `0` and `2**8-1`
*/
// template ASCII(n) {
//     signal input in[n];

//     component Byte[n];
//     for(var i = 0; i < n; i++) {
//         Byte[i] = U8ToBits();
//         Byte[i].in <== in[i];
//     }
// }

// template Num2Bits(n) {
//     signal input in;
//     signal output out[n];
//     var lc1=0;

//     var e2=1;
//     for (var i = 0; i<n; i++) {
//         out[i] <-- (in >> i) & 1;
//         out[i] * (out[i] -1 ) === 0;
//         lc1 += out[i] * e2;
//         e2 = e2+e2;
//     }

//     lc1 === in;
// }
