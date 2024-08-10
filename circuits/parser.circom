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
JSON TYPES:
Number.
String.
Boolean.
Array.
Object.
Whitespace.
Null.
*/
template StateUpdate() {
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

    signal input byte;  

    signal input pointer;             // POINTER -- points to the stack to mark where we currently are inside the JSON.
    signal input stack[4];            // STACK -- how deep in a JSON nest we are and what type we are currently inside (e.g., `1` for object, `-1` for array).
    signal input parsing_string;
    signal input parsing_array;
    signal input parsing_object;
    signal input parsing_number;
    signal input key_or_value;              // BIT_FLAG-- whether we are in a key or a value
    // signal parsing_boolean;
    // signal parsing_null; // TODO

    signal output next_pointer;
    signal output next_stack[4];
    signal output next_parsing_string;
    signal output next_parsing_object;
    signal output next_parsing_array;
    signal output next_parsing_number;
    signal output next_key_or_value;
    //--------------------------------------------------------------------------------------------//
    //-Instructions for ASCII---------------------------------------------------------------------//
    var pushpop = 0;
    var obj_or_arr = 0;
    var parsing_state[7]     = [pushpop, obj_or_arr, parsing_string, parsing_array, parsing_object, parsing_number, key_or_value];   
    var do_nothing[7]        = [0,          0,       0,             0,             0,              0,              0]; // Command returned by switch if we want to do nothing, e.g. read a whitespace char while looking for a key
    var hit_start_brace[7]   = [1,          1,       0,            -1,             1,              0,              0]; // Command returned by switch if we hit a start brace `{`
    var hit_end_brace[7]     = [-1,          1,      0,             0,            -1,              0,              0]; // Command returned by switch if we hit a end brace `}`
    var hit_start_bracket[7] = [1,          -1,       0,             1,            -1,              0,              0]; // TODO: Might want `key_or_value` to toggle. Command returned by switch if we hit a start bracket `[` (TODO: could likely be combined with end bracket)
    var hit_end_bracket[7]   = [-1,          -1,      0,            -1,             0,              0,              0]; // Command returned by switch if we hit a start bracket `]` 
    var hit_quote[7]         = [0,           0,       1,             1,             1,              0,              0]; // TODO: Mightn ot want this to toglle `parsing_array`. Command returned by switch if we hit a quote `"`
    var hit_colon[7]         = [0,           0,       0,             0,             0,              0,              1]; // Command returned by switch if we hit a colon `:`
    var hit_comma[7]         = [0,           0,       0,             0,             0,             -1,              0]; // Command returned by switch if we hit a comma `,`
    var hit_number[7]        = [0,           0,       0,             0,             0,              1,              0]; // Command returned by switch if we hit some decimal number (e.g., ASCII 48-57)
    //--------------------------------------------------------------------------------------------//
    
    //--------------------------------------------------------------------------------------------//
    //-State machine updating---------------------------------------------------------------------//
    // * yield instruction based on what byte we read *
    component matcher           = Switch(8, 7);
    var number = 256; // Number beyond a byte to represent an ASCII numeral
    matcher.branches          <== [start_brace,     end_brace,      quote,     colon,      comma,     start_bracket,     end_bracket,     number    ];
    matcher.vals              <== [hit_start_brace, hit_end_brace,  hit_quote, hit_colon,  hit_comma, hit_start_bracket, hit_end_bracket, hit_number];
    component numeral_range_check = InRange(8);
    numeral_range_check.in    <== byte;
    numeral_range_check.range <== [48, 57]; // ASCII NUMERALS
    matcher.case              <== (1 - numeral_range_check.out) * byte + numeral_range_check.out * 256; // IF (NOT is_number) THEN byte ELSE 256
    // * get the instruction mask based on current state *
    component mask             = StateToMask();
    mask.in                  <== parsing_state;     
    // * multiply the mask array elementwise with the instruction array *
    component mulMaskAndOut    = ArrayMul(7);
    mulMaskAndOut.lhs        <== mask.out;
    mulMaskAndOut.rhs        <== matcher.out;
    // * add the masked instruction to the state to get new state *
    component addToState       = ArrayAdd(7);
    addToState.lhs           <== parsing_state;
    addToState.rhs           <== mulMaskAndOut.out;
    // * set the new state *
    component newStack = RewriteStack(4);
    newStack.pointer    <== pointer;
    newStack.stack      <== stack;
    newStack.pushpop    <== addToState.out[0];
    newStack.obj_or_arr <== addToState.out[1];
    next_pointer        <== newStack.next_pointer;
    next_stack          <== newStack.next_stack;
    next_parsing_string <== addToState.out[2];
    next_parsing_array  <== addToState.out[3];
    next_parsing_object <== addToState.out[4];
    next_parsing_number <== addToState.out[5];
    next_key_or_value   <== addToState.out[6];    
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    // DEBUGGING: internal state
    // for(var i = 0; i<7; i++) {
    //     log("------------------------------------------");
    //     log(">>>> parsing_state[",i,"]:        ", parsing_state[i]);
    //     log(">>>> mask[",i,"]         :        ", mask.out[i]);
    //     log(">>>> command[",i,"]      :        ", matcher.out[i]);
    //     log(">>>> addToState[",i,"]   :        ", addToState.out[i]);
    // }
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    //-Constraints--------------------------------------------------------------------------------//
    // * constrain bit flags *
    // next_parsing_key * (1 - next_parsing_key)     === 0; // - constrain that `next_parsing_key` remain a bit flag
    // next_inside_key * (1 - next_inside_key)       === 0; // - constrain that `next_inside_key` remain a bit flag
    // next_parsing_value * (1 - next_parsing_value) === 0; // - constrain that `next_parsing_value` remain a bit flag
    // next_inside_value * (1 - next_inside_value)   === 0; // - constrain that `next_inside_value` remain a bit flag 
    // // * constrain `tree_depth` to never hit -1 (TODO: should always moves in 1 bit increments?)
    // component isMinusOne = IsEqual();      
    // isMinusOne.in[0]   <== -1;             
    // isMinusOne.in[1]   <== next_tree_depth; 
    // isMinusOne.out     === 0;              
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

template StateToMask() {
    signal input in[7];
    signal output out[7];
    
    signal pushpop        <== in[0];
    signal val_or_array   <== in[1];
    signal parsing_string <== in[2];
    signal parsing_array  <== in[3];
    signal parsing_object <== in[4];
    signal parsing_number <== in[5];
    signal key_or_value   <== in[6];

    // can push or pop the depth stack if we're not parsing a string
    out[0] <== (1 - parsing_string);

    // 
    out[1] <== (1 - parsing_string);

    // `parsing_string` can change:
    out[2] <== 1;
    
    // `parsing_array` can change:
    out[3] <== (1 - parsing_string);

    // `parsing_object` can change:
    out[4] <== (1 - parsing_string);

    // `parsing_number` can change: 
    out[5] <== (1 - parsing_string);

    // `key_or_value` can change:
    out[6] <== (1 - parsing_string);
}

template RewriteStack(n) {
    signal input pointer;
    signal input stack[n];
    signal input pushpop;
    signal input obj_or_arr;

    signal output next_pointer;
    signal output next_stack[n];

    next_pointer <== pointer + pushpop; // If pushpop is 0, pointer doesn't change, if -1, decrement, +1 increment

    /*
    IDEA:

    We want to look at the old data
    - if pushpop is 0, we are going to just return the old stack
    - if pushpop is 1, we are going to increment the pointer and write a new value
    - if pushpop is -1, we are going to decrement the pointer and delete an old value if it was the same value
    */

    // Indicate which position in the stack should change (if any)
    component indicator[n];
    for(var i = 0; i < n; i++) {
        indicator[i] = IsZero();
        indicator[i].in <== pointer - i; // Change at pointer or TODO: change at incremented pointer
        next_stack[i] <== indicator[i].out * obj_or_arr;
    }

}