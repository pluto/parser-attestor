import { circomkit, WitnessTester, generateDescription } from "../common";
import { Delimiters, WhiteSpace, Numbers, Escape, INITIAL_IN, INITIAL_OUT } from '.';

describe("StateUpdate :: Values", () => {
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

    // //-TEST_1----------------------------------------------------------//
    // // idea:   Read a number value after a key in an object.
    // // state:  pointer == 2, stack == [1,3,0,0]
    // // read:   `0`
    // // expect: pointer        --> 2
    // //         stack          --> [1,3,0,0]
    // //         parsing_number --> 1
    // let read_number = { ...INITIAL_IN };
    // read_number.pointer = 2;
    // read_number.stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    // read_number.byte = Numbers.ZERO;
    // let read_number_out = { ...INITIAL_OUT };
    // read_number_out.next_pointer = 2;
    // read_number_out.next_stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    // read_number_out.next_parsing_number = 1;
    // generatePassCase(read_number, read_number_out, ">>>> `0` read");

    // //-TEST_2----------------------------------------------------------//
    // // idea:   Inside a number value after a key in an object.
    // // state:  pointer == 2, stack == [1,3,0,0], parsing_number == 1
    // // read:   `,`
    // // expect: pointer        --> 2
    // //         stack          --> [1,3,0,0]
    // //         parsing_number --> 0
    // let inside_number = { ...INITIAL_IN };
    // inside_number.pointer = 2;
    // inside_number.stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    // inside_number.parsing_number = 1;
    // inside_number.byte = Delimiters.COMMA;
    // let inside_number_out = { ...INITIAL_OUT };
    // inside_number_out.next_pointer = 2;
    // inside_number_out.next_stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    // generatePassCase(inside_number, inside_number_out, ">>>> `,` read");

    // // TODO: Note that reading a space while reading a number will not throw an error!

    // //-TEST_2----------------------------------------------------------//
    // // idea:   Inside a number value after a key in an object.
    // // state:  pointer == 2, stack == [1,3,0,0], parsing_number == 1
    // // read:   `1`
    // // expect: pointer        --> 2
    // //         stack          --> [1,3,0,0]
    // //         parsing_number --> 0
    // let inside_number_continue = { ...INITIAL_IN };
    // inside_number_continue.pointer = 2;
    // inside_number_continue.stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    // inside_number_continue.parsing_number = 1;
    // inside_number_continue.byte = Numbers.ONE;
    // let inside_number_continue_out = { ...INITIAL_OUT };
    // inside_number_continue_out.next_pointer = 2;
    // inside_number_continue_out.next_stack = [[1, 0], [3, 0], [0, 0], [0, 0]];
    // inside_number_continue_out.next_parsing_number = 1;
    // generatePassCase(inside_number_continue, inside_number_continue_out, ">>>> `,` read");
});