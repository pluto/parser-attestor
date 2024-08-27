pragma circom 2.1.9;

// All the possible request methods: https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods

template Syntax() {
    //-Delimeters---------------------------------------------------------------------------------//
    // - ASCII char `:`
    signal output COLON     <== 58;
    // - ASCII char `;`
    signal output SEMICOLON <== 59;
    // - ASCII char `,`
    signal output COMMA     <== 44;
    // - ASCII char `"`
    signal output QUOTE     <== 34;
    //-White_space--------------------------------------------------------------------------------//
    // - ASCII char: `\n`
    signal output NEWLINE   <== 10;
    // - ASCII char: ` `
    signal output SPACE     <== 32;
    //-Escape-------------------------------------------------------------------------------------//
    // - ASCII char: `\`
    signal output ESCAPE    <== 92;
}

template RequestMethod() {
    signal output GET[3]  <== [71, 69, 84];
    // signal output HEAD[4] <== [72, 69, 65, 68];
    signal output POST[4] <== [80, 79, 83, 84];
    // signal output PUT     <== 3;
    // signal output DELETE  <== 4;
    // signal output CONNECT <== 5;
    // signal output OPTIONS <== 6;
    // signal output TRACE   <== 7;
    // signal output PATCH   <== 8;
}

// NOTE: Starting at 1 to avoid a false positive with a 0.
template RequestMethodTag() {
    signal output GET  <== 1;
    // signal output HEAD <== 2;
    signal output POST <== 3;
    // signal output PUT     <== 4;
    // signal output DELETE  <== 5;
    // signal output CONNECT <== 6;
    // signal output OPTIONS <== 7;
    // signal output TRACE   <== 8;
    // signal output PATCH   <== 9;
}