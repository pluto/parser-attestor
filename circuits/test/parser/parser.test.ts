import { circomkit, WitnessTester } from "../common";
import { Delimiters, WhiteSpace, Numbers, Escape, INITIAL_IN, INITIAL_OUT } from '.';



describe("StateUpdate", () => {
    let circuit: WitnessTester<
        ["byte", "pointer", "stack", "parsing_string", "parsing_number"],
        ["next_pointer", "next_stack", "next_parsing_string", "next_parsing_number"]
    >;

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = Object.entries(input)
            .map(([key, value]) => `${key} = ${value}`)
            .join(", ");

        it(`(valid) witness: ${description}\n${desc}`, async () => {
            await circuit.expectPass(input, expected);
        });
    }

    function generateFailCase(input: any, desc: string) {
        const description = Object.entries(input)
            .map(([key, value]) => `${key} = ${value}`)
            .join(", ");

        it(`(invalid) witness: ${description}\n${desc}`, async () => {
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

    //-TEST_1----------------------------------------------------------//
    // init: ZEROS then read `do_nothing` byte
    // expect: ZEROS
    generatePassCase(INITIAL_IN, INITIAL_OUT, ">>>> `NUL` read");

    // TODO: Consider moving to `stack.test.ts`
    //-TEST_2----------------------------------------------------------//
    // init:   INIT
    // read:   `{`
    // expect: pointer --> 1
    //         stack   --> [1,0,0,0]
    let read_start_brace = { ...INITIAL_IN };
    read_start_brace.byte = Delimiters.START_BRACE;
    let read_start_brace_out = { ...INITIAL_OUT };
    read_start_brace_out.next_pointer = 1;
    read_start_brace_out.next_stack = [1, 0, 0, 0];
    generatePassCase(read_start_brace, read_start_brace_out, ">>>> `{` read");

    //-TEST_3----------------------------------------------------------//
    // state:  INIT
    // read:   `}`
    // expect: FAIL (stack underflow)
    let read_end_brace = { ...INITIAL_IN };
    read_end_brace.byte = Delimiters.END_BRACE;
    generateFailCase(read_end_brace, ">>>> `}` read --> (stack underflow)");

    //-TEST_4----------------------------------------------------------//
    // state:  pointer == 1, stack == [1,0,0,0] 
    // read:   `"`
    // expect: parsing_string --> 1
    let in_object_find_key = { ...INITIAL_IN };
    in_object_find_key.pointer = 1;
    in_object_find_key.stack = [1, 0, 0, 0];
    in_object_find_key.byte = Delimiters.QUOTE;
    let in_object_find_key_out = { ...INITIAL_OUT };
    in_object_find_key_out.next_pointer = 1;
    in_object_find_key_out.next_stack = [1, 0, 0, 0];
    in_object_find_key_out.next_parsing_string = 1;
    generatePassCase(in_object_find_key, in_object_find_key_out, ">>>> `\"` read");

    //-TEST_5----------------------------------------------------------//
    // state:  pointer == 1, stack = [1,0,0,0], parsing_string == 1
    // read:   ` `
    // expect: NIL
    let in_key = { ...INITIAL_IN };
    in_key.pointer = 1;
    in_key.stack = [1, 0, 0, 0];
    in_key.parsing_string = 1;
    in_key.byte = WhiteSpace.SPACE;
    let in_key_out = { ...INITIAL_OUT };
    in_key_out.next_pointer = 1;
    in_key_out.next_stack = [1, 0, 0, 0];
    in_key_out.next_parsing_string = 1;
    generatePassCase(in_key, in_key_out, ">>>> ` ` read");

    //-TEST_6----------------------------------------------------------//
    // init: pointer == 1, stack == [1,0,0,0]
    // read: `"`
    // expect: parsing_string --> 0
    //         
    let in_key_to_exit = { ...INITIAL_IN };
    in_key_to_exit.pointer = 1;
    in_key_to_exit.stack = [1, 0, 0, 0];
    in_key_to_exit.parsing_string = 1
    in_key_to_exit.byte = Delimiters.QUOTE;
    let in_key_to_exit_out = { ...INITIAL_OUT };
    in_key_to_exit_out.next_pointer = 1;
    in_key_to_exit_out.next_stack = [1, 0, 0, 0];
    generatePassCase(in_key_to_exit, in_key_to_exit_out, "`\"` read");

    //-TEST_7----------------------------------------------------------//
    // state:  pointer == 2, stack == [1,3,0,0]
    // read:   `"`
    // expect: parsing_string --> 1
    let in_tree_find_value = { ...INITIAL_IN };
    in_tree_find_value.pointer = 1;
    in_tree_find_value.stack = [1, 3, 0, 0];
    in_tree_find_value.byte = Delimiters.QUOTE;
    let in_tree_find_value_out = { ...INITIAL_OUT };
    in_tree_find_value_out.next_pointer = 1;
    in_tree_find_value_out.next_stack = [1, 3, 0, 0];
    in_tree_find_value_out.next_parsing_string = 1;
    generatePassCase(in_tree_find_value, in_tree_find_value_out, ">>>> `\"` read");

    //-TEST_8----------------------------------------------------------//
    // state:  pointer == 2, stack == [1,3,0,0], parsing_string == 1
    // read:   `"`
    // expect: parsing_string == 0,
    let in_value_to_exit = { ...INITIAL_IN };
    in_value_to_exit.pointer = 2;
    in_value_to_exit.stack = [1, 3, 0, 0];
    in_value_to_exit.parsing_string = 1;
    in_value_to_exit.byte = Delimiters.QUOTE;
    let in_value_to_exit_out = { ...INITIAL_OUT };
    in_value_to_exit_out.next_pointer = 2;
    in_value_to_exit_out.next_stack = [1, 3, 0, 0];
    generatePassCase(in_value_to_exit, in_value_to_exit_out, ">>>> `\"` is read");

    // // Test 11: `tree_depth == 1` AND end_of_kv` setup -> ` ` is read
    // let in_end_of_kv = { ...init };
    // in_end_of_kv.tree_depth = 1;
    // in_end_of_kv.byte = space;
    // let in_end_of_kv_out = { ...out };
    // in_end_of_kv_out.next_tree_depth = 1;
    // generatePassCase(in_end_of_kv, in_end_of_kv_out, ">>>> ` ` is read");

    // // Test 12: `tree_depth == 1` AND end_of_kv` setup ->  `,` is read
    // let end_of_kv_to_parse_to_key = { ...init };
    // end_of_kv_to_parse_to_key.tree_depth = 1;
    // end_of_kv_to_parse_to_key.parsing_value = 1;
    // // end_of_kv_to_parse_to_key.end_of_kv = 1;
    // end_of_kv_to_parse_to_key.byte = comma;
    // let end_of_kv_to_parse_to_key_out = { ...out };
    // end_of_kv_to_parse_to_key_out.next_tree_depth = 1;
    // end_of_kv_to_parse_to_key_out.next_parsing_key = 1;
    // generatePassCase(end_of_kv_to_parse_to_key, end_of_kv_to_parse_to_key_out, ">>>> ` ` is read");

    // // Test 13: `tree_depth == 1` AND end_of_kv` setup ->  `}` is read
    // let end_of_kv_to_exit_json = { ...init };
    // end_of_kv_to_exit_json.tree_depth = 1;
    // end_of_kv_to_exit_json.parsing_value = 1;
    // end_of_kv_to_exit_json.byte = end_brace;
    // let end_of_kv_to_exit_json_out = { ...out };
    // end_of_kv_to_exit_json_out.next_parsing_value = 1;
    // generatePassCase(end_of_kv_to_exit_json, end_of_kv_to_exit_json_out, ">>>> `}` is read");

    // // NOTE: At this point, we can parse JSON that has 2 keys at depth 1!

    // // Test 14: `tree_depth == 1` AND parsing_value` setup ->  `{` is read
    // let end_of_key_to_inner_object = { ...init };
    // end_of_key_to_inner_object.tree_depth = 1;
    // end_of_key_to_inner_object.parsing_value = 1;
    // end_of_key_to_inner_object.byte = start_brace;
    // let end_of_key_to_inner_object_out = { ...out };
    // end_of_key_to_inner_object_out.next_tree_depth = 2;
    // end_of_key_to_inner_object_out.next_parsing_key = 1;
    // generatePassCase(end_of_key_to_inner_object, end_of_key_to_inner_object_out, ">>>> `{` is read");

});


