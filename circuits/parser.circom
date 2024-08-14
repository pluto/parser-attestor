pragma circom 2.1.9;

include "utils.circom";
include "language.circom";

/*
TODO: Change the values to push onto stack to be given by START_BRACE, COLON, etc.
*/

template StateUpdate(MAX_STACK_HEIGHT) {
    signal input byte;  

    signal input pointer;             // POINTER -- points to the stack to mark where we currently are inside the JSON.
    signal input stack[MAX_STACK_HEIGHT][2];            // STACK -- how deep in a JSON nest we are and what type we are currently inside (e.g., `1` for object, `-1` for array).
    signal input parsing_string;
    signal input parsing_number;
    // TODO
    // signal parsing_boolean;
    // signal parsing_null;

    signal output next_pointer;
    signal output next_stack[MAX_STACK_HEIGHT][2];
    signal output next_parsing_string;
    signal output next_parsing_number;
    
    component Syntax  = Syntax();
    component Command = Command();

    var pushpop = 0;
    var stack_val = 0;
    var parsing_state[4]     = [pushpop, stack_val, parsing_string, parsing_number];   
    
    //--------------------------------------------------------------------------------------------//
    //-State machine updating---------------------------------------------------------------------//
    // * yield instruction based on what byte we read *
    component matcher           = SwitchArray(8, 4);
    matcher.branches          <== [Syntax.START_BRACE,  Syntax.END_BRACE,  Syntax.QUOTE,  Syntax.COLON,  Syntax.COMMA,  Syntax.START_BRACKET,  Syntax.END_BRACKET,  Syntax.NUMBER ];
    matcher.vals              <== [Command.START_BRACE, Command.END_BRACE, Command.QUOTE, Command.COLON, Command.COMMA, Command.START_BRACKET, Command.END_BRACKET, Command.NUMBER];
    component numeral_range_check = InRange(8);
    numeral_range_check.in    <== byte;
    numeral_range_check.range <== [48, 57]; // ASCII NUMERALS
    // log("isNumeral:", numeral_range_check.out);
    signal IS_NUMBER          <==  numeral_range_check.out * Syntax.NUMBER;
    matcher.case              <== (1 - numeral_range_check.out) * byte + IS_NUMBER; // IF (NOT is_number) THEN byte ELSE 256
    
    // * get the instruction mask based on current state *
    component mask             = StateToMask(MAX_STACK_HEIGHT);
    // mask.in                  <== parsing_state;    
    mask.in <== [matcher.out[0],matcher.out[1],parsing_string,parsing_number];  // TODO: This is awkward. Things need to be rewritten

    
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
    newStack.stack_val       <== addToState.out[1];
    next_pointer             <== newStack.next_pointer;
    next_stack               <== newStack.next_stack;
    next_parsing_string      <== addToState.out[2];
    next_parsing_number      <== addToState.out[3];

    // for(var i = 0; i < 4; i++) {
    //     log("matcher.out[",i,"]:   ", matcher.out[i]);
    //     log("mask.out[",i,"]:      ", mask.out[i]);
    //     log("mulMaskAndOut[",i,"]: ", mulMaskAndOut.out[i]);
    // }

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

template StateToMask(n) {
    // TODO: Probably need to assert things are bits where necessary.
    signal input in[4];
    signal output out[4];
    
    signal pushpop        <== in[0];
    signal stack_val      <== in[1];
    signal parsing_string <== in[2];
    signal parsing_number <== in[3];

    // `pushpop` can change:  IF NOT `parsing_string`
    out[0] <== (1 - parsing_string) * (1 - parsing_number);

    // `stack_val`can change: IF NOT `parsing_string` 
    out[1] <== (1 - parsing_string) * (1- parsing_number);

    // `parsing_string` can change:
    out[2] <== 1 - 2 * parsing_string;

    // `parsing_number` can change: 
    component isDelimeter   = InRange(8);
    isDelimeter.in        <== stack_val;
    isDelimeter.range[0]  <== 1;
    isDelimeter.range[1]  <== 4;
    component isNumber      = IsEqual();
    isNumber.in           <== [stack_val, 256];
    component isParsingString = IsEqual();
    isParsingString.in[0]     <== parsing_string;     
    isParsingString.in[1]     <== 1;
    component isParsingNumber = IsEqual();
    isParsingNumber.in[0]     <== parsing_number;     
    isParsingNumber.in[1]     <== 1;
    component toParseNumber   = Switch(16);
    // TODO: Could combine this into something that returns arrays so that we can set the mask more easily.
    toParseNumber.branches  <== [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    toParseNumber.vals      <== [0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,  0,  0,  0,  0,   0];
    component stateToNum      = Bits2Num(4);
    stateToNum.in           <== [isParsingString.out, isParsingNumber.out, isNumber.out, isDelimeter.out];
     //                                   1                 2                   4              8
    toParseNumber.case      <== stateToNum.out;
    // log("isNumber:        ", isNumber.out);
    // log("isParsingString: ", isParsingString.out);
    // log("isParsingNumber: ", isParsingNumber.out);
    // log("isDelimeter:     ", isDelimeter.out);
    // log("stateToNum:      ", stateToNum.out);
    // log("toParseNumber:   ", toParseNumber.out);

    out[3] <== toParseNumber.out;
}

template GetTopOfStack(n) {
    signal input stack[n][2];
    signal input pointer;

    signal output out[2];

    component atTop = SwitchArray(n,2);
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
    signal input stack[n][2];
    signal input pushpop;
    signal input stack_val;
    signal output next_pointer;
    signal output next_stack[n][2];

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
    component topOfStack = GetTopOfStack(n);
    topOfStack.pointer <== pointer;
    topOfStack.stack   <== stack;

    component isArray = IsEqual();
    isArray.in[0]    <== topOfStack.out[0];
    isArray.in[1]    <== 2;

    component readComma = IsEqual();
    readComma.in[0]   <== 4;
    readComma.in[1]   <== stack_val;

    signal READ_COMMA_AND_IN_ARRAY <== (1 - readComma.out) + (1 - isArray.out);
    component isReadCommaAndInArray   = IsZero();
    isReadCommaAndInArray.in       <== READ_COMMA_AND_IN_ARRAY;

    component isPop = IsZero();
    isPop.in      <== (1 - isReadCommaAndInArray.out) * pushpop + 1;
    component isPush = IsZero();
    isPush.in     <== pushpop - 1;
    component prev_indicator[n];
    component indicator[n];
    signal isPopAt[n];
    signal isPushAt[n];

    component readEndChar = IsZero();
    readEndChar.in <== (stack_val + 1) * (stack_val + 2);

    signal NOT_READ_COMMA      <== (1 - readComma.out) * stack_val;
    signal READ_COMMA          <== readComma.out * ((1-isArray.out) * (-3) + isArray.out * (-2));
    signal corrected_stack_val <== READ_COMMA + NOT_READ_COMMA;

    // top of stack is a 3, then we need to pop off 3, and check the value underneath 
    // is correct match (i.e., a brace or bracket (1 or 2))

    for(var i = 0; i < n; i++) {
        // points to 1 value back from top
        prev_indicator[i] = IsZero();
        prev_indicator[i].in <== pointer - 2 * isPop.out - i;

        // Points to top of stack if POP else it points to unallocated position
        indicator[i]         = IsZero();
        indicator[i].in    <== pointer - isPop.out - i;   
    }

    component atColon = IsEqual();
    atColon.in[0]   <== topOfStack.out[0];
    atColon.in[1]   <== 3;
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
        second_pop_val[i]  <== isPopAtPrev[i] * corrected_stack_val;
        temp_val[i]        <== corrected_stack_val - (3 + corrected_stack_val) * isDoublePop;
        first_pop_val[i]   <== isPopAt[i] * temp_val[i]; // = isPopAt[i] * (corrected_stack_val * (1 - isDoublePop) - 3 * isDoublePop)

        next_stack[i][0]      <== stack[i][0] + isPushAt[i] * corrected_stack_val + first_pop_val[i] + second_pop_val[i];

        // TODO: Constrain next_stack entries to be 0,1,2,3
    }

    signal IS_READ_COMMA_AND_IN_ARRAY_MODIFIER <== (1-isReadCommaAndInArray.out) * pushpop;
    next_pointer <== pointer + (1 + isDoublePop) * IS_READ_COMMA_AND_IN_ARRAY_MODIFIER; // If pushpop is 0, pointer doesn't change, if -1, decrement, +1 increment

    component isOverflow = GreaterThan(8);
    isOverflow.in[0]   <== next_pointer;
    isOverflow.in[1]   <== n;
    isOverflow.out     === 0;

    component isUnderflow = LessThan(8);
    isUnderflow.in[0]   <== next_pointer;
    isUnderflow.in[1]   <== 0;
    isUnderflow.out     === 0;
}