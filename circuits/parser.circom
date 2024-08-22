/*
# `parser`
This module consists of the core parsing components for generating proofs of selective disclosure in JSON.

## Layout
The key ingredients of `parser` are:
 - `StateUpdate`: has as input a current state of a stack-machine parser.
    Also takes in a `byte` as input which combines with the current state
    to produce the `next_*` states.
 - `StateToMask`: Reads the current state to decide whether accept instruction tokens
    or ignore them for the current task (e.g., ignore `[` if `parsing_string == 1`).
 - `GetTopOfStack`: Helper function that yields the topmost allocated stack value
    and a pointer (index) to that value.
 - `RewriteStack`: Combines all the above data and produces the `next_stack`.

`parser` brings in many functions from the `utils` module and `language`.
The inclusion of `langauge` allows for this file to (eventually) be generic over
a grammar for different applications (e.g., HTTP, YAML, TOML, etc.).
*/

pragma circom 2.1.9;

include "utils.circom";
include "language.circom";

template StateUpdate(MAX_STACK_HEIGHT) {
    signal input byte; // TODO: Does this need to be constrained within here?

    signal input stack[MAX_STACK_HEIGHT][2]; 
    signal input parsing_string;
    signal input parsing_number;

    signal output next_stack[MAX_STACK_HEIGHT][2];
    signal output next_parsing_string;
    signal output next_parsing_number;
    
    component Syntax  = Syntax();
    component Command = Command();   

    //--------------------------------------------------------------------------------------------//
    // Break down what was read
    // * read in a start brace `{` *
    component readStartBrace     = IsEqual();
    readStartBrace.in          <== [byte, Syntax.START_BRACE];
    // * read in an end brace `}` *
    component readEndBrace       = IsEqual();
    readEndBrace.in            <== [byte, Syntax.END_BRACE];
    // * read in a start bracket `[` *
    component readStartBracket   = IsEqual();
    readStartBracket.in        <== [byte, Syntax.START_BRACKET];
    // * read in an end bracket `]` *
    component readEndBracket     = IsEqual();
    readEndBracket.in          <== [byte, Syntax.END_BRACKET];
    // * read in a colon `:` *
    component readColon          = IsEqual();
    readColon.in               <== [byte, Syntax.COLON];
    // * read in a comma `,` *
    component readComma          = IsEqual();
    readComma.in               <== [byte, Syntax.COMMA];
    // * read in some delimeter *
    signal readDelimeter       <== readStartBrace.out + readEndBrace.out + readStartBracket.out + readEndBracket.out
                                 + readColon.out + readComma.out;
    // * read in some number *
    component readNumber = InRange(8);
    readNumber.in    <== byte;
    readNumber.range <== [48, 57]; // ASCII NUMERALS
    signal isNumberSyntax          <==  readNumber.out * Syntax.NUMBER;
    //--------------------------------------------------------------------------------------------//
    // Yield instruction based on what byte we read *
    component matcher           = SwitchArray(8, 3);
    matcher.branches          <== [Syntax.START_BRACE,  Syntax.END_BRACE,  Syntax.QUOTE,  Syntax.COLON,  Syntax.COMMA,  Syntax.START_BRACKET,  Syntax.END_BRACKET,  Syntax.NUMBER ];
    matcher.vals              <== [Command.START_BRACE, Command.END_BRACE, Command.QUOTE, Command.COLON, Command.COMMA, Command.START_BRACKET, Command.END_BRACKET, Command.NUMBER];
    matcher.case              <== (1 - readNumber.out) * byte + isNumberSyntax; // IF (NOT readNumber) THEN byte ELSE Syntax.NUMBER
    //--------------------------------------------------------------------------------------------//
    // Apply state changing data
    // * get the instruction mask based on current state *
    component mask              = StateToMask(MAX_STACK_HEIGHT);
    mask.readDelimeter        <== readDelimeter;
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
    // * compute the new stack *
    component newStack         = RewriteStack(MAX_STACK_HEIGHT);
    newStack.stack            <== stack;
    newStack.read_write_value <== addToState.out[0];
    newStack.readStartBrace   <== readStartBrace.out;
    newStack.readStartBracket <== readStartBracket.out;
    newStack.readEndBrace     <== readEndBrace.out;
    newStack.readEndBracket   <== readEndBracket.out;
    newStack.readColon        <== readColon.out;
    newStack.readComma        <== readComma.out;
    // * set all the next state of the parser * 
    next_stack                <== newStack.next_stack;
    next_parsing_string       <== addToState.out[1];
    next_parsing_number       <== addToState.out[2];
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


    //--------------------------------------------------------------------------------------------//
    // `parsing_number` is more complicated to deal with
    /* We have the possible relevant states below:
    [isParsingString, isParsingNumber, readNumber, readDelimeter];
             1                2             4             8
    Above is the binary value for each if is individually enabled
    This is a total of 2^4 states
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    [0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,  0,  0,  0,  0,   0]; 
    and the above is what we want to set `next_parsing_number` to given those 
    possible.
    Below is an optimized version that could instead be done with a `Switch`
    */
    signal parsingNumberReadDelimeter <== parsing_number * (readDelimeter); 
    signal readNumberNotParsingNumber <== (1 - parsing_number) * readNumber;
    signal notParsingStringAndParsingNumberReadDelimeterOrReadNumberNotParsingNumber <== (1 - parsing_string) * (parsingNumberReadDelimeter + readNumberNotParsingNumber);
    //                                                                                                           10 above ^^^^^^^^^^^^^^^^^   4 above ^^^^^^^^^^^^^^^^^^
    signal temp <== parsing_number * (1 - readNumber) ;
    signal parsingNumberNotReadNumberNotReadDelimeter <== temp * (1-readDelimeter);
    out[2] <== notParsingStringAndParsingNumberReadDelimeterOrReadNumberNotParsingNumber + parsingNumberNotReadNumberNotReadDelimeter;
    // Sorry about the long names, but they hopefully read clearly!
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

// TODO: IMPORTANT NOTE, THE STACK IS CONSTRAINED TO 2**8 so the InRange work (could be changed)
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
    
    //--------------------------------------------------------------------------------------------//
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
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    // * composite signals *
    signal readEndChar         <== readEndBrace + readEndBracket;
    signal readCommaInArray    <== readComma * inArray.out;
    signal readCommaNotInArray <== readComma * (1 - inArray.out);
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
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
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    // * loop to modify the stack by rebuilding it *
    signal stack_change_value[2] <== [(isPush.out + isPop.out) * read_write_value, readColon + readCommaInArray - readCommaNotInArray];
    signal second_index_clear[n];
    for(var i = 0; i < n; i++) {
        next_stack[i][0]         <== stack[i][0] + indicator[i].out * stack_change_value[0];
        second_index_clear[i]    <== stack[i][1] * readEndChar;
        next_stack[i][1]         <== stack[i][1] + indicator[i].out * (stack_change_value[1] - second_index_clear[i]);
    }
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    // * check for under or overflow
    component isUnderflowOrOverflow = InRange(8);
    isUnderflowOrOverflow.in     <== pointer - isPop.out + isPush.out;
    isUnderflowOrOverflow.range  <== [0,n];
    isUnderflowOrOverflow.out    === 1;
    //--------------------------------------------------------------------------------------------//
}