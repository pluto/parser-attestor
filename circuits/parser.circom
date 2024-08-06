pragma circom 2.1.9;

include "operators.circom";


/*
TODO
*/
template Parser() {
    signal input byte;

    signal input tree_depth;
    signal input parsing_to_key;
    signal input parsing_to_value;
    signal input inside_key;
    signal input inside_value;

    signal output next_tree_depth;
    signal output next_parsing_to_key;
    signal output next_parsing_to_value;
    signal output next_inside_key;
    signal output next_inside_value;

    // Delimeters 
    // - ASCII char: `{`
    var start_brace = 123;
    // - ASCII char: `}`
    var end_brace = 125;
    // - ASCII char `[`
    var start_bracket = 91;
    // - ASCII char `]`
    var end_bracket = 93;
    // - ASCII char `"`
    var quote = 34;

    // White space
    // - ASCII char: `/n`
    var newline = 10;
    // - ASCII char: ` `
    var space = 32;

    // Outputs

    // component matcher = Switch(7, 4); // 7 possible characters above
    // matcher.branches <== [target_byte, start_brace, end_brace, start_bracket, end_bracket, quote];
    // matches.vals <== 
    
}

/*
This function is creates an exhaustive switch statement from `0` up to `n`.

# Inputs:
- `m`: the number of switch cases
- `n`: the output array length
- `case`: which case of the switch to select
- `branches[m]`: the values that enable taking different branches in the switch 
    (e.g., if `branch[i] == 10` then if `case == 10` we set `out == `vals[i]`)
- `vals[m][n]`: the value that is emitted for a given switch case 
    (e.g., `val[i]` array is emitted on `case == `branch[i]`)
- `out[n]`: the selected output value

# Constraints:
- `case`: must be in the range `0, 1, ..., n-1`
*/
template Switch(m, n) {
    assert(m > 0);
    assert(n > 0);
    signal input case;
    signal input branches[m];
    signal input vals[m][n];
    signal output out[n];

    // Verify that the `case` is in the possible set of matches (0..n exlusive)
    var match_array[m];
    component indicator[m];
    signal component_out[m][n];
    var sum[n];
    for(var i = 0; i < m; i++) {
        match_array[i] = case - branches[i];
        indicator[i] = IsZero();
        indicator[i].in <== case - branches[i]; 
        for(var j = 0; j < n; j++) {
            component_out[i][j] <== indicator[i].out * vals[i][j];
            sum[j] += component_out[i][j];
        }
    }
    component matchChecker = Contains(m);
    matchChecker.in <== 0;
    matchChecker.array <== match_array;
    matchChecker.out === 1;

    out <== sum;
}