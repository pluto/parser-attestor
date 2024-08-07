pragma circom 2.1.9;

include "operators.circom";
/*
Notes: for `test.json`
         | Read In: | STATE
-------------------
State[1] | {        | 
-------------------
State[7] | "        | INSIDE KEY
-------------------
State[12]| "        | NOT INSIDE KEY
-------------------------------------------------
State[13]| :        | PARSING TO VALUE
-------------------------------------------------
State[15]| "        | INSIDE VALUE
-------------------------------------------------
State[19]| "        | COMPLETE WITH KV PARSING



Notes:
- If there is no comma after leaving a value, then we should not be parsing to key. If anything breaks here, JSON was bad.
*/

/*
TODO
*/
template Parser() {
    signal input byte;

    signal input tree_depth;
    signal input escaping;
    signal input parsing_to_key;
    signal input parsing_to_value;
    signal input inside_key;
    signal input inside_value;
    signal input end_of_kv;

    signal output next_tree_depth;
    signal output next_parsing_to_key;
    signal output next_inside_key;
    signal output next_parsing_to_value;
    signal output next_inside_value;
    signal output next_end_of_kv;

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
    // - ASCII char `:`
    var colon = 58;
    // - ASCII char `,`
    var comma = 44;

    // White space
    // - ASCII char: `\n`
    var newline = 10;
    // - ASCII char: ` `
    var space = 32;

    // Escape
    // - ASCII char: `\`
    var escape = 92;

    // TODO: Check all the constraints here so state of `Parser` cannot be incorrect.
    // Output management
    component matcher = Switch(8, 3);
    var do_nothing[3]       = [ 0,                             0,         0];
    var increase_depth[3]   = [ 1,                             0,         0]; 
    var decrease_depth[3]   = [-1,                             0,         0];
    var hit_quote[3]        = [ 0,                             1,         0];
    var hit_colon[3]        = [ 0,                             0,         1];

    matcher.branches      <== [start_brace,    end_brace,      quote,     colon,      start_bracket, end_bracket, comma,      escape    ];
    matcher.vals          <== [increase_depth, decrease_depth, hit_quote, hit_colon,  do_nothing,    do_nothing,  do_nothing, do_nothing];
    matcher.case          <== byte;


    // TODO: These could likely go into a switch statement
    next_inside_key       <== inside_key + (parsing_to_key - inside_key) * matcher.out[1]; // If we were parsing to key and we hit a quote, then we set to be inside key
    next_inside_key * (1 - next_inside_key) === 0;
    next_parsing_to_key   <== parsing_to_key * (1 - matcher.out[1]);                       // If we were parsing to key and we hit a quote, then we are not parsing to key
    next_parsing_to_key * (1 - next_parsing_to_key) === 0;


    next_inside_value     <== inside_value + (parsing_to_value - inside_value) * matcher.out[1];
    next_inside_value * (1 - next_inside_value) === 0;
    signal NOT_PARSING_TO_KEY_AND_NOT_INSIDE_KEY <== (1 - parsing_to_key) * (1 - inside_key);
    signal PARSING_TO_VALUE_AND_NOT_HIT_QUOTE <== parsing_to_value * (1 - matcher.out[1]);
    next_parsing_to_value <== PARSING_TO_VALUE_AND_NOT_HIT_QUOTE + NOT_PARSING_TO_KEY_AND_NOT_INSIDE_KEY * matcher.out[2];    // If we are NOT parsing to key AND NOT inside key AND hit a colon, then we are parsing to value
    next_parsing_to_value * (1 - next_parsing_to_value) === 0;

    signal NOT_PARSING_TO_VALUE_AND_NOT_INSIDE_VALUE <== (1 - parsing_to_value) * (1 - inside_value);
    next_end_of_kv <== NOT_PARSING_TO_KEY_AND_NOT_INSIDE_KEY * NOT_PARSING_TO_VALUE_AND_NOT_INSIDE_VALUE;
    next_end_of_kv * (1 - next_end_of_kv) === 0;
     
    // TODO: Assert this never goes below zero (mod p)
    next_tree_depth       <== tree_depth + (parsing_to_key + next_end_of_kv) * matcher.out[0];                // Update the tree depth ONLY if we are parsing to a key

    // TODO: Can hit comma and then be sent to next KV, so comma will engage `parsing_to_key`
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

# Outputs
- `match`: is set to `0` if `case` does not match on any of `branches`
- `out[n]`: the selected output value if one of `branches` is selected (will be `[0,0,...]` otherwise)
*/
template Switch(m, n) {
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