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

    var read_write_value = 0;
    var parsing_state[3]     = [read_write_value, parsing_string, parsing_number];   
    
    //--------------------------------------------------------------------------------------------//
    //-State machine updating---------------------------------------------------------------------//
    // * yield instruction based on what byte we read *
    component matcher           = SwitchArray(8, 3);
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
    mask.in <== [matcher.out[0],parsing_string,parsing_number];  // TODO: This is awkward. Things need to be rewritten

    
    // * multiply the mask array elementwise with the instruction array *
    component mulMaskAndOut    = ArrayMul(3);
    mulMaskAndOut.lhs        <== mask.out;
    mulMaskAndOut.rhs        <== matcher.out;
    // * add the masked instruction to the state to get new state *
    component addToState       = ArrayAdd(3);
    addToState.lhs           <== parsing_state;
    addToState.rhs           <== mulMaskAndOut.out;

    // * set the new state *
    component newStack         = RewriteStack(MAX_STACK_HEIGHT);
    newStack.stack            <== stack;
    newStack.read_write_value <== addToState.out[0];
    next_stack                <== newStack.next_stack;
    next_parsing_string       <== addToState.out[1];
    next_parsing_number       <== addToState.out[2];

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
    signal input in[3];
    signal output out[3];
    
    signal read_write_value <== in[0];
    signal parsing_string   <== in[1];
    signal parsing_number   <== in[2];

    // `read_write_value`can change: IF NOT `parsing_string` 
    out[0] <== (1 - parsing_string);

    // `parsing_string` can change:
    out[1] <== 1 - 2 * parsing_string;

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

    out[2] <== toParseNumber.out;
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
template RewriteStack(n) {
    assert(n < 2**8);
    signal input stack[n][2];
    signal input read_write_value;
    signal output next_stack[n][2];
    
    //-----------------------------------------------------------------------------//
    // * scan value on top of stack *
    component topOfStack      = GetTopOfStack(n);
    topOfStack.stack        <== stack;
    signal pointer          <== topOfStack.pointer;
    signal current_value[2] <== topOfStack.value;
    // * check if we are currently in a value of an object *
    component inObjectValue   = IsEqualArray(2);
    inObjectValue.in[0]     <== current_value;
    inObjectValue.in[1]     <== [1,1];
    // * check if value indicates currently in an array *
    component inArray         = IsEqual();
    inArray.in[0]           <== current_value[0];
    inArray.in[1]           <== 2;
    //-----------------------------------------------------------------------------//

    //-----------------------------------------------------------------------------//
    // * check what value was read *
    // * read in a start brace `{` *
    component readStartBrace     = IsEqual();
    readStartBrace.in          <== [read_write_value, 1];
    // * read in a start bracket `[` *
    component readStartBracket   = IsEqual();
    readStartBracket.in        <== [read_write_value, 2];
    // * read in an end brace `}` *
    component readEndBrace       = IsEqual();
    readEndBrace.in            <== [read_write_value, -1];
    // * read in an end bracket `]` *
    component readEndBracket     = IsEqual();
    readEndBracket.in          <== [read_write_value, -2];
    // * read in a colon `:` *
    component readColon          = IsEqual();
    readColon.in[0]            <== 3;
    readColon.in[1]            <== read_write_value;
    // * read in a comma `,` *
    component readComma          = IsEqual();
    readComma.in[0]            <== 4;
    readComma.in[1]            <== read_write_value;
    // * composite signals *
    signal readEndChar         <== readEndBrace.out + readEndBracket.out;
    signal readCommaInArray    <== readComma.out * inArray.out;
    signal readCommaNotInArray <== readComma.out * (1 - inArray.out);
    //-----------------------------------------------------------------------------//

    //-----------------------------------------------------------------------------//
    // * determine whether we are pushing or popping from the stack *
    component isPush       = IsEqual();
    isPush.in            <== [readStartBrace.out + readStartBracket.out, 1];
    component isPop        = IsEqual();
    isPop.in             <== [readEndBrace.out + readEndBracket.out, 1];
    // * set an indicator array for where we are pushing to or popping from* 
    component indicator[n];
    for(var i = 0; i < n; i++) {
        // Points
        indicator[i]       = IsZero();
        indicator[i].in  <== pointer - isPop.out - readColon.out - readComma.out - i; // Note, pointer points to unallocated region!
    }
    //-----------------------------------------------------------------------------//


    signal stack_change_value[2] <== [(isPush.out + isPop.out) * read_write_value, readColon.out + readCommaInArray - readCommaNotInArray];
    signal second_index_clear[n];
    for(var i = 0; i < n; i++) {
        next_stack[i][0]         <== stack[i][0] + indicator[i].out * stack_change_value[0];
        second_index_clear[i]    <== stack[i][1] * readEndChar;
        next_stack[i][1]         <== stack[i][1] + indicator[i].out * (stack_change_value[1] - second_index_clear[i]);
    }

    // TODO: WE CAN'T LEAVE 8 HERE, THIS HAS TO DEPEND ON THE STACK HEIGHT AS IT IS THE NUM BITS NEEDED TO REPR STACK HEIGHT IN BINARY
    component isUnderflowOrOverflow = InRange(8);
    isUnderflowOrOverflow.in     <== pointer - isPop.out + isPush.out;
    isUnderflowOrOverflow.range  <== [0,n];
    isUnderflowOrOverflow.out    === 1;
}