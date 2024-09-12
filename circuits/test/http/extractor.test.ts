import { circomkit, WitnessTester, generateDescription, readHTTPInputFile, toByte } from "../common";

describe("HTTP :: body Extractor", async () => {
    let circuit: WitnessTester<["data"], ["response"]>;


    function generatePassCase(input: number[], expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`ExtractResponseData`, {
                file: "http/extractor",
                template: "ExtractResponse",
                params: [input.length, expected.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input }, { response: expected });
        });
    }

    describe("response", async () => {

        let parsedHttp = readHTTPInputFile("get_response.http");

        generatePassCase(parsedHttp.input, parsedHttp.bodyBytes, "");

        let output2 = parsedHttp.bodyBytes.slice(0);
        output2.push(0, 0, 0, 0);
        generatePassCase(parsedHttp.input, output2, "output length more than actual length");

        let output3 = parsedHttp.bodyBytes.slice(0);
        output3.pop();
        output3.pop();
        generatePassCase(parsedHttp.input, output3, "output length less than actual length");
    });

    describe("request", async () => {
        let parsedHttp = readHTTPInputFile("post_request.http");

        generatePassCase(parsedHttp.input, parsedHttp.bodyBytes, "");

        let output2 = parsedHttp.bodyBytes.slice(0);
        output2.push(0, 0, 0, 0, 0, 0);
        generatePassCase(parsedHttp.input, output2, "output length more than actual length");

        console.log(parsedHttp.bodyBytes.length);
        let output3 = parsedHttp.bodyBytes.slice(0);
        output3.pop();
        output3.pop();
        generatePassCase(parsedHttp.input, output3, "output length less than actual length");
    });
});

describe("HTTP :: header Extractor", async () => {
    let circuit: WitnessTester<["data", "header"], ["value"]>;

    function generatePassCase(input: number[], headerName: number[], headerValue: number[], desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`ExtractHeaderValue`, {
                file: "http/extractor",
                template: "ExtractHeaderValue",
                params: [input.length, headerName.length, headerValue.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input, header: headerName }, { value: headerValue });
        });
    }

    describe("response", async () => {

        let parsedHttp = readHTTPInputFile("get_response.http");

        generatePassCase(parsedHttp.input, toByte("Content-Length"), toByte(parsedHttp.headers["Content-Length"]), "");
    });
});

