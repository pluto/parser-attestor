import { circomkit, WitnessTester } from "../common";
import { Delimiters, WhiteSpace, Numbers, Escape } from './constants';

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

    it("witness: pointer = 4, stack = [0, 1, 2, 3, 4]", async () => {
        await circuit.expectPass(
            { pointer: 4, stack: [1, 2, 3, 4] },
            { out: 4 },
        );
    });




    // TODO: Test stack fully works with brackets too
    // Test 7: Stack Management
    // init: read `{`, read another `{`
    // expect: pointer --> 2
    //         stack   --> [1,1,0,0]
    let in_object = { ...init };
    in_object.pointer = read_start_brace_out.next_pointer;
    in_object.stack = read_start_brace_out.next_stack;
    in_object.byte = Delimiters.START_BRACE;
    let in_object_out = { ...out };
    in_object_out.next_pointer = 2;
    in_object_out.next_stack = [1, 1, 0, 0];
    generatePassCase(in_object, in_object_out, ">>>> `{` read");

    // Test 8: Stack Management
    // init: read `{` then read`}`
    // expect: pointer --> 0
    //           stack --> [0, 0, 0, 0]
    let in_object_to_leave = { ...init };
    in_object_to_leave.pointer = read_start_brace_out.next_pointer;
    in_object_to_leave.stack = read_start_brace_out.next_stack;
    in_object_to_leave.byte = Delimiters.END_BRACE;
    let in_object_to_leave_out = { ...out };
    in_object_to_leave_out.next_pointer = 0;
    in_object_to_leave_out.next_stack = [0, 0, 0, 0];
    generatePassCase(in_object_to_leave, in_object_to_leave_out, ">>>> `}` read");

    // Test 9: Stack Management
    // init: read `{`, then read `[`
    // expect: pointer --> 2
    //         stack   --> [1,2,0,0]
    let in_object_to_read_start_bracket = { ...init };
    in_object_to_read_start_bracket.byte = Delimiters.START_BRACKET;
    in_object_to_read_start_bracket.pointer = 1;
    in_object_to_read_start_bracket.stack = [1, 0, 0, 0];
    let in_object_to_read_start_bracket_out = { ...out };
    in_object_to_read_start_bracket_out.next_pointer = 2;
    in_object_to_read_start_bracket_out.next_stack = [1, 2, 0, 0];
    generatePassCase(in_object_to_read_start_bracket, in_object_to_read_start_bracket_out, ">>>> `[` read");

    // Test 10: Stack Management
    // init: read 4x `{`, then read `{`
    // expect: pointer --> 4
    //         stack   --> [1,1,1,1]
    let in_max_stack = { ...init };
    in_max_stack.byte = Delimiters.START_BRACE;
    in_max_stack.pointer = 4;
    in_max_stack.stack = [1, 1, 1, 1];
    generateFailCase(in_max_stack, ">>>> `{` read --> (stack overflow)");

    // Test 11: Stack Management
    // init: read 4x `{`, then read `[`
    // expect: pointer --> 4
    //         stack   --> [1,1,1,1]
    let in_max_stack_2 = { ...init };
    in_max_stack_2.byte = Delimiters.START_BRACKET;
    in_max_stack_2.pointer = 4;
    in_max_stack_2.stack = [1, 1, 1, 1];
    generateFailCase(in_max_stack, ">>>> `[` read --> (stack overflow)");

    // Test 12: Stack Management
    // init: read `{` and `[`, then read `]`
    // expect: pointer --> 2
    //         stack   --> [1,0,0,0]
    let in_object_and_array = { ...init };
    in_object_and_array.byte = Delimiters.END_BRACKET;
    in_object_and_array.pointer = 2;
    in_object_and_array.stack = [1, 2, 0, 0];
    let in_object_and_array_out = { ...out };
    in_object_and_array_out.next_pointer = 1;
    in_object_and_array_out.next_stack = [1, 0, 0, 0];
    generatePassCase(in_object_and_array, in_object_and_array_out, ">>>> `]` read");

    // Test 12: Stack Management
    // init: read `{` and `:`, then read `,`
    // expect: pointer --> 2
    //         stack   --> [1,3,0,0]
    let in_object_and_value = { ...init };
    in_object_and_value.byte = Delimiters.COMMA;
    in_object_and_value.pointer = 2;
    in_object_and_value.stack = [1, 3, 0, 0];
    let in_object_and_value_out = { ...out };
    in_object_and_value_out.next_pointer = 1;
    in_object_and_value_out.next_stack = [1, 0, 0, 0];
    generatePassCase(in_object_and_value, in_object_and_value_out, ">>>> `,` read");

    // Test 13: Stack Management
    // init: read `{` and `:`, then read `,`
    // expect: pointer --> 2
    //         stack   --> [1,3,0,0]
    let in_object_and_value_to_leave_object = { ...init };
    in_object_and_value_to_leave_object.byte = Delimiters.END_BRACE;
    in_object_and_value_to_leave_object.pointer = 2;
    in_object_and_value_to_leave_object.stack = [1, 3, 0, 0];
    let in_object_and_value_to_leave_object_out = { ...out };
    in_object_and_value_to_leave_object_out.next_pointer = 0;
    in_object_and_value_to_leave_object_out.next_stack = [0, 0, 0, 0];
    generatePassCase(in_object_and_value_to_leave_object, in_object_and_value_to_leave_object_out, ">>>> `,` read");








    //-----------------------------------------------------------------------------//
    // Test SOMETHING: 
    // init: pointer = 1, stack = [1,2,0,0] -> `,` is read
    let inside_array = { ...init };
    inside_array.pointer = 2;
    inside_array.stack = [1, 2, 0, 0];
    inside_array.byte = Delimiters.COMMA;
    let inside_array_out = { ...out };
    inside_array_out.next_pointer = 2;
    inside_array_out.next_stack = [1, 2, 0, 0];
    generatePassCase(inside_array, inside_array_out, ">>>> `,` read");
    //-----------------------------------------------------------------------------//

});