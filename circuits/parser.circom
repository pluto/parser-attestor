pragma circom 2.1.9;

include "operators.circom";
/*
Notes: for `test.json`
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 POINTER | Read In: | STATE
-------------------------------------------------
State[1] | {        | PARSING TO KEY
-------------------------------------------------
State[7] | "        | INSIDE KEY
-------------------------------------------------
State[12]| "        | NOT INSIDE KEY
-------------------------------------------------
State[13]| :        | PARSING TO VALUE
-------------------------------------------------
State[15]| "        | INSIDE VALUE
-------------------------------------------------
State[19]| "        | NOT INSIDE VALUE
-------------------------------------------------
State[20]| "        | COMPLETE WITH KV PARSING
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
State[20].next_tree_depth == 0 | VALID JSON
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx



TODOs:
- Handle case where the value is an another JSON. Shouldn't be too bad as we should just reset to init state with different tree depth
- In fact, we might not even need tree depth if we replace it with `inside_value` that is a counter as it represents the same thing!
   - Actually, this may not work since multiple values exist at same height. Let's not change this yet.
*/

/*
TODO
*/
template StateUpdate() {
    signal input byte;

    signal input tree_depth;             // STATUS_INDICATOR -- how deep in a JSON branch we are, e.g., `user.balance.value` key should be at depth `3`. 
                                         // Should always be greater than or equal to `0` (TODO: implement this constraint).

    signal input parsing_to_key;         // BIT_FLAG         -- whether we are currently parsing bytes until we find the next key (mutally exclusive with `inside_key` and both `*_value flags).
    signal input inside_key;             // BIT_FLAG         -- whether we are currently inside a key (mutually exclusive with `parsing_to_key` and both `*_value` flags).
    
    signal input parsing_to_value;       // BIT_FLAG         -- whether we are currently parsing bytes until we find the next value (mutually exclusive with `inside_value` and both `*_key` flags).
    signal input inside_value;           // BIT_FLAG         -- whether we are currently inside a value (mutually exclusive with `parsing_to_value` and both `*_key` flags).

    // signal input escaping;               // BIT_FLAG         -- whether we have hit an escape ASCII symbol inside of a key or value. 

    signal input end_of_kv;              // BIT_FLAG         -- reached end of key-value sequence, looking for comma delimiter or end of file signified by `tree_depth == 0`.

    signal output next_tree_depth;       // BIT_FLAG         -- next state for `tree_depth`.
    signal output next_parsing_to_key;   // BIT_FLAG         -- next state for `parsing_to_key`.
    signal output next_inside_key;       // BIT_FLAG         -- next state for `inside_key`.
    signal output next_parsing_to_value; // BIT_FLAG         -- next state for `parsing_to_value`.
    signal output next_inside_value;     // BIT_FLAG         -- next state for `inside_value`.
    signal output next_end_of_kv;        // BIT_FLAG         -- next state for `end_of_kv`.

    

    // signal output escaping; // TODO: Add this in!

    //--------------------------------------------------------------------------------------------//
    //-Delimeters---------------------------------------------------------------------------------//
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
    //--------------------------------------------------------------------------------------------//
    // White space
    // - ASCII char: `\n`
    var newline = 10;
    // - ASCII char: ` `
    var space = 32;
    //--------------------------------------------------------------------------------------------//
    // Escape
    // - ASCII char: `\`
    var escape = 92;
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    //-MACHINE INSTRUCTIONS-----------------------------------------------------------------------//
    // TODO: ADD CASE FOR `is_number` for in range 48-57 https://www.ascii-code.com since a value may just be a number
    // Output management
    component matcher = Switch(5, 6);
    component mask = StateToMask();
    var state =             = [tree_depth, parsing_to_key, inside_key, parsing_to_value, inside_value, end_of_kv];   
    mask.in               <== state;     
    var do_nothing[4]       = [ 0,         0,              0,          0,                0,            0        ]; // Command returned by switch if we want to do nothing, e.g. read a whitespace char while looking for a key
    var hit_start_brace[4]  = [ 1,         0,              0,          0,                0,            0        ]; // Command returned by switch if we hit a start brace `{`
    var hit_end_brace[4]    = [-1,         0,              0,          0,                0,            0        ]; // Command returned by switch if we hit a end brace `}`
    var hit_quote[4]        = [ 0,        -1,              1,         -1,                1,            1        ]; // Command returned by switch if we hit a quote `"`
    var hit_colon[4]        = [ 0,         0,              0,          1,                0,            0        ]; // Command returned by switch if we hit a colon `:`
    var hit_comma[4]        = [ 0,         1,              0,          0,                0,           -1        ];
    
    matcher.branches      <== [start_brace,     end_brace,      quote,     colon,      comma    ];
    matcher.vals          <== [hit_start_brace, hit_end_brace,  hit_quote, hit_colon,  hit_comma];
    matcher.case          <== byte;

    component mulMaskAndOut = ArrayMul(6);
    mulMaskAndOut.lhs <== mask.out;
    mulMaskAndOut.rhs <== matcher.out;

    component addToState = ArrayAdd(6);
    addToState.lhs <== state;
    addToState.rhs <== mulMaskAndOut.out;

    out.next_tree_depth       = addToState.out[0];
    out.next_parsing_to_key   = addToState.out[1];
    out.next_inside_key       = addToState.out[2];
    out.next_parsing_to_value = addToState.out[3];
    out.next_inside_value     = addToState.out[4];
    out.next_end_of_kv        = addToState.out[5];

     
    // TODO: Assert this never goes below zero (mod p)
    next_tree_depth  <== tree_depth + (parsing_to_key + next_end_of_kv) * matcher.out[0]; // IF ((`parsing_to_key` OR `next_end_of_kv`) AND `read_brace` THEN `increase/decrease_depth`

    // Constrain bit flags
    next_parsing_to_key * (1 - next_parsing_to_key)     === 0; // - constrain that `next_parsing_to_key` remain a bit flag
    next_inside_key * (1 - next_inside_key)             === 0; // - constrain that `next_inside_key` remain a bit flag
    next_parsing_to_value * (1 - next_parsing_to_value) === 0; // - constrain that `next_parsing_to_value` remain a bit flag
    next_inside_value * (1 - next_inside_value)         === 0; // - constrain that `next_inside_value` remain a bit flag 
    next_end_of_kv * (1 - next_end_of_kv)               === 0; // - constrain that `next_end_of_kv` remain a bit flag

    component depthIsZero             = IsZero();   
    depthIsZero.in                  <== tree_depth;     // Determine if `tree_depth` was `0`
    component isOneLess               = IsEqual();      
    isOneLess.in[0]                 <== -1;             
    isOneLess.in[1]                 <== matcher.out[0]; // Determine if instruction was to `decrease_depth`
    depthIsZero.out * isOneLess.out === 0;              // IF ( `decrease_depth` AND `tree_depth == 0`) THEN FAIL 
    // TODO: Can hit comma and then be sent to next KV, so comma will engage `parsing_to_key`
    //--------------------------------------------------------------------------------------------//
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

// TODO: Note at the moment mask 2 and 4 are the same, so this can be removed if it maintains.
template StateToMask() {
    signal input state[6];
    signal output mask[6];
    
    var tree_depth = state[0];
    var parsing_to_key = state[1];
    var inside_key = state[2];
    var parsing_to_value = state[3];
    var inside_value = state[4];
    var end_of_kv = state[5];

    signal NOT_INSIDE_KEY_AND_NOT_INSIDE_VALUE = (1 - inside_key) * (1 - inside_value);
    signal NOT_PARSING_TO_KEY_AND_NOT_PARSING_TO_VALUE = (1 - parsing_to_key) * (1 - parsing_to_value);

    // `tree_depth` can change: `IF (parsing_to_key OR parsing_to_value)`
    mask[0] <== parsing_to_key + parsing_to_value; // TODO: Make sure these are never both 1!

    
    // `parsing_to_key` can change: `IF ((NOT inside_key) AND (NOT inside_value))`
    mask[1] <== NOT_INSIDE_KEY_AND_NOT_INSIDE_VALUE;

    // `inside_key` can change: `IF ((NOT parsing_to_key) AND (NOT parsing_to_value))`
    mask[2] <== NOT_PARSING_TO_KEY_AND_NOT_PARSING_TO_VALUE;

    // `parsing_to_value` can change: `IF ((NOT inside_key) AND (NOT inside_key) AND (NOT inside_value))`
    mask[3] <== (1 - parsing_to_key) * NOT_INSIDE_KEY_AND_NOT_INSIDE_VALUE;

    // `inside_value` can change: `IF ((NOT parsing_to_key) AND (NOT parsing to value))`
    mask[4] <== NOT_PARSING_TO_KEY_AND_NOT_PARSING_TO_VALUE;

    // `end_of_kv` can change: `IF ((NOT inside_key) AND (NOT inside_value) AND (NOT parsing_to_key) AND (NOT parsing_to_value)
    mask[5] <== NOT_INSIDE_KEY_AND_NOT_INSIDE_VALUE * NOT_PARSING_TO_KEY_AND_NOT_PARSING_TO_VALUE;
}