import { circomkit, WitnessTester, generateDescription } from "../common";
import { Delimiters, WhiteSpace, Numbers, Escape, INITIAL_IN, INITIAL_OUT } from '.';



describe("StateUpdate", () => {
    let circuit: WitnessTester<
        ["byte", "pointer", "stack", "parsing_string", "parsing_number"],
        ["next_pointer", "next_stack", "next_parsing_string", "next_parsing_number"]
    >;

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

    before(async () => {
        circuit = await circomkit.WitnessTester(`StateUpdate`, {
            file: "circuits/parser",
            template: "StateUpdate",
            params: [4],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

    });

    //    //-TEST_1----------------------------------------------------------//
    //     // init: ZEROS then read `do_nothing` byte
    //     // expect: ZEROS
    //     generatePassCase(INITIAL_IN, INITIAL_OUT, ">>>> `NUL` read");

    //     // TODO: Consider moving to `stack.test.ts`
    //     //-TEST_2----------------------------------------------------------//
    //     // init:   INIT
    //     // read:   `{`
    //     // expect: pointer --> 1
    //     //         stack   --> [1,0,0,0]
    //     let read_start_brace = { ...INITIAL_IN };
    //     read_start_brace.byte = Delimiters.START_BRACE;
    //     let read_start_brace_out = { ...INITIAL_OUT };
    //     read_start_brace_out.next_pointer = 1;
    //     read_start_brace_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    //     generatePassCase(read_start_brace,
    //         read_start_brace_out,
    //         ">>>> `{` read"
    //     );

    //     //-TEST_3----------------------------------------------------------//
    //     // state:  INIT
    //     // read:   `}`
    //     // expect: FAIL (stack underflow)
    //     let read_end_brace = { ...INITIAL_IN };
    //     read_end_brace.byte = Delimiters.END_BRACE;
    //     generateFailCase(read_end_brace,
    //         ">>>> `}` read --> (stack underflow)"
    //     );

    //     //-TEST_4----------------------------------------------------------//
    //     // state:  pointer == 1, stack == [1,0,0,0] 
    //     // read:   `"`
    //     // expect: parsing_string --> 1
    //     let in_object_find_key = { ...INITIAL_IN };
    //     in_object_find_key.pointer = 1;
    //     in_object_find_key.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    //     in_object_find_key.byte = Delimiters.QUOTE;
    //     let in_object_find_key_out = { ...INITIAL_OUT };
    //     in_object_find_key_out.next_pointer = 1;
    //     in_object_find_key_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    //     in_object_find_key_out.next_parsing_string = 1;
    //     generatePassCase(in_object_find_key,
    //         in_object_find_key_out,
    //         ">>>> `\"` read"
    //     );

    //     //-TEST_5----------------------------------------------------------//
    //     // state:  pointer == 1, stack = [1,0,0,0], parsing_string == 1
    //     // read:   ` `
    //     // expect: NIL
    //     let in_key = { ...INITIAL_IN };
    //     in_key.pointer = 1;
    //     in_key.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    //     in_key.parsing_string = 1;
    //     in_key.byte = WhiteSpace.SPACE;
    //     let in_key_out = { ...INITIAL_OUT };
    //     in_key_out.next_pointer = 1;
    //     in_key_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    //     in_key_out.next_parsing_string = 1;
    //     generatePassCase(in_key, in_key_out, ">>>> ` ` read");

    //     //-TEST_6----------------------------------------------------------//
    //     // init: pointer == 1, stack == [1,0,0,0]
    //     // read: `"`
    //     // expect: parsing_string --> 0
    //     //         
    //     let in_key_to_exit = { ...INITIAL_IN };
    //     in_key_to_exit.pointer = 1;
    //     in_key_to_exit.stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    //     in_key_to_exit.parsing_string = 1
    //     in_key_to_exit.byte = Delimiters.QUOTE;
    //     let in_key_to_exit_out = { ...INITIAL_OUT };
    //     in_key_to_exit_out.next_pointer = 1;
    //     in_key_to_exit_out.next_stack = [[1, 0], [0, 0], [0, 0], [0, 0]];
    //     generatePassCase(in_key_to_exit, in_key_to_exit_out, "`\"` read");

    //     //-TEST_7----------------------------------------------------------//
    //     // state:  pointer == 2, stack == [1,3,0,0]
    //     // read:   `"`
    //     // expect: parsing_string --> 1
    //     let in_tree_find_value = { ...INITIAL_IN };
    //     in_tree_find_value.pointer = 1;
    //     in_tree_find_value.stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    //     in_tree_find_value.byte = Delimiters.QUOTE;
    //     let in_tree_find_value_out = { ...INITIAL_OUT };
    //     in_tree_find_value_out.next_pointer = 1;
    //     in_tree_find_value_out.next_stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    //     in_tree_find_value_out.next_parsing_string = 1;
    //     generatePassCase(in_tree_find_value,
    //         in_tree_find_value_out,
    //         ">>>> `\"` read"
    //     );

    //     //-TEST_8----------------------------------------------------------//
    //     // state:  pointer == 2, stack == [1,3,0,0], parsing_string == 1
    //     // read:   `"`
    //     // expect: parsing_string == 0,
    //     let in_value_to_exit = { ...INITIAL_IN };
    //     in_value_to_exit.pointer = 2;
    //     in_value_to_exit.stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    //     in_value_to_exit.parsing_string = 1;
    //     in_value_to_exit.byte = Delimiters.QUOTE;
    //     let in_value_to_exit_out = { ...INITIAL_OUT };
    //     in_value_to_exit_out.next_pointer = 2;
    //     in_value_to_exit_out.next_stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    //     generatePassCase(in_value_to_exit,
    //         in_value_to_exit_out,
    //         ">>>> `\"` is read"
    //     );

});



