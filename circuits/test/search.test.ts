import { circomkit, WitnessTester } from "./common";

import witness from "../../inputs/search/witness.json";
import { PoseidonModular } from "./common/poseidon";

describe("search", () => {
    describe("SubstringSearch", () => {
        let circuit: WitnessTester<["data", "key", "random_num"], ["position"]>;

        it("key at first position", async () => {
            const data = [10, 8, 9, 4, 11, 9, 1, 2];
            const key = [10, 8, 9, 4];
            const concatenatedInput = key.concat(data);
            const hashResult = PoseidonModular(concatenatedInput);

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringSearch",
                params: [data.length, key.length],
            });

            await circuit.expectPass(
                { data: data, key: key, random_num: hashResult },
                { position: 0 },
            );
        });

        it("key at last position", async () => {
            const data = [11, 9, 1, 2, 10, 8, 9, 4];
            const key = [10, 8, 9, 4];
            const concatenatedInput = key.concat(data);
            const hashResult = PoseidonModular(concatenatedInput);

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringSearch",
                params: [data.length, key.length],
            });

            await circuit.expectPass(
                { data: data, key: key, random_num: hashResult },
                { position: 4 },
            );
        });

        it("wrong random_num input, correct key position: 2", async () => {
            const data = [0, 0, 1, 0, 0];
            const key = [1, 0];

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringSearch",
                params: [data.length, key.length],
            });

            await circuit.expectPass(
                { data: data, key: key, random_num: 1 },
                { position: 1 },
            );
        });

        it("data = inputs.json:data, key = inputs.json:key, r = hash(data+key)", async () => {
            const concatenatedInput = witness["key"].concat(witness["data"]);
            const hashResult = PoseidonModular(concatenatedInput);

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringSearch",
                params: [witness["data"].length, witness["key"].length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass(
                { data: witness["data"], key: witness["key"], random_num: hashResult },
                { position: 6 }
            );
        });
    });

    describe("SubstringMatchWithIndex", () => {
        let circuit: WitnessTester<["data", "key", "r", "start"]>;

        before(async () => {
            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringMatchWithIndex",
                params: [787, 10],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("data = inputs.json:data, key = inputs.json:key, r = hash(data+key)", async () => {
            await circuit.expectPass(
                {
                    data: witness["data"],
                    key: witness["key"],
                    r: PoseidonModular(witness["key"].concat(witness["data"])),
                    start: 6
                },
            );
        });

        it("data = inputs.json:data, key = inputs.json:key, r = hash(data+key),  incorrect position", async () => {
            await circuit.expectFail(
                {
                    data: witness["data"],
                    key: witness["key"],
                    r: PoseidonModular(witness["key"].concat(witness["data"])),
                    start: 98
                },
            );
        });
    });

    describe("SubstringMatch", () => {
        let circuit: WitnessTester<["data", "key"], ["position"]>;

        before(async () => {
            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringMatch",
                params: [787, 10],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("data = inputs.json:data, key = inputs.json:key", async () => {
            await circuit.expectPass(
                { data: witness["data"], key: witness["key"] },
                { position: 6 },
            );
        });

        it("data = inputs.json:data, key = wrong key", async () => {
            await circuit.expectFail(
                { data: witness["data"], key: witness["key"].concat(257) },
            );
        });
    });
});