pragma circom 2.1.9;

include "operators.circom";

template Parser() {
    signal input tree_depth;
    signal input parsing_to_key;
    signal input parsing_to_value;
    signal input in_key;
    signal input in_value;

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
}

template Switch(n) {
    assert(n > 0);
    signal input case;
    signal input vals[n];
    signal output out;

    // Verify that the `case` is in the possible set of matches (0..n exlusive)
    signal values[n][n]; 
    var match_array[n];
    for(var i = 0; i < n; i++) {
        match_array[i] = case - i;

        for(var j = 0; j < n; j++) {
                values[i][j] <-- (j - i)!=0 ? (case - i) / (j - i) : 1;
        }
    }
    component matchChecker = Contains(n);
    matchChecker.in <== 0;
    matchChecker.array <== match_array;

    // Get the output at that match case using lagrange polynomial
    var sum = 0;
    for(var i = 0; i < n; i++) {
        var product = 1;
        for(var j = 0; j < n; j++) {
            product *= values[i][j];
        }
        sum += product;
    }
    out <== sum;
}