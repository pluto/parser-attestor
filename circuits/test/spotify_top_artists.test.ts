import { circomkit, WitnessTester, toByte, readJSONInputFile } from "./common";
import { readLockFile, readHTTPInputFile, getHeaders as getHttpHeaders, Response, Request } from "./common/http";
import { executeCodegen as httpLockfileCodegen } from "./http/codegen.test";
import { executeCodegen as jsonLockfileCodegen } from "./json/extractor/extractor.test";
import { join } from "path";
import { spawn } from "child_process";
import { readFileSync } from "fs";
import { version } from "os";

async function extendedLockfileCodegen(circuitName: string, inputFileName: string, lockfileName: string) {
    return new Promise((resolve, reject) => {
        const inputFilePath = join(__dirname, "..", "..", "examples", "http", inputFileName);
        const lockfilePath = join(__dirname, "..", "..", "examples", "http", "lockfile", lockfileName);

        const codegen = spawn("cargo", ["run", "codegen", "extended", "--circuit-name", circuitName, "--input-file", inputFilePath, "--lockfile", lockfilePath]);

        codegen.stdout.on('data', (data) => {
            console.log(`stdout: ${data}`);
        });

        codegen.stderr.on('data', (data) => {
            console.error(`stderr: ${data}`);
        });

        codegen.on('close', (code) => {
            if (code === 0) {
                resolve(`child process exited with code ${code}`); // Resolve the promise if the process exits successfully
            } else {
                reject(new Error(`Process exited with code ${code}`)); // Reject if there's an error
            }
        });
    })
}

// describe("spotify top artists separate", async () => {
//     let http_circuit: WitnessTester<["data", "version", "status", "message", "header1", "value1"], ["body"]>;
//     let json_circuit: WitnessTester<["data", "key1", "key2", "key4", "key5"], ["value"]>;

//     it("POST response body extraction", async () => {
//         let httpLockfile = "spotify.lock"
//         let httpInputFile = "spotify_top_artists_response.http";
//         let httpCircuitName = "spotify_top_artists";

//         await httpLockfileCodegen(httpCircuitName, httpInputFile, `${httpLockfile}.json`);

//         let jsonFilename = "spotify";

//         await jsonLockfileCodegen(`${jsonFilename}_test`, `${jsonFilename}.json`, `${jsonFilename}.json`);

//         const lockData = readLockFile<Response>(`${httpLockfile}.json`);

//         const http = readHTTPInputFile(`${httpInputFile}`);
//         const inputHttp = http.input;

//         const headers = getHttpHeaders(lockData);

//         const params = [inputHttp.length, http.bodyBytes.length, lockData.version.length, lockData.status.length, lockData.message.length];
//         headers.forEach(header => {
//             params.push(header[0].length);
//             params.push(header[1].length);
//         });

//         http_circuit = await circomkit.WitnessTester(`Extract`, {
//             file: `main/http_${httpCircuitName}`,
//             template: "LockHTTPResponse",
//             params: params,
//         });
//         console.log("#constraints:", await http_circuit.getConstraintCount());

//         // match circuit output to original JSON value
//         const circuitInput: any = {
//             data: inputHttp,
//             version: toByte(lockData.version),
//             status: toByte(lockData.status),
//             message: toByte(lockData.message),
//         };

//         headers.forEach((header, index) => {
//             circuitInput[`header${index + 1}`] = toByte(header[0]);
//             circuitInput[`value${index + 1}`] = toByte(header[1]);
//         });

//         await http_circuit.expectPass(circuitInput, { body: http.bodyBytes });

//         let index_0 = 0;

//         let [inputJson, key, output] = readJSONInputFile(
//             `${jsonFilename}.json`,
//             [
//                 "data",
//                 "items",
//                 index_0,
//                 "profile",
//                 "name"
//             ]
//         );

//         json_circuit = await circomkit.WitnessTester(`Extract`, {
//             file: `main/json_${jsonFilename}_test`,
//             template: "ExtractStringValue",
//             params: [inputJson.length, 5, 4, 0, 5, 1, index_0, 2, 7, 3, 4, 4, 12],
//         });
//         console.log("#constraints:", await json_circuit.getConstraintCount());

//         await json_circuit.expectPass({ data: inputJson, key1: key[0], key2: key[1], key4: key[3], key5: key[4] }, { value: output });
//     });
// });

interface JsonLockfile {
    keys: any[],
    valueType: string,
}

interface HttpJsonLockdata {
    http: Response,
    json: JsonLockfile,
}

describe("spotify top artists", async () => {
    let circuit: WitnessTester<["data", "version", "status", "message", "header1", "value1", "key1", "key2", "key4", "key5"], ["value"]>;

    it("extraction", async () => {
        let lockfile = "spotify_extended.lock.json"
        let inputFile = "spotify_top_artists_response.http";
        let circuitName = "spotify_top_artists";

        await extendedLockfileCodegen(circuitName, inputFile, lockfile);

        const lockFilePath = join(__dirname, "..", "..", "examples", "http", "lockfile", lockfile);
        const fileString = readFileSync(lockFilePath, 'utf-8');
        const lockData: HttpJsonLockdata = JSON.parse(fileString);

        const http = readHTTPInputFile(`${inputFile}`);
        const inputHttp = http.input;
        let [inputJson, key, finalOutput] = readJSONInputFile(JSON.stringify(http.body), lockData.json.keys);

        const headers = getHttpHeaders(lockData.http);

        const params = [inputHttp.length, http.bodyBytes.length, lockData.http.version.length, lockData.http.status.length, lockData.http.message.length];
        headers.forEach(header => {
            params.push(header[0].length);
            params.push(header[1].length);
        });

        // JSON extractor params

        // MAX_STACK_HEIGHT
        params.push(5);

        // keys
        for (var i = 0; i < lockData.json.keys.length; i++) {
            let key = lockData.json.keys[i];
            if (typeof (key) == "string") {
                params.push(String(key).length);
            } else if (typeof (key) == "number") {
                params.push(key);
            }
            params.push(i);
        }

        // maxValueLen
        params.push(finalOutput.length);

        circuit = await circomkit.WitnessTester(`spotify_top_artists_test`, {
            file: `main/extended_${circuitName}`,
            template: "HttpJson",
            params: params,
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        // circuit input for http + json

        // add http start line + headers
        const circuitInput: any = {
            data: inputHttp,
            version: toByte(lockData.http.version),
            status: toByte(lockData.http.status),
            message: toByte(lockData.http.message),
        };
        headers.forEach((header, index) => {
            circuitInput[`header${index + 1}`] = toByte(header[0]);
            circuitInput[`value${index + 1}`] = toByte(header[1]);
        });

        // add json key inputs
        circuitInput["key1"] = key[0];
        circuitInput["key2"] = key[1];
        circuitInput["key4"] = key[3];
        circuitInput["key5"] = key[4];

        await circuit.expectPass(circuitInput);
        // TODO: currently this fails due to sym file being too large
        // await circuit.expectPass(circuitInput, { value: finalOutput });
    });
});