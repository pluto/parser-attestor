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
*/

/*
TODO
*/
template StateUpdate() {
    signal input byte;  

    signal input tree_depth;          // STATUS_INDICATOR -- how deep in a JSON branch we are, e.g., `user.balance.value` key should be at depth `3`. 
                                      // constrainted to be greater than or equal to `0`.
    signal input parsing_key;         // BIT_FLAG         -- whether we are currently parsing bytes until we find the next key (mutally exclusive with `inside_key` and both `*_value flags).
    signal input inside_key;          // BIT_FLAG         -- whether we are currently inside a key (mutually exclusive with `parsing_key` and both `*_value` flags).
    signal input parsing_value;       // BIT_FLAG         -- whether we are currently parsing bytes until we find the next value (mutually exclusive with `inside_value` and both `*_key` flags).
    signal input inside_value;        // BIT_FLAG         -- whether we are currently inside a value (mutually exclusive with `parsing_value` and both `*_key` flags).

    signal output next_tree_depth;    // STATUS_INDICATOR -- next state for `tree_depth`.
    signal output next_parsing_key;   // BIT_FLAG         -- next state for `parsing_key`.
    signal output next_inside_key;    // BIT_FLAG         -- next state for `inside_key`.
    signal output next_parsing_value; // BIT_FLAG         -- next state for `parsing_value`.
    signal output next_inside_value;  // BIT_FLAG         -- next state for `inside_value`.

    // TODO: Add this in!
    // signal input escaping;  // BIT_FLAG         -- whether we have hit an escape ASCII symbol inside of a key or value. 
    // signal output escaping; 

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

    // TODO: ADD CASE FOR `is_number` for in range 48-57 https://www.ascii-code.com since a value may just be a number
    //--------------------------------------------------------------------------------------------//
    //-Instructions for ASCII---------------------------------------------------------------------//
    var state[5]             = [tree_depth, parsing_key, inside_key, parsing_value, inside_value];   
    var do_nothing[5]        = [ 0,         0,           0,          0,             0           ]; // Command returned by switch if we want to do nothing, e.g. read a whitespace char while looking for a key
    var hit_start_brace[5]   = [ 1,         1,           0,          -1,            0           ]; // Command returned by switch if we hit a start brace `{`
    var hit_end_brace[5]     = [-1,         0,           0,          0,             0           ]; // Command returned by switch if we hit a end brace `}`
    var hit_quote[5]         = [ 0,         0,           1,          0,             1           ]; // Command returned by switch if we hit a quote `"`
    var hit_colon[5]         = [ 0,         -1,          0,          1,             0           ]; // Command returned by switch if we hit a colon `:`
    var hit_comma[5]         = [ 0,         1,           0,          -1,            0           ]; // Command returned by switch if we hit a comma `,`
    var hit_start_bracket[5] = [ 0,         0,           0,          0,             1           ]; // Command returned by switch if we hit a start bracket `[` (TODO: could likely be combined with end bracket)
    var hit_end_bracket[5]   = [ 0,         0,           0,          0,             1           ]; // Command returned by switch if we hit a start bracket `]` 
    // TODO
    var hit_number[5]        = [ 0,         0,           0,          0,             1           ]; // Command returned by switch if we hit some decimal number (e.g., ASCII 48-57)
    //--------------------------------------------------------------------------------------------//
    
    //--------------------------------------------------------------------------------------------//
    //-State machine updating---------------------------------------------------------------------//
    // * yield instruction based on what byte we read *
    component matcher       = Switch(8, 5);
    matcher.branches      <== [start_brace,     end_brace,      quote,     colon,      comma,     start_bracket,     end_bracket    , number    ];
    matcher.vals          <== [hit_start_brace, hit_end_brace,  hit_quote, hit_colon,  hit_comma, hit_start_bracket, hit_end_bracket, hit_number];
    component LEQ = LessEqThan(8);
    matcher.case          <== byte;
    // * get the instruction mask based on current state *
    component mask          = StateToMask();
    mask.state            <== state;     
    // * multiply the mask array elementwise with the instruction array *
    component mulMaskAndOut = ArrayMul(5);
    mulMaskAndOut.lhs     <== mask.mask;
    mulMaskAndOut.rhs     <== matcher.out;
    // * add the masked instruction to the state to get new state *
    component addToState    = ArrayAdd(5);
    addToState.lhs        <== state;
    addToState.rhs        <== mulMaskAndOut.out;
    // * set the new state *
    next_tree_depth       <== addToState.out[0];
    next_parsing_key      <== addToState.out[1];
    next_inside_key       <== addToState.out[2];
    next_parsing_value    <== addToState.out[3];
    next_inside_value     <== addToState.out[4];
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    // // DEBUGGING: internal state
    // for(var i = 0; i<5; i++) {
    //     log("-----------------------");
    //     log("mask[",i,"]:         ", mask.mask[i]);
    //     log("mulMaskAndOut[",i,"]:", mulMaskAndOut.out[i]);
    //     log("state[",i,"]:        ", state[i]);
    //     log("next_state[",i,"]:   ", addToState.out[i]);
    // }
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    //-Constraints--------------------------------------------------------------------------------//
    // * constrain bit flags *
    next_parsing_key * (1 - next_parsing_key)     === 0; // - constrain that `next_parsing_key` remain a bit flag
    next_inside_key * (1 - next_inside_key)       === 0; // - constrain that `next_inside_key` remain a bit flag
    next_parsing_value * (1 - next_parsing_value) === 0; // - constrain that `next_parsing_value` remain a bit flag
    next_inside_value * (1 - next_inside_value)   === 0; // - constrain that `next_inside_value` remain a bit flag 
    // * constrain `tree_depth` to never hit -1 (TODO: should always moves in 1 bit increments?)
    component isMinusOne = IsEqual();      
    isMinusOne.in[0]   <== -1;             
    isMinusOne.in[1]   <== next_tree_depth; 
    isMinusOne.out     === 0;              
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
    signal input state[5];
    signal output mask[5];
    
    var tree_depth    = state[0];
    var parsing_key   = state[1];
    var inside_key    = state[2];
    var parsing_value = state[3];
    var inside_value  = state[4];

    signal NOT_INSIDE_KEY_AND_NOT_INSIDE_VALUE <== (1 - inside_key) * (1 - inside_value);
    signal NOT_PARSING_VALUE_NOT_INSIDE_VALUE  <== (1 - parsing_value) * (1 - inside_value);

    component init_tree = IsZero();
    init_tree.in      <== tree_depth;

    // `tree_depth` can change: `IF (parsing_key XOR parsing_value XOR end_of_kv)`
    mask[0] <== init_tree.out + parsing_key + parsing_value; // TODO: Make sure these are never both 1!
    
    // `parsing_key` can change: `IF ((NOT inside_key) AND (NOT inside_value) AND (NOT parsing_value))`
    mask[1] <== NOT_INSIDE_KEY_AND_NOT_INSIDE_VALUE;

    // `inside_key` can change: `IF ((NOT parsing_value) AND (NOT inside_value) AND inside_key) THEN mask <== -1 ELSEIF (NOT parsing_value) AND (NOT inside_value) THEN mask <== 1`
    mask[2] <== NOT_PARSING_VALUE_NOT_INSIDE_VALUE - 2 * inside_key;

    // `parsing_value` can change: `IF ((NOT inside_key) AND (NOT inside_value) AND (tree_depth != 0))`
    mask[3] <== NOT_INSIDE_KEY_AND_NOT_INSIDE_VALUE * (1 - init_tree.out);

    // `inside_value` can change: `IF (parsing_value AND (NOT inside_value)) THEN mask <== 1 ELSEIF (inside_value) mask <== -1`
    mask[4] <== parsing_value - 2 * inside_value;
}