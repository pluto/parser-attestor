import { start } from "repl";
import { circomkit, WitnessTester } from "./common";

describe("parser", () => {
    describe("Switch", () => {
        let circuit: WitnessTester<["case", "branches", "vals"], ["match", "out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`Switch`, {
                file: "circuits/parser",
                template: "Switch",
                params: [3, 2],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: case = 0, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 0, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 1, out: [69, 0] },
            );
        });

        it("witness: case = 1, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 1, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 1, out: [420, 1] },
            );
        });

        it("witness: case = 2, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 2, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 1, out: [1337, 2] },
            );
        });

        it("witness: case = 3, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 3, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 0, out: [0, 0] }
            );
        });

        it("witness: case = 420, branches = [69, 420, 1337], vals = [[10,3], [20,5], [30,7]]", async () => {
            await circuit.expectPass(
                { case: 420, branches: [69, 420, 1337], vals: [[10, 3], [20, 5], [30, 7]] },
                { match: 1, out: [20, 5] }
            );
        });

        it("witness: case = 0, branches = [69, 420, 1337], vals = [[10,3], [20,5], [30,7]]", async () => {
            await circuit.expectPass(
                { case: 0, branches: [69, 420, 1337], vals: [[10, 3], [20, 5], [30, 7]] },
                { match: 0, out: [0, 0] }
            );
        });

    });

    //--------------------------------------------------------------------------------------------//
    //-Delimeters---------------------------------------------------------------------------------//
    // - ASCII char: `{`
    const start_brace = 123;
    // - ASCII char: `}`
    const end_brace = 125;
    // - ASCII char `[`
    const start_bracket = 91;
    // - ASCII char `]`
    const end_bracket = 93;
    // - ASCII char `"`
    const quote = 34;
    // - ASCII char `:`
    const colon = 58;
    // - ASCII char `,`
    const comma = 44;
    //--------------------------------------------------------------------------------------------//
    // White space
    // - ASCII char: `\n`
    const newline = 10;
    // - ASCII char: ` `
    const space = 32;
    //--------------------------------------------------------------------------------------------//
    // Escape
    // - ASCII char: `\`
    const escape = 92;
    //--------------------------------------------------------------------------------------------//

    describe("StateUpdate", () => {
        let circuit: WitnessTester<
            ["byte", "pointer", "stack", "parsing_string", "parsing_array", "parsing_object", "parsing_number", "key_or_value"],
            ["next_pointer", "next_stack", "next_parsing_string", "next_parsing_array", "next_parsing_object", "next_parsing_number", "next_key_or_value"]
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
            });
            console.log("#constraints:", await circuit.getConstraintCount());

        });

        let init = {
            byte: 0,
            pointer: 0,
            stack: [0, 0, 0, 0],
            parsing_string: 0,
            parsing_array: 0,
            parsing_object: 0,
            parsing_number: 0,
            key_or_value: 0,
        };
        let out = {
            next_pointer: init.pointer,
            next_stack: init.stack,
            next_parsing_string: init.parsing_string,
            next_parsing_array: init.parsing_array,
            next_parsing_object: init.parsing_object,
            next_parsing_number: init.parsing_number,
            next_key_or_value: init.key_or_value,
        };

        // Test 1: init setup -> `do_nothing` byte
        generatePassCase(init, out, ">>>> `NUL` read");

        // Test 2: init setup -> `{` is read
        let read_start_brace = { ...init };
        read_start_brace.byte = start_brace;
        let read_start_brace_out = { ...out };
        read_start_brace_out.next_pointer = 1;
        read_start_brace_out.next_stack = [1, 0, 0, 0];
        read_start_brace_out.next_parsing_object = 1;
        generatePassCase(read_start_brace, read_start_brace_out, ">>>> `{` read");

        // Test 3: init setup -> `}` is read (should be INVALID)
        let read_end_brace = { ...init };
        read_end_brace.byte = end_brace;
        generateFailCase(read_end_brace, ">>>> `}` read --> (stack underflow)");

        // // Test 4: after just reading { then read a quote
        // let in_object_find_key = { ...init };
        // in_object_find_key.pointer = read_start_brace_out.next_pointer;
        // in_object_find_key.stack = read_start_brace_out.next_stack;
        // in_object_find_key.parsing_object = read_start_brace_out.next_parsing_object;
        // in_object_find_key.byte = quote;
        // let in_object_find_key_out = { ...out };
        // in_object_find_key_out.next_pointer = 1;
        // in_object_find_key_out.next_stack = [1, 0, 0, 0];
        // in_object_find_key_out.next_parsing_string = 1;
        // in_object_find_key_out.next_key_or_value = 1;
        // in_object_find_key_out.next_parsing_object = 1;
        // generatePassCase(in_object_find_key, in_object_find_key_out, ">>>> `\"` read");

        // // TODO: THESE SHOULD ACTUALLY SAY WE ARE KEY OR VALUE
        // // Test 5: `tree_depth == 1` AND `inside_key ==1` setup -> ` ` is read
        // let in_key = { ...init };
        // in_key.pointer = read_start_brace_out.next_pointer;
        // in_key.stack = read_start_brace_out.next_stack;
        // in_key.parsing_object = read_start_brace_out.next_parsing_object;
        // in_key.parsing_string = 1;
        // in_key.key_or_value = 1;
        // in_key.byte = space;
        // let in_key_out = { ...out };
        // in_key_out.next_pointer = 1;
        // in_key_out.next_stack = [1, 0, 0, 0];
        // in_key_out.next_parsing_string = 1;
        // in_key_out.next_parsing_object = 1;
        // in_key_out.next_key_or_value = 1;
        // generatePassCase(in_key, in_key_out, ">>>> ` ` read");

        // // Test 6: `tree_depth == 1` AND `inside_key == 1 AND `parsing_key == 0` setup -> `"` is read
        // let in_key_to_exit = { ...init };
        // in_key_to_exit.pointer = read_start_brace_out.next_pointer;
        // in_key_to_exit.stack = read_start_brace_out.next_stack;
        // in_key_to_exit.parsing_object = read_start_brace_out.next_parsing_object;
        // in_key_to_exit.parsing_string = 1
        // in_key_to_exit.byte = quote;
        // let in_key_to_exit_out = { ...out };
        // in_key_to_exit_out.next_pointer = 1;
        // in_key_to_exit_out.next_stack = [1, 0, 0, 0];
        // in_key_to_exit_out.next_parsing_object = 1;
        // generatePassCase(in_key_to_exit, in_key_to_exit_out, "`\"` read");

        // Test 7: Stack Management
        // init: read `{`, read another `{`
        // expect: pointer --> 2
        //         stack   --> [1,1,0,0]
        let in_object = { ...init };
        in_object.pointer = read_start_brace_out.next_pointer;
        in_object.stack = read_start_brace_out.next_stack;
        in_object.parsing_object = read_start_brace_out.next_parsing_object;
        in_object.byte = start_brace;
        let in_object_out = { ...out };
        in_object_out.next_pointer = 2;
        in_object_out.next_stack = [1, 1, 0, 0];
        in_object_out.next_parsing_object = 2;
        generatePassCase(in_object, in_object_out, ">>>> `\"` read");

        // Test 8: Stack Management
        // init: read `{` then read`}`
        // expect: pointer-- > 0
        // stack-- > [0, 0, 0, 0]
        let in_object_to_leave = { ...init };
        in_object_to_leave.pointer = read_start_brace_out.next_pointer;
        in_object_to_leave.stack = read_start_brace_out.next_stack;
        in_object_to_leave.parsing_object = read_start_brace_out.next_parsing_object;
        in_object_to_leave.byte = end_brace;
        let in_object_to_leave_out = { ...out };
        in_object_to_leave_out.next_pointer = 0;
        in_object_to_leave_out.next_stack = [0, 0, 0, 0];
        in_object_to_leave_out.next_parsing_object = 0;
        generatePassCase(in_object_to_leave, in_object_to_leave_out, ">>>> `\"` read");

        // Test 9: Stack Management
        // init: read `{`, then read `[`
        // expect: pointer --> 2
        //         stack   --> [1,-1,0,0]
        in_object.byte = start_bracket;
        in_object_out.next_pointer = 2;
        in_object_out.next_stack =
            [1,
                21888242871839275222246405745257275088548364400416034343698204186575808495616,
                0,
                0];
        in_object_out.next_parsing_object = 1;
        in_object_out.next_parsing_array = 1;
        generatePassCase(in_object, in_object_out, ">>>> `\"` read");


        //// BREAK HERE AND RENAME AND ADJUST
        /// USE CLEAR PREVIOUS SETUPS SO THIS IS EASIER TO PARSE VVVVVVVVVVVV

        // // Test 7: `tree_depth == 1` AND parsed through key` setup -> `:` is read
        // let parsed_key_wait_to_parse_value = { ...init };
        // parsed_key_wait_to_parse_value.tree_depth = 1;
        // parsed_key_wait_to_parse_value.parsing_key = 1;
        // parsed_key_wait_to_parse_value.byte = colon;
        // let parsed_key_wait_to_parse_value_out = { ...out };
        // parsed_key_wait_to_parse_value_out.next_tree_depth = 1;
        // parsed_key_wait_to_parse_value_out.next_parsing_value = 1;
        // generatePassCase(parsed_key_wait_to_parse_value, parsed_key_wait_to_parse_value_out, ">>>> `:` read");

        // // Test 8: `tree_depth == 1` AND parsing_value == 1` setup -> `"` is read
        // let in_tree_find_value = { ...init };
        // in_tree_find_value.tree_depth = 1;
        // in_tree_find_value.parsing_value = 1;
        // in_tree_find_value.byte = quote;
        // let in_tree_find_value_out = { ...out };
        // in_tree_find_value_out.next_tree_depth = 1;
        // in_tree_find_value_out.next_inside_value = 1;
        // in_tree_find_value_out.next_parsing_value = 1;
        // generatePassCase(in_tree_find_value, in_tree_find_value_out, ">>>> `\"` read");

        // // Test 9: `tree_depth == 1` AND inside_value` setup -> ` ` is read
        // let in_value = { ...init };
        // in_value.tree_depth = 1;
        // in_value.inside_value = 1;
        // in_value.byte = space;
        // let in_value_out = { ...out };
        // in_value_out.next_tree_depth = 1;
        // in_value_out.next_inside_value = 1;
        // generatePassCase(in_value, in_value_out, ">>>> ` ` is read");

        // // Test 10: `tree_depth == 1` AND inside_value` setup -> `"` is read
        // let in_value_to_exit = { ...init };
        // in_value_to_exit.tree_depth = 1;
        // in_value_to_exit.parsing_value = 1;
        // in_value_to_exit.inside_value = 1;
        // in_value_to_exit.byte = quote;
        // let in_value_to_exit_out = { ...out };
        // in_value_to_exit_out.next_tree_depth = 1;
        // // in_value_to_exit_out.next_end_of_kv = 1;
        // in_value_to_exit_out.next_parsing_value = 1;
        // generatePassCase(in_value_to_exit, in_value_to_exit_out, ">>>> `\"` is read");

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

});


