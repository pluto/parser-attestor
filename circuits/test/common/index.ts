import 'mocha';
import { Circomkit, WitnessTester } from "circomkit";

export const circomkit = new Circomkit({
    verbose: false,
});

export { WitnessTester };

export function generatePassCase(input: any, expected: any, desc: string, circuit: any) {
    const description = Object.entries(input)
        .map(([key, value]) => `${key} = ${value}`)
        .join(", ");

    it(`(valid) witness: ${description}\n${desc}`, async () => {
        await circuit.expectPass(input, expected);
    });
}

export function generateFailCase(input: any, desc: string, circuit: any) {
    const description = Object.entries(input)
        .map(([key, value]) => `${key} = ${value}`)
        .join(", ");

    it(`(invalid) witness: ${description}\n${desc}`, async () => {
        await circuit.expectFail(input);
    });
}