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

    // TODO: Rewrite switch to also take the switch cases instead of enforcing 0,1,...n,
    component matcher = Switch(8); // 7 possible characters above, 1 case for non-chars above
    
}

/*
This function is creates an exhaustive switch statement from `0` up to `n`.

# Inputs:
- `n`: the number of switch cases
- `case`: which case of the switch to select
- `vals[n]`: the value that is emitted for a given switch case (e.g., `val[i]` on `case == i`)
- `out`: the selected output value

# Constraints:
- `case`: must be in the range `0, 1, ..., n-1`
*/
template Switch(n) {
    assert(n > 0);
    signal input case;
    signal input branches[n];
    signal input vals[n];
    signal output out;

    // Verify that the `case` is in the possible set of matches (0..n exlusive)
    var match_array[n];
    component indicator[n];
    signal component_out[n];
    var sum = 0;
    for(var i = 0; i < n; i++) {
        match_array[i] = case - branches[i];
        indicator[i] = IsZero();
        indicator[i].in <== case - branches[i]; 
        component_out[i] <== indicator[i].out * vals[i];
        sum += component_out[i];
    }
    component matchChecker = Contains(n);
    matchChecker.in <== 0;
    matchChecker.array <== match_array;
    matchChecker.out === 1;

    out <== sum;
}