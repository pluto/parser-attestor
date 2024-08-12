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

TODO: Might not need the "parsing object" and "parsing array" as these are kinda captured by the stack?
*/
template StateUpdate(MAX_STACK_HEIGHT) {
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
    signal input stack[MAX_STACK_HEIGHT];            // STACK -- how deep in a JSON nest we are and what type we are currently inside (e.g., `1` for object, `-1` for array).
    signal input parsing_string;
    signal input parsing_number;
    // signal parsing_boolean;
    // signal parsing_null; // TODO

    signal output next_pointer;
    signal output next_stack[MAX_STACK_HEIGHT];
    signal output next_parsing_string;
    signal output next_parsing_number;
    //--------------------------------------------------------------------------------------------//
    //-Instructions for ASCII---------------------------------------------------------------------//
    var pushpop = 0;
    var stack_val = 0;
    var parsing_state[4]     = [pushpop, stack_val, parsing_string, parsing_number];   
    var do_nothing[4]        = [0,       0,         0,              0             ]; // Command returned by switch if we want to do nothing, e.g. read a whitespace char while looking for a key
    var hit_start_brace[4]   = [1,       1,         0,              0             ]; // Command returned by switch if we hit a start brace `{`
    var hit_end_brace[4]     = [-1,      -1,        0,              0             ]; // Command returned by switch if we hit a end brace `}`
    var hit_start_bracket[4] = [1,       2,         0,              0             ]; // TODO: Might want `in_value` to toggle. Command returned by switch if we hit a start bracket `[` (TODO: could likely be combined with end bracket)
    var hit_end_bracket[4]   = [-1,      -2,        0,              0             ]; // Command returned by switch if we hit a start bracket `]` 
    var hit_quote[4]         = [0,       0,         1,              0             ]; // TODO: Mightn ot want this to toglle `parsing_array`. Command returned by switch if we hit a quote `"`
    var hit_colon[4]         = [1,       3,         0,              0             ]; // Command returned by switch if we hit a colon `:`
    var hit_comma[4]         = [-1,      -3,        0,              -1            ]; // Command returned by switch if we hit a comma `,`
    var hit_number[4]        = [0,       0,         0,              1             ]; // Command returned by switch if we hit some decimal number (e.g., ASCII 48-57)
    //--------------------------------------------------------------------------------------------//
    
    //--------------------------------------------------------------------------------------------//
    //-State machine updating---------------------------------------------------------------------//
    // * yield instruction based on what byte we read *
    component matcher           = SwitchArray(8, 4);
    var number = 256; // Number beyond a byte to represent an ASCII numeral
    matcher.branches          <== [start_brace,     end_brace,      quote,     colon,      comma,     start_bracket,     end_bracket,     number    ];
    matcher.vals              <== [hit_start_brace, hit_end_brace,  hit_quote, hit_colon,  hit_comma, hit_start_bracket, hit_end_bracket, hit_number];
    component numeral_range_check = InRange(8);
    numeral_range_check.in    <== byte;
    numeral_range_check.range <== [48, 57]; // ASCII NUMERALS
    matcher.case              <== (1 - numeral_range_check.out) * byte + numeral_range_check.out * 256; // IF (NOT is_number) THEN byte ELSE 256
    // * get the instruction mask based on current state *
    component mask             = StateToMask(MAX_STACK_HEIGHT);
    mask.in                  <== parsing_state;     
    // * multiply the mask array elementwise with the instruction array *
    component mulMaskAndOut    = ArrayMul(4);
    mulMaskAndOut.lhs        <== mask.out;
    mulMaskAndOut.rhs        <== matcher.out;
    // * add the masked instruction to the state to get new state *
    component addToState       = ArrayAdd(4);
    addToState.lhs           <== parsing_state;
    addToState.rhs           <== mulMaskAndOut.out;
    // * set the new state *
    component newStack         = RewriteStack(MAX_STACK_HEIGHT);
    newStack.pointer         <== pointer;
    newStack.stack           <== stack;
    newStack.pushpop         <== addToState.out[0];
    newStack.stack_val    <== addToState.out[1];
    next_pointer             <== newStack.next_pointer;
    next_stack               <== newStack.next_stack;
    next_parsing_string      <== addToState.out[2];
    next_parsing_number      <== addToState.out[3];
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    // // DEBUGGING: internal state
    // for(var i = 0; i<7; i++) {
    //     log("------------------------------------------");
    //     log(">>>> parsing_state[",i,"]:        ", parsing_state[i]);
    //     log(">>>> mask[",i,"]         :        ", mask.out[i]);
    //     log(">>>> command[",i,"]      :        ", matcher.out[i]);
    //     log(">>>> addToState[",i,"]   :        ", addToState.out[i]);
    // }
    // Debugging
    // log("next_pointer       ", "= ", next_pointer);
    // for(var i = 0; i<4; i++) {
    //     log("next_stack[", i,"]    ", "= ", next_stack[i]);
    // }
    // log("next_parsing_string", "= ", next_parsing_string);
    // log("next_parsing_number", "= ", next_parsing_number);
    // log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
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

template StateToMask(n) {
    signal input in[4];
    signal output out[4];
    
    signal pushpop        <== in[0];
    signal stack_val      <== in[1];
    signal parsing_string <== in[2];
    signal parsing_number <== in[3];

    // component stackTop = Switch(n);


    // `pushpop` can change: IF NOT `parsing_string`
    out[0] <== (1 - parsing_string);

    // `stack_val`: IF NOT `parsing_string` OR 
    // TODO: `parsing_array`
    out[1] <== (1 - parsing_string);

    // `parsing_string` can change:
    out[2] <== 1 - 2 * parsing_string;

    // `parsing_number` can change: 
    out[3] <== (1 - parsing_string) * (- 2 * parsing_number);
}

template GetTopOfStack(n) {
    signal input stack[n];
    signal input pointer;

    signal output out;

    component atTop = Switch(n);
    for(var i = 0; i < n; i++) {
        atTop.branches[i] <== i + 1;
        atTop.vals[i]     <== stack[i];
    }
    atTop.case <== pointer;

    out <== atTop.out;
}

// TODO: IMPORTANT NOTE, THE STACK IS CONSTRAINED TO 2**8 so the LessThan and GreaterThan work (could be changed)
// TODO: Might be good to change value before increment pointer AND decrement pointer before changing value
template RewriteStack(n) {
    assert(n < 2**8);
    signal input pointer;
    signal input stack[n];
    signal input pushpop;
    signal input stack_val;
    signal output next_pointer;
    signal output next_stack[n];

    /*
    IDEA:

    We want to look at the old data
    - if pushpop is 0, we are going to just return the old stack
    - if pushpop is 1, we are going to increment the pointer and write a new value
    - if pushpop is -1, we are going to decrement the pointer and delete an old value if it was the same value

    TODO: There's the weird case of "no trailing commas" for KVs in JSON. 
    This constitutes valid JSON, fortunately, and is NOT optional. Or, at least,
    we should NOT consider it to be for this current impl.
    Basically, JSON must be like:
    ```
    {
        "a": "valA",
        "b": "valB"
    }
    ```
    so there is the one end here where we have to go from:
    stack      == [1,3,0,0,...]
    to
    next_stack == [0,0,0,0,...]
    on the case we get a POP instruction reading an object OR an array (no trailing commas in arrays either)
    */

    // Indicate which position in the stack should change (if any)
    component isPop = IsZero();
    isPop.in      <== pushpop + 1;
    component isPush = IsZero();
    isPush.in     <== pushpop - 1;
    component prev_indicator[n];
    component indicator[n];
    signal isPopAt[n];
    signal isPushAt[n];

    component readEndChar = IsZero();
    readEndChar.in <== (stack_val + 1) * (stack_val + 2);

    // top of stack is a 3, then we need to pop off 3, and check the value underneath 
    // is correct match (i.e., a brace or bracket (1 or 2))


    signal accum[n];

    for(var i = 0; i < n; i++) {
        // points to 1 value back from top
        prev_indicator[i] = IsZero();
        prev_indicator[i].in <== pointer - 2 * isPop.out - i;

        // Points to top of stack if POP else it points to unallocated position
        indicator[i]         = IsZero();
        indicator[i].in    <== pointer - isPop.out - i;   

        accum[i] <== stack[i] * indicator[i].out;
    }

    var next_accum = 0;
    for(var i = 0; i < n; i++) {
        next_accum += accum[i];
    }

    component atColon = IsZero();
    atColon.in      <== next_accum - 3;
    signal isDoublePop <== atColon.out * readEndChar.out;

    signal isPopAtPrev[n];
    signal second_pop_val[n];
    signal first_pop_val[n];
    signal temp_val[n];


    for(var i = 0; i < n; i++) {

        // Indicators for index to PUSH to or POP from
        isPopAtPrev[i]     <== prev_indicator[i].out * isDoublePop; // temp signal
        isPopAt[i]         <== indicator[i].out * isPop.out; // want to add: `prev_indicator[i] * isDoublePop`

        isPushAt[i]        <== indicator[i].out * isPush.out; 

        // Leave the stack alone except for where we indicate change
        second_pop_val[i]            <== isPopAtPrev[i] * stack_val;
        temp_val[i]                  <== stack_val - (3 + stack_val) * isDoublePop;
        first_pop_val[i]             <== isPopAt[i] * temp_val[i]; // = isPopAt[i] * (stack_val * (1 - isDoublePop) - 3 * isDoublePop)

        next_stack[i]      <== stack[i] + isPushAt[i] * stack_val + first_pop_val[i] + second_pop_val[i];

        // TODO: Constrain next_stack entries to be 0,1,2,3
    }

    // TODO: This decrements by 2 if we hit a ] or } when the top of stack is 3
    next_pointer <== pointer + (1 + isDoublePop) * pushpop; // If pushpop is 0, pointer doesn't change, if -1, decrement, +1 increment

    component isOverflow = GreaterThan(8);
    isOverflow.in[0]   <== next_pointer;
    isOverflow.in[1]   <== n;
    isOverflow.out     === 0;

    component isUnderflow = LessThan(8);
    isUnderflow.in[0]   <== next_pointer;
    isUnderflow.in[1]   <== 0;
    isUnderflow.out     === 0;
}