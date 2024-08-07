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

    describe("StateUpdate", () => {
        let circuit: WitnessTester<
            ["byte", "tree_depth", "parsing_to_key", "inside_key", "parsing_to_value", "inside_value", "escaping", "end_of_kv"],
            ["next_tree_depth", "next_parsing_to_key", "next_inside_key", "next_parsing_to_value", "next_inside_value", "next_end_of_kv"]
        >;

        function generateTestCase(input: any, expected: any) {
            const description = Object.entries(input)
                .map(([key, value]) => `${key} = ${value}`)
                .join(", ");

            it(`witness: ${description}`, async () => {
                await circuit.expectPass(input, expected);
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
        generateTestCase(init, out);

        // Test 2: init setup -> `{` is read
        let read_start_brace = init;
        read_start_brace.byte = 123;
        let read_start_brace_out = out;
        read_start_brace_out.next_tree_depth = 1;
        generateTestCase(read_start_brace, read_start_brace_out);

    });

});


