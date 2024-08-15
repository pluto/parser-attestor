pragma circom 2.1.9;

include "utils.circom";
include "language.circom";

/*
TODO: Change the values to push onto stack to be given by START_BRACE, COLON, etc.
*/

template StateUpdate(MAX_STACK_HEIGHT) {
    signal input byte;  

    signal input stack[MAX_STACK_HEIGHT][2];  // STACK -- how deep in a JSON nest we are and what type we are currently inside (e.g., `1` for object, `-1` for array).
    signal input parsing_string;
    signal input parsing_number;
    // TODO
    // signal parsing_boolean;
    // signal parsing_null;

    signal output next_stack[MAX_STACK_HEIGHT][2];
    signal output next_parsing_string;
    signal output next_parsing_number;
    
    component Syntax  = Syntax();
    component Command = Command();

    var pushpop = 0;
    var read_write_value = 0;
    var parsing_state[4]     = [pushpop, read_write_value, parsing_string, parsing_number];   
    
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
    newStack.stack           <== stack;
    newStack.pushpop         <== addToState.out[0];
    newStack.read_write_value       <== addToState.out[1];
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
    signal read_write_value      <== in[1];
    signal parsing_string <== in[2];
    signal parsing_number <== in[3];

    // TODO: Pushpop is probably unecessary actually
    // `pushpop` can change:  IF NOT `parsing_string`
    out[0] <== (1 - parsing_string);

    // `read_write_value`can change: IF NOT `parsing_string` 
    out[1] <== (1 - parsing_string);

    // `parsing_string` can change:
    out[2] <== 1 - 2 * parsing_string;

    // `parsing_number` can change: 
    component isDelimeter   = InRange(8);
    isDelimeter.in        <== read_write_value;
    isDelimeter.range[0]  <== 1;
    isDelimeter.range[1]  <== 4;
    component isNumber      = IsEqual();
    isNumber.in           <== [read_write_value, 256];
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

// TODO: Check if underconstrained
template GetTopOfStack(n) {
    signal input stack[n][2];
    signal output value[2];
    signal output pointer;

    component isUnallocated[n];
    component atTop = SwitchArray(n,2);
    var selector = 0;
    for(var i = 0; i < n; i++) {
        isUnallocated[i]         = IsEqualArray(2);
        isUnallocated[i].in[0] <== [0,0];
        isUnallocated[i].in[1] <== stack[i];
        selector += (1 - isUnallocated[i].out);
        atTop.branches[i] <== i + 1;
        atTop.vals[i]     <== stack[i];
    }
    atTop.case <== selector;
    value      <== atTop.out;
    pointer    <== selector;
}

// TODO: IMPORTANT NOTE, THE STACK IS CONSTRAINED TO 2**8 so the LessThan and GreaterThan work (could be changed)
// TODO: Might be good to change value before increment pointer AND decrement pointer before changing value
template RewriteStack(n) {
    assert(n < 2**8);
    signal input stack[n][2];
    signal input pushpop;
    signal input read_write_value;
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

    // top of stack is a 3, then we need to pop off 3, and check the value underneath 
    // is correct match (i.e., a brace or bracket (1 or 2))
    */
    
    //-----------------------------------------------------------------------------//
    // * scan value on top of stack *
    component topOfStack = GetTopOfStack(n);
    topOfStack.stack   <== stack;
    signal pointer     <== topOfStack.pointer;
    signal current_value[2]    <== topOfStack.value;
    // * check if value indicates currently in an array *
    component inArray = IsEqual();
    inArray.in[0]    <== current_value[0];
    inArray.in[1]    <== 2;
    //-----------------------------------------------------------------------------//

    //-----------------------------------------------------------------------------//
    // * check what value was read *
    // * read in a comma
    component readComma = IsEqual();
    readComma.in[0]   <== 4;
    readComma.in[1]   <== read_write_value;
    // * read in either an end brace `}` or an end bracket `]` *
    component readEndChar = IsZero();
    readEndChar.in <== (read_write_value + 1) * (read_write_value + 2);
    // * read in an end bracket `]` *
    component readEndArr = IsZero();
    readEndArr.in      <== read_write_value + 2;

    // TODO: Can remove all the pushpop stuff by checking what character we got. E.g., if it is "negative" or comma, we pop, if it is positive we push, basically
    signal READ_COMMA_AND_IN_ARRAY <== (1 - readComma.out) + (1 - inArray.out); // POORLY NAMED. THIS IS MORE LIKE XNOR or something.
    component isReadCommaAndInArray   = IsZero();
    isReadCommaAndInArray.in       <== READ_COMMA_AND_IN_ARRAY;

    signal read_comma_in_array <== readComma.out * inArray.out;




    component isPop = IsZero();
    isPop.in      <== (1 - isReadCommaAndInArray.out) * pushpop + 1; // TODO: can simplify?

    component isPush = IsZero();
    isPush.in     <== pushpop - 1;
    component prev_indicator[n];
    component indicator[n];
    signal isPopAt[n];
    signal isPushAt[n];



    signal NOT_READ_COMMA      <== (1 - readComma.out) * read_write_value;
    signal READ_COMMA          <== readComma.out * ((1-inArray.out) * (-3) + inArray.out * (-2));
    signal corrected_read_write_value <== READ_COMMA + NOT_READ_COMMA;

    signal isPopArr    <== isPop.out * readEndArr.out;

    for(var i = 0; i < n; i++) {
        // points to 1 value back from top
        prev_indicator[i] = IsZero();
        prev_indicator[i].in <== pointer - 1 - isPop.out - i;

        // Points to top of stack if POP else it points to unallocated position
        indicator[i]         = IsZero();
        indicator[i].in    <== pointer - isPop.out - i;   
    }

    component atColon = IsEqual();
    atColon.in[0]   <== current_value[0]; // TODO: Move colon to be a toggle in the second stack position.
    atColon.in[1]   <== 3;
    signal isDoublePop <== atColon.out * readEndChar.out;

    signal isPopAtPrev[n];
    signal second_pop_val[n];
    signal first_pop_val[n];
    signal temp_val[n];
    signal temp_val2[n];

// log("read_comma_in_array: ", read_comma_in_array);
    for(var i = 0; i < n; i++) {

        // Indicators for index to PUSH to or POP from
        isPopAtPrev[i]     <== prev_indicator[i].out * isDoublePop; // temp signal
        isPopAt[i]         <== indicator[i].out * isPop.out; // want to add: `prev_indicator[i] * isDoublePop`

        isPushAt[i]        <== indicator[i].out * isPush.out; 

        // Leave the stack alone except for where we indicate change
        second_pop_val[i]  <== isPopAtPrev[i] * corrected_read_write_value;
        temp_val[i]        <== corrected_read_write_value - (3 + corrected_read_write_value) * isDoublePop;
        first_pop_val[i]   <== isPopAt[i] * temp_val[i]; // = isPopAt[i] * (corrected_read_write_value * (1 - isDoublePop) - 3 * isDoublePop)

        next_stack[i][0]      <== stack[i][0] + isPushAt[i] * corrected_read_write_value + first_pop_val[i] + second_pop_val[i];

        temp_val2[i]          <== prev_indicator[i].out * read_comma_in_array;
        next_stack[i][1]      <== stack[i][1] + temp_val2[i] - stack[i][1] * isPopArr;

        // log("prev_indicator[i]: ", prev_indicator[i].out);
        // log("next_stack[", i,"]    ", "= [",next_stack[i][0], "][", next_stack[i][1],"]" );
        // TODO: Constrain next_stack entries to be 0,1,2,3
    }

    // TODO: Reimplement these!
    // component isOverflow = GreaterThan(8);
    // isOverflow.in[0]   <== next_pointer;
    // isOverflow.in[1]   <== n;
    // isOverflow.out     === 0;

    // component isUnderflow = LessThan(8);
    // isUnderflow.in[0]   <== next_pointer;
    // isUnderflow.in[1]   <== 0;
    // isUnderflow.out     === 0;
}