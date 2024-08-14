pragma circom 2.1.9;

template Syntax() {
    //-Delimeters---------------------------------------------------------------------------------//
    // - ASCII char: `{`
    signal output START_BRACE   <== 123;
    // - ASCII char: `}`
    signal output END_BRACE     <== 125;
    // - ASCII char `[`
    signal output START_BRACKET <== 91;
    // - ASCII char `]`
    signal output END_BRACKET   <== 93;
    // - ASCII char `"`
    signal output QUOTE         <== 34;
    // - ASCII char `:`
    signal output COLON         <== 58;
    // - ASCII char `,`
    signal output COMMA         <== 44;
    //-White_space--------------------------------------------------------------------------------//
    // - ASCII char: `\n`
    signal output NEWLINE       <== 10;
    // - ASCII char: ` `
    signal output SPACE         <== 32;
    //-Escape-------------------------------------------------------------------------------------//
    // - ASCII char: `\`
    signal output ESCAPE        <== 92;
    //-Number_Remapping---------------------------------------------------------------------------//
    signal output NUMBER        <== 256; // past a u8 -- reserved for ANY numerical ASCII (48 - 57)
}

template Command() {
    //            STATE              = [pushpop, stack_val, parsing_string, parsing_number]
    signal output NOTHING[4]       <== [0,       0,         0,              -1            ]; // Command returned by switch if we want to do nothing, e.g. read a whitespace char while looking for a key
    signal output START_BRACE[4]   <== [1,       1,         0,              0             ]; // Command returned by switch if we hit a start brace `{`
    signal output END_BRACE[4]     <== [-1,      1,         0,              -1            ]; // Command returned by switch if we hit a end brace `}`
    signal output START_BRACKET[4] <== [1,       2,         0,              0             ]; // TODO: Might want `in_value` to toggle. Command returned by switch if we hit a start bracket `[` (TODO: could likely be combined with end bracket)
    signal output END_BRACKET[4]   <== [-1,      2,         0,              -1            ]; // Command returned by switch if we hit a start bracket `]` 
    signal output QUOTE[4]         <== [0,       0,         1,              0             ]; // TODO: Mightn ot want this to toglle `parsing_array`. Command returned by switch if we hit a quote `"`
    signal output COLON[4]         <== [1,       3,         0,              0             ]; // Command returned by switch if we hit a colon `:`
    signal output COMMA[4]         <== [-1,      4,         0,              -1            ]; // Command returned by switch if we hit a comma `,`
    signal output NUMBER[4]        <== [0,       256,         0,              1             ]; // Command returned by switch if we hit some decimal number (e.g., ASCII 48-57)
}