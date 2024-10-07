import { circomkit, WitnessTester, generateDescription, readJSONInputFile } from "../../common";

describe("json-parser", () => {
    let circuit: WitnessTester<["data"]>;

    it(`array only input`, async () => {
        let filename = "array_only";
        let [input, keyUnicode, output] = readJSONInputFile(`${filename}.json`, [0]);

        circuit = await circomkit.WitnessTester(`StateUpdate`, {
            file: "json/parser/machine",
            template: "StateUpdate",
            params: [input.length, 2],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectPass({
            data: input
        });
    });
})