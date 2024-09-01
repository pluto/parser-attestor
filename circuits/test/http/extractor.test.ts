import { circomkit, WitnessTester, generateDescription, readHTTPInputFile } from "../common";

describe("HTTP :: Response Extractor", async () => {
    let circuit: WitnessTester<["data"], ["response"]>;


    function generatePassCase(input: number[], expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`ExtractResponseData`, {
                file: "circuits/http/extractor",
                template: "ExtractResponseData",
                params: [input.length, expected.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input }, { response: expected });
        });
    }

    let parsedHttp = readHTTPInputFile("get_response.http");

    let output =
        generatePassCase(parsedHttp.input, parsedHttp.bodyBytes, "");

    let output2 = parsedHttp.bodyBytes.slice(0);
    output2.push(0, 0, 0, 0);
    generatePassCase(parsedHttp.input, output2, "output length more than actual length");

    let output3 = parsedHttp.bodyBytes.slice(0);
    output3.pop();
    output3.pop();
    generatePassCase(parsedHttp.input, output3, "output length less actual length");
});