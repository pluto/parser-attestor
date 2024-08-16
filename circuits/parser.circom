pragma circom 2.1.9;

include "utils.circom";
include "language.circom";

/*
TODO: OKAY, so one big thing to notice is that we are effectively doubling up (if not tripling up) on checking what byte we have just read. If we mess with the Commands, matcher, mask, and rewrite stack, I think we can reduce the times
we call these sorts of things and consolidate this greatly. Probably can cut constraints down by a factor of 2.
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
    
    //--------------------------------------------------------------------------------------------//
    // Read new byte
    // * yield instruction based on what byte we read *
    component matcher           = SwitchArray(8, 3);
    matcher.branches          <== [Syntax.START_BRACE,  Syntax.END_BRACE,  Syntax.QUOTE,  Syntax.COLON,  Syntax.COMMA,  Syntax.START_BRACKET,  Syntax.END_BRACKET,  Syntax.NUMBER ];
    matcher.vals              <== [Command.START_BRACE, Command.END_BRACE, Command.QUOTE, Command.COLON, Command.COMMA, Command.START_BRACKET, Command.END_BRACKET, Command.NUMBER];
    component readNumber = InRange(8);
    readNumber.in    <== byte;
    readNumber.range <== [48, 57]; // ASCII NUMERALS
    signal IS_NUMBER          <==  readNumber.out * Syntax.NUMBER;
    matcher.case              <== (1 - readNumber.out) * byte + IS_NUMBER; // IF (NOT is_number) THEN byte ELSE 256
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    // Break down what was read
    // * read in a start brace `{` *
    component readStartBrace     = IsEqual();
    readStartBrace.in          <== [matcher.out[0], 1];
    // * read in a start bracket `[` *
    component readStartBracket   = IsEqual();
    readStartBracket.in        <== [matcher.out[0], 2];
    // * read in an end brace `}` *
    component readEndBrace       = IsEqual();
    readEndBrace.in            <== [matcher.out[0], -1];
    // * read in an end bracket `]` *
    component readEndBracket     = IsEqual();
    readEndBracket.in          <== [matcher.out[0], -2];
    // * read in a colon `:` *
    component readColon          = IsEqual();
    readColon.in               <== [matcher.out[0], 3];
    // * read in a comma `,` *
    component readComma          = IsEqual();
    readComma.in            <== [matcher.out[0], 4];

    component readDelimeter   = Contains(6);
    readDelimeter.in        <== matcher.out[0];
    readDelimeter.array     <== [1,-1,2,-2,3,4];

    // * get the instruction mask based on current state *
    component mask             = StateToMask(MAX_STACK_HEIGHT);
    mask.readDelimeter        <== readDelimeter.out;
    mask.readNumber           <== readNumber.out;
    mask.parsing_string       <== parsing_string;
    mask.parsing_number       <== parsing_number;

    
    // * multiply the mask array elementwise with the instruction array *
    component mulMaskAndOut    = ArrayMul(3);
    mulMaskAndOut.lhs        <== mask.out;
    mulMaskAndOut.rhs        <== matcher.out;
    // * add the masked instruction to the state to get new state *
    component addToState       = ArrayAdd(3);
    addToState.lhs           <== [0, parsing_string, parsing_number];
    addToState.rhs           <== mulMaskAndOut.out;

    // * set the new state *
    component newStack         = RewriteStack(MAX_STACK_HEIGHT);
    newStack.stack            <== stack;
    newStack.read_write_value <== addToState.out[0];
    newStack.readStartBrace   <== readStartBrace.out;
    newStack.readStartBracket <== readStartBracket.out;
    newStack.readEndBrace     <== readEndBrace.out;
    newStack.readEndBracket   <== readEndBracket.out;
    newStack.readColon        <== readColon.out;
    newStack.readComma        <== readComma.out;


    next_stack                <== newStack.next_stack;
    next_parsing_string       <== addToState.out[1];
    next_parsing_number       <== addToState.out[2];

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
    signal input readDelimeter;
    signal input readNumber;
    signal input parsing_string;
    signal input parsing_number;
    signal output out[3];
    

    // `read_write_value`can change: IF NOT `parsing_string` 
    out[0] <== (1 - parsing_string);

    // `parsing_string` can change:
    out[1] <== 1 - 2 * parsing_string;

    // // `parsing_number` can change: 
  
    // log("readNumber: ", readNumber.out);
    // component isParsingString = IsEqual();
    // isParsingString.in[0]     <== parsing_string;     
    // isParsingString.in[1]     <== 1;
    // component isParsingNumber = IsEqual();
    // isParsingNumber.in[0]     <== parsing_number;     
    // isParsingNumber.in[1]     <== 1;
    // component toParseNumber   = Switch(16);
    // // TODO: Could combine this into something that returns arrays so that we can set the mask more easily.
    // toParseNumber.branches  <== [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    // toParseNumber.vals      <== [0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,  0,  0,  0,  0,   0]; // These cases are useful to think about
    // component stateToNum      = Bits2Num(4);
    // stateToNum.in           <== [isParsingString.out, isParsingNumber.out, readNumber.out, readDelimeter.out];
    //  //                                   1                 2                   4              8
    // toParseNumber.case      <== stateToNum.out;

    // out[2] <== toParseNumber.out;
    signal parsingNumberReadDelimeter <== parsing_number * (readDelimeter); // 10 above used
    signal readNumberNotParsingNumber <== (1 - parsing_number) * readNumber; // 4 above
    signal notParsingStringAndParsingNumberReadDelimeterOrReadNumberNotParsingNumber <== (1 - parsing_string) * (parsingNumberReadDelimeter + readNumberNotParsingNumber);
    //                                    10 above ^^^^^^^^^^^^^^^^^     4 above ^^^^^^^^^^^^^^^
    signal temp <== parsing_number * (1 - readNumber) ;
    signal parsingNumberNotReadNumberNotReadDelimeter <== temp * (1-readDelimeter);
    out[2] <== notParsingStringAndParsingNumberReadDelimeterOrReadNumberNotParsingNumber + parsingNumberNotReadNumberNotReadDelimeter;
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
    signal input readStartBrace;
    signal input readStartBracket;
    signal input readEndBrace;
    signal input readEndBracket;
    signal input readColon;
    signal input readComma;

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
    // * composite signals *
    signal readEndChar         <== readEndBrace + readEndBracket;
    signal readCommaInArray    <== readComma * inArray.out;
    signal readCommaNotInArray <== readComma * (1 - inArray.out);
    //-----------------------------------------------------------------------------//

    //-----------------------------------------------------------------------------//
    // * determine whether we are pushing or popping from the stack *
    component isPush       = IsEqual();
    isPush.in            <== [readStartBrace + readStartBracket, 1];
    component isPop        = IsEqual();
    isPop.in             <== [readEndBrace + readEndBracket, 1];
    // * set an indicator array for where we are pushing to or popping from* 
    component indicator[n];
    for(var i = 0; i < n; i++) {
        // Points
        indicator[i]       = IsZero();
        indicator[i].in  <== pointer - isPop.out - readColon - readComma - i; // Note, pointer points to unallocated region!
    }
    //-----------------------------------------------------------------------------//


    signal stack_change_value[2] <== [(isPush.out + isPop.out) * read_write_value, readColon + readCommaInArray - readCommaNotInArray];
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