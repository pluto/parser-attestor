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
            ["byte", "tree_depth", "parsing_to_key", "inside_key", "parsing_to_value", "inside_value", "escaping", "end_of_kv"],
            ["next_tree_depth", "next_parsing_to_key", "next_inside_key", "next_parsing_to_value", "next_inside_value", "next_end_of_kv"]
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
            tree_depth: 0,
            parsing_to_key: 1,
            inside_key: 0,
            parsing_to_value: 0,
            inside_value: 0,
            escaping: 0,
            end_of_kv: 0,
        };

        // Test 1: init setup -> `do_nothing` byte
        let out = {
            next_tree_depth: init.tree_depth,
            next_parsing_to_key: init.parsing_to_key,
            next_inside_key: init.inside_key,
            next_parsing_to_value: init.parsing_to_value,
            next_inside_value: init.inside_value,
            next_end_of_kv: init.end_of_kv
        };

        generatePassCase(init, out, "init setup -> `do_nothing` byte");

        // Test 2: init setup -> `{` is read
        let read_start_brace = { ...init };
        read_start_brace.byte = start_brace;
        let read_start_brace_out = { ...out };
        read_start_brace_out.next_tree_depth = 1;
        generatePassCase(read_start_brace, read_start_brace_out, "init setup -> `{` is read");

        // Test 3: init setup -> `}` is read (should be INVALID)
        let read_end_brace = { ...init };
        read_end_brace.byte = end_brace;
        generateFailCase(read_end_brace, "init setup -> `}` is read (NEGATIVE TREE DEPTH!)");

        // Test 4: `tree_depth == 1` setup -> `"` is read
        let in_tree_find_key = { ...init };
        in_tree_find_key.tree_depth = 1;
        in_tree_find_key.byte = quote;
        let in_tree_find_key_out = { ...out };
        in_tree_find_key_out.next_inside_key = 1;
        in_tree_find_key_out.next_parsing_to_key = 0;
        in_tree_find_key_out.next_tree_depth = 1;
        generatePassCase(in_tree_find_key, in_tree_find_key_out, "`tree_depth == 1` setup -> `\"` is read");

        // Test 5: `tree_depth == 1` AND `inside_key ==1` setup -> ` ` is read
        let in_key = { ...init };
        in_key.tree_depth = 1;
        in_key.parsing_to_key = 0;
        in_key.inside_key = 1;
        in_key.byte = space;
        let in_key_out = { ...out };
        in_key_out.next_inside_key = 1;
        in_key_out.next_parsing_to_key = 0;
        in_key_out.next_tree_depth = 1;
        generatePassCase(in_key, in_key_out, "`tree_depth == 1` AND `inside_key == 1 AND `parsing_to_key == 0` setup -> ` ` is read");

        // Test 6: "`tree_depth == 1` AND `inside_key ==1 AND `parsing_to_key == 0` setup -> `"` is read"
        let in_key_to_exit = { ...init };
        in_key_to_exit.tree_depth = 1;
        in_key_to_exit.parsing_to_key = 0;
        in_key_to_exit.inside_key = 1;
        in_key_to_exit.byte = quote;
        let in_key_to_exit_out = { ...out };
        in_key_to_exit_out.next_inside_key = 0;
        in_key_to_exit_out.next_parsing_to_key = 0;
        in_key_to_exit_out.next_tree_depth = 1;
        generatePassCase(in_key_to_exit, in_key_to_exit_out, "`tree_depth == 1` AND `inside_key == 1 AND `parsing_to_key == 0` setup -> `\"` is read");
    });

});


