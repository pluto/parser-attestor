import { circomkit, WitnessTester, generateDescription } from "../common";
import { Delimiters, WhiteSpace, Numbers, Escape, INITIAL_IN, INITIAL_OUT } from '.';

describe("GetTopOfStack", () => {
    let circuit: WitnessTester<["stack", "pointer"], ["out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`GetTopOfStack`, {
            file: "circuits/parser",
            template: "GetTopOfStack",
            params: [4],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    it("witness: pointer = 4, stack = [[1,0], [2,0], [3,1], [4,2]]", async () => {
        await circuit.expectPass(
            { pointer: 4, stack: [[1, 0], [2, 0], [3, 1], [4, 2]] },
            { out: [4, 2] },
        );
    });
});

describe("StateUpdate :: RewriteStack", () => {
    let circuit: WitnessTester<
        ["byte", "pointer", "stack", "parsing_string", "parsing_number"],
        ["next_pointer", "next_stack", "next_parsing_string", "next_parsing_number"]
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
    // state:  pointer == 1, stack == [1,0,0,0]
    // read:   `{`
    // expect: pointer --> 2
    //         stack   --> [1,1,0,0]
    let in_object = { ...INITIAL_IN };
    in_object.pointer = 1;
    in_object.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    in_object.byte = Delimiters.START_BRACE;
    let in_object_out = { ...INITIAL_OUT };
    in_object_out.next_pointer = 2;
    in_object_out.next_stack = [[1, 0], [1, 0], [0, 0], [0, 0]];
    generatePassCase(in_object, in_object_out, ">>>> `{` read");

    //-TEST_2----------------------------------------------------------//
    // state:  pointer == 1, stack == [1,0,0,0]
    // read:   `}`
    // expect: pointer --> 0
    //         stack   --> [0,0,0,0]
    let in_object_to_leave = { ...INITIAL_IN };
    in_object_to_leave.pointer = 1;
    in_object_to_leave.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    in_object_to_leave.byte = Delimiters.END_BRACE;
    let in_object_to_leave_out = { ...INITIAL_OUT };
    generatePassCase(in_object_to_leave,
        in_object_to_leave_out,
        ">>>> `}` read"
    );

    //-TEST_3----------------------------------------------------------//
    // init: read `{`, then read `[`
    // expect: pointer --> 2
    //         stack   --> [1,2,0,0]
    let in_object_to_read_start_bracket = { ...INITIAL_IN };
    in_object_to_read_start_bracket.byte = Delimiters.START_BRACKET;
    in_object_to_read_start_bracket.pointer = 1;
    in_object_to_read_start_bracket.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    let in_object_to_read_start_bracket_out = { ...INITIAL_OUT };
    in_object_to_read_start_bracket_out.next_pointer = 2;
    in_object_to_read_start_bracket_out.next_stack = [[1, 0], [2, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_to_read_start_bracket,
        in_object_to_read_start_bracket_out,
        ">>>> `[` read"
    );

    //-TEST_4----------------------------------------------------------//
    // init: read 4x `{`, then read `{`
    // expect: pointer --> 4
    //         stack   --> [1,1,1,1]
    let in_max_stack = { ...INITIAL_IN };
    in_max_stack.byte = Delimiters.START_BRACE;
    in_max_stack.pointer = 4;
    in_max_stack.stack = [[1, 0], [1, 0], [1, 0], [1, 0]];
    generateFailCase(in_max_stack, ">>>> `{` read --> (stack overflow)");

    //-TEST_5----------------------------------------------------------//
    // init: read 4x `{`, then read `[`
    // expect: pointer --> 4
    //         stack   --> [1,1,1,1]
    let in_max_stack_2 = { ...INITIAL_IN };
    in_max_stack_2.byte = Delimiters.START_BRACKET;
    in_max_stack_2.pointer = 4;
    in_max_stack_2.stack = [[1, 0], [1, 0], [1, 0], [1, 0]];
    generateFailCase(in_max_stack, ">>>> `[` read --> (stack overflow)");

    //-TEST_6----------------------------------------------------------//
    // init: read `{` and `[`, then read `]`
    // expect: pointer --> 2
    //         stack   --> [1,0,0,0]
    let in_object_and_array = { ...INITIAL_IN };
    in_object_and_array.byte = Delimiters.END_BRACKET;
    in_object_and_array.pointer = 2;
    in_object_and_array.stack = [[1, 0], [2, 0], [0, 0], [0, 0]];
    let in_object_and_array_out = { ...INITIAL_OUT };
    in_object_and_array_out.next_pointer = 1;
    in_object_and_array_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_and_array,
        in_object_and_array_out,
        ">>>> `]` read"
    );

    //-TEST_7----------------------------------------------------------//
    // init: read `{` and `:`, then read `,`
    // expect: pointer --> 2
    //         stack   --> [1,3,0,0]
    let in_object_and_value = { ...INITIAL_IN };
    in_object_and_value.byte = Delimiters.COMMA;
    in_object_and_value.pointer = 2;
    in_object_and_value.stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    let in_object_and_value_out = { ...INITIAL_OUT };
    in_object_and_value_out.next_pointer = 1;
    in_object_and_value_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_and_value,
        in_object_and_value_out,
        ">>>> `,` read"
    );

    //-TEST_8----------------------------------------------------------//
    // init:   pointer == 2, stack == [1,3,0,0]
    // read:   `}`
    // expect: pointer --> 2
    //         stack   --> [1,3,0,0]
    let in_object_and_value_to_leave_object = { ...INITIAL_IN };
    in_object_and_value_to_leave_object.byte = Delimiters.END_BRACE;
    in_object_and_value_to_leave_object.pointer = 2;
    in_object_and_value_to_leave_object.stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    let in_object_and_value_to_leave_object_out = { ...INITIAL_OUT };
    in_object_and_value_to_leave_object_out.next_pointer = 0;
    in_object_and_value_to_leave_object_out.next_stack = [[0, 0], [0, 0], [0, 0], [0, 0]];
    generatePassCase(in_object_and_value_to_leave_object,
        in_object_and_value_to_leave_object_out,
        ">>>> `}` read"
    );

    //-TEST_9----------------------------------------------------------//
    // init: pointer = 1, stack = [1,2,0,0] -> `,` is read
    let inside_array = { ...INITIAL_IN };
    inside_array.pointer = 2;
    inside_array.stack = [[1, 0], [2, 0], [0, 0], [0, 0]];
    inside_array.byte = Delimiters.COMMA;
    let inside_array_out = { ...INITIAL_OUT };
    inside_array_out.next_pointer = 2;
    inside_array_out.next_stack = [[1, 0], [2, 0], [0, 0], [0, 0]];
    generatePassCase(inside_array, inside_array_out, ">>>> `,` read");

    //-TEST_10----------------------------------------------------------//
    // state:  pointer == 1, stack == [1,0,0,0] 
    // read:   `:`
    // expect: pointer --> 2
    //         stack   --> [1,3,0,0]
    let parsed_key_wait_to_parse_value = { ...INITIAL_IN };
    parsed_key_wait_to_parse_value.pointer = 1;
    parsed_key_wait_to_parse_value.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    parsed_key_wait_to_parse_value.byte = Delimiters.COLON;
    let parsed_key_wait_to_parse_value_out = { ...INITIAL_OUT };
    parsed_key_wait_to_parse_value_out.next_pointer = 2;
    parsed_key_wait_to_parse_value_out.next_stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    generatePassCase(parsed_key_wait_to_parse_value,
        parsed_key_wait_to_parse_value_out,
        ">>>> `:` read"
    );

});