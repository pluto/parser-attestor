import { circomkit, WitnessTester, toByte, readJSONInputFile } from "./common";
import { readLockFile, readHTTPInputFile, getHeaders as getHttpHeaders, Response } from "./common/http";
import { executeCodegen as httpLockfileCodegen } from "./http/codegen.test";
import { executeCodegen as jsonLockfileCodegen } from "./json/extractor/extractor.test";

describe("spotify top artists", async () => {
    let http_circuit: WitnessTester<["data", "version", "status", "message", "header1", "value1", "header2", "value2"], ["body"]>;
    let json_circuit: WitnessTester<["data", "key1", "key2", "key3", "key4", "key5", "key7", "key8", "key9"], ["value"]>;

    it("POST response body extraction", async () => {
        let httpLockfile = "spotify.lock"
        let httpInputFile = "spotify_top_artists_response.http";
        let httpCircuitName = "spotify_top_artists";

        await httpLockfileCodegen(httpCircuitName, httpInputFile, `${httpLockfile}.json`);

        let jsonFilename = "spotify";

        await jsonLockfileCodegen(`${jsonFilename}_test`, `${jsonFilename}.json`, `${jsonFilename}.json`);

        let index_0 = 0;

        let [inputJson, key, output] = readJSONInputFile(
            `${jsonFilename}.json`,
            [
                "data",
                "me",
                "profile",
                "topArtists",
                "items",
                index_0,
                "data",
                "profile",
                "name"
            ]
        );

        // json_circuit = await circomkit.WitnessTester(`Extract`, {
        //     file: `main/json_${jsonFilename}_test`,
        //     template: "ExtractStringValue",
        //     params: [input.length, 9, 4, 0, 2, 1, 7, 2, 10, 3, 5, 4, index_0, 5, 4, 6, 7, 7, 4, 8, 12],
        // });
        // console.log("#constraints:", await json_circuit.getConstraintCount());

        // await json_circuit.expectPass({ data: input, key1: key[0], key2: key[1], key3: key[2], key4: key[3], key5: key[4], key7: key[6], key8: key[7], key9: key[8] }, { value: output });

        const lockData = readLockFile<Response>(`${httpLockfile}.json`);
        console.log("lockData: ", JSON.stringify(lockData));

        const http = readHTTPInputFile(`${httpInputFile}`);
        const inputHttp = http.input;

        const headers = getHttpHeaders(lockData);

        const params = [inputHttp.length, http.bodyBytes.length, lockData.version.length, lockData.status.length, lockData.message.length];
        headers.forEach(header => {
            params.push(header[0].length);
            params.push(header[1].length);
        });

        // http_circuit = await circomkit.WitnessTester(`Extract`, {
        //     file: `main/http_${httpCircuitName}`,
        //     template: "LockHTTPResponse",
        //     params: params,
        // });
        // console.log("#constraints:", await http_circuit.getConstraintCount());

        // match circuit output to original JSON value
        const circuitInput: any = {
            data: inputHttp,
            version: toByte(lockData.version),
            status: toByte(lockData.status),
            message: toByte(lockData.message),
        };

        headers.forEach((header, index) => {
            circuitInput[`header${index + 1}`] = toByte(header[0]);
            circuitInput[`value${index + 1}`] = toByte(header[1]);
        });

        // await http_circuit.expectPass(circuitInput, { body: http.bodyBytes });
    });
})