import { circomkit, WitnessTester, generateDescription } from "../common";
import { Delimiters, WhiteSpace, Numbers, Escape, INITIAL_IN, INITIAL_OUT } from '.';

describe("GetTopOfStack", () => {
    let circuit: WitnessTester<["stack"], ["value", "pointer"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`GetTopOfStack`, {
            file: "circuits/parser",
            template: "GetTopOfStack",
            params: [4],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    function generatePassCase(input: any, expected: any) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description}`, async () => {
            await circuit.expectPass(input, expected);
        });
    }

    let input = { stack: [[1, 0], [2, 0], [3, 1], [4, 2]] };
    let output = { value: [4, 2], pointer: 3 };
    generatePassCase(input, output);

    input.stack[2] = [0, 0];
    input.stack[3] = [0, 0];
    output.value = [2, 0]
    output.pointer = 1;
    generatePassCase(input, output);

    input.stack[0] = [0, 0];
    input.stack[1] = [0, 0];
    output.value = [0, 0]
    output.pointer = 0;
    generatePassCase(input, output);
});

describe("StateUpdate :: RewriteStack", () => {
    let circuit: WitnessTester<
        ["byte", "stack", "parsing_string", "parsing_number"],
        ["next_stack", "next_parsing_string", "next_parsing_number"]
    >;
    before(async () => {
        circuit = await circomkit.WitnessTester(`GetTopOfStack`, {
            file: "circuits/parser",
            template: "StateUpdate",
            params: [4],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description}\n${desc}`, async () => {
            await circuit.expectPass(input, expected);
        });
    }

    function generateFailCase(input: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description}\n${desc}`, async () => {
            await circuit.expectFail(input);
        });
    }

    //-TEST_1----------------------------------------------------------//
    // init:   stack  == [[0, 0], [0, 0], [0, 0], [0, 0]]
    // read:   `{`
    // expect: stack --> [[1, 0], [0, 0], [0, 0], [0, 0]]
    let read_start_brace = { ...INITIAL_IN };
    read_start_brace.byte = Delimiters.START_BRACE;
    let read_start_brace_out = { ...INITIAL_OUT };
    read_start_brace_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    generatePassCase(read_start_brace,
        read_start_brace_out,
        ">>>> `{` read"
    );

    //-TEST_2----------------------------------------------------------//
    // state:  stack ==  [[1, 0], [0, 0], [0, 0], [0, 0]]
    // read:   `{`
    // expect: stack --> [[1, 0], [1, 0], [0, 0], [0, 0]]
    let in_object = { ...INITIAL_IN };
    in_object.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    in_object.byte = Delimiters.START_BRACE;
    let in_object_out = { ...INITIAL_OUT };
    in_object_out.next_stack = [[1, 0], [1, 0], [0, 0], [0, 0]];
    generatePassCase(in_object, in_object_out, ">>>> `{` read");

    //-TEST_3----------------------------------------------------------//
    // state:  stack  == [[1, 0], [0, 0], [0, 0], [0, 0]]
    // read:   `}`
    // expect: stack --> [[0, 0], [0, 0], [0, 0], [0, 0]]
    let in_object_to_leave = { ...INITIAL_IN };
    in_object_to_leave.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    in_object_to_leave.byte = Delimiters.END_BRACE;
    let in_object_to_leave_out = { ...INITIAL_OUT };
    generatePassCase(in_object_to_leave,
        in_object_to_leave_out,
        ">>>> `}` read"
    );

    //-TEST_4----------------------------------------------------------//
    // init:   stack  == [[1, 0], [0, 0], [0, 0], [0, 0]]
    // read:   `[`
    // expect: stack --> [[1, 0], [2, 0], [0, 0], [0, 0]]
    let in_object_to_read_start_bracket = { ...INITIAL_IN };
    in_object_to_read_start_bracket.byte = Delimiters.START_BRACKET;
    in_object_to_read_start_bracket.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    let in_object_to_read_start_bracket_out = { ...INITIAL_OUT };
    in_object_to_read_start_bracket_out.next_stack = [[1, 0], [2, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_to_read_start_bracket,
        in_object_to_read_start_bracket_out,
        ">>>> `[` read"
    );

    //-TEST_5----------------------------------------------------------//
    // init:   stack  == [[1, 0], [2, 0], [0, 0], [0, 0]]
    // read:   `]`
    // expect: stack --> [[1, 0], [0, 0], [0, 0], [0, 0]]
    let in_object_and_array = { ...INITIAL_IN };
    in_object_and_array.byte = Delimiters.END_BRACKET;
    in_object_and_array.stack = [[1, 0], [2, 0], [0, 0], [0, 0]];
    let in_object_and_array_out = { ...INITIAL_OUT };
    in_object_and_array_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_and_array,
        in_object_and_array_out,
        ">>>> `]` read"
    );

    //-TEST_6-----------------------------------------------------------//
    // state:  stack  == [[1, 0], [0, 0], [0, 0], [0, 0]]
    // read:   `:`
    // expect: stack --> [[1, 1], [0, 0], [0, 0], [0, 0]]
    let parsed_key_wait_to_parse_value = { ...INITIAL_IN };
    parsed_key_wait_to_parse_value.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    parsed_key_wait_to_parse_value.byte = Delimiters.COLON;
    let parsed_key_wait_to_parse_value_out = { ...INITIAL_OUT };
    parsed_key_wait_to_parse_value_out.next_stack = [[1, 1], [0, 0], [0, 0], [0, 0]];
    generatePassCase(parsed_key_wait_to_parse_value,
        parsed_key_wait_to_parse_value_out,
        ">>>> `:` read"
    );

    //-TEST_7----------------------------------------------------------//
    // init:   stack  == [[1, 0], [0, 0], [0, 0], [0, 0]]
    // expect: stack --> [[1, 0], [0, 0], [0, 0], [0, 0]]
    let in_object_and_value = { ...INITIAL_IN };
    in_object_and_value.byte = Delimiters.COMMA;
    in_object_and_value.stack = [[1, 1], [0, 0], [0, 0], [0, 0]];
    let in_object_and_value_out = { ...INITIAL_OUT };
    in_object_and_value_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_and_value,
        in_object_and_value_out,
        ">>>> `,` read"
    );

    //-TEST_8----------------------------------------------------------//
    // init:   stack  == [[1, 1], [0, 0], [0, 0], [0, 0]]
    // read:   `}`
    // expect: stack --> [[0, 0], [0, 0], [0, 0], [0, 0]]
    let in_object_and_value_to_leave_object = { ...INITIAL_IN };
    in_object_and_value_to_leave_object.byte = Delimiters.END_BRACE;
    in_object_and_value_to_leave_object.stack = [[1, 1], [0, 0], [0, 0], [0, 0]];
    let in_object_and_value_to_leave_object_out = { ...INITIAL_OUT };
    in_object_and_value_to_leave_object_out.next_stack = [[0, 0], [0, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_and_value_to_leave_object,
        in_object_and_value_to_leave_object_out,
        ">>>> `}` read"
    );


    // TODO: FAIL CASES, ADD STACK UNDERFLOW CASES TOO
    // //-TEST_4----------------------------------------------------------//
    // // init:   stack == [[1, 0], [1, 0], [1, 0], [1, 0]]
    // // expect: FAIL, STACK OVERFLOW
    // let in_max_stack = { ...INITIAL_IN };
    // in_max_stack.byte = Delimiters.START_BRACE;
    // in_max_stack.stack = [[1, 0], [1, 0], [1, 0], [1, 0]];
    // generateFailCase(in_max_stack, ">>>> `{` read --> (stack overflow)");

    // //-TEST_5----------------------------------------------------------//
    // // init:   stack  == [[1, 0], [1, 0], [1, 0], [1, 0]]
    // // expect: FAIL, STACK OVERFLOW
    // let in_max_stack_2 = { ...INITIAL_IN };
    // in_max_stack_2.byte = Delimiters.START_BRACKET;
    // in_max_stack_2.stack = [[1, 0], [1, 0], [1, 0], [1, 0]];
    // generateFailCase(in_max_stack, ">>>> `[` read --> (stack overflow)");

    // //-TEST_3----------------------------------------------------------//
    // // init:   stack == [1,0,0,0]
    // // read:   `]`
    // // expect: FAIL, INVALID CHAR
    // let in_object_to_read_start_bracket = { ...INITIAL_IN };
    // in_object_to_read_start_bracket.byte = Delimiters.START_BRACKET;
    // in_object_to_read_start_bracket.pointer = 1;
    // in_object_to_read_start_bracket.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    // let in_object_to_read_start_bracket_out = { ...INITIAL_OUT };
    // in_object_to_read_start_bracket_out.next_pointer = 2;
    // in_object_to_read_start_bracket_out.next_stack = [[1, 0], [2, 0], [0, 0], [0, 0]];
    // generatePassCase(in_object_to_read_start_bracket,
    //     in_object_to_read_start_bracket_out,
    //     ">>>> `[` read"
    // );
});