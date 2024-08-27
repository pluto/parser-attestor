// All the possible request methods: https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods

template Syntax() {
    //-Delimeters---------------------------------------------------------------------------------//
    // - ASCII char `:`
    signal output COLON         <== 58;
    // - ASCII char `;`
    signal output SEMICOLON     <== 59;
    // - ASCII char `,`
    signal output COMMA         <== 44;
    // - ASCII char `"`
    signal output QUOTE         <== 34;
    //-White_space--------------------------------------------------------------------------------//
    // - ASCII char: `\n`
    signal output NEWLINE       <== 10;
    // - ASCII char: ` `
    signal output SPACE         <== 32;
    //-Escape-------------------------------------------------------------------------------------//
    // - ASCII char: `\`
    signal output ESCAPE        <== 92;
}