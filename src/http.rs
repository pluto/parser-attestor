use codegen::CircomkitCircuitsInput;
use regex::Regex;
use witness::read_input_file_as_bytes;

use super::*;
use std::{
    collections::HashMap,
    fs::{self, create_dir_all},
};

use super::codegen::write_circuit_config;

#[derive(Serialize, Deserialize)]
#[serde(untagged)]
pub enum HttpData {
    Request(Request),
    Response(Response),
}

#[derive(Debug, Deserialize)]
pub struct Request {
    method: String,
    target: String,
    version: String,
    #[serde(flatten)]
    #[serde(deserialize_with = "deserialize_headers")]
    headers: HashMap<String, String>,
}

#[derive(Debug, Deserialize)]
pub struct Response {
    version: String,
    status: String,
    message: String,
    #[serde(flatten)]
    #[serde(deserialize_with = "deserialize_headers")]
    headers: HashMap<String, String>,
}

impl HttpData {
    fn headers(&self) -> HashMap<String, String> {
        match self {
            HttpData::Request(request) => request.headers.clone(),
            HttpData::Response(response) => response.headers.clone(),
        }
    }
}

impl std::fmt::Debug for HttpData {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            HttpData::Request(req) => req.fmt(f),
            HttpData::Response(res) => res.fmt(f),
        }
    }
}

impl Serialize for Request {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        use serde::ser::SerializeMap;
        let mut map = serializer.serialize_map(Some(3 + self.headers.len() * 2))?;

        map.serialize_entry("method", self.method.as_bytes())?;
        map.serialize_entry("target", self.target.as_bytes())?;
        map.serialize_entry("version", self.version.as_bytes())?;

        for (i, (key, value)) in self.headers.iter().enumerate() {
            map.serialize_entry(&format!("key{}", i + 1), key.as_bytes())?;
            map.serialize_entry(&format!("value{}", i + 1), value.as_bytes())?;
        }
        map.end()
    }
}

impl Serialize for Response {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        use serde::ser::SerializeMap;
        let mut map = serializer.serialize_map(Some(3 + self.headers.len() * 2))?;

        map.serialize_entry("version", self.version.as_bytes())?;
        map.serialize_entry("status", self.status.as_bytes())?;
        map.serialize_entry("message", self.message.as_bytes())?;

        for (i, (key, value)) in self.headers.iter().enumerate() {
            map.serialize_entry(&format!("key{}", i + 1), key)?;
            map.serialize_entry(&format!("value{}", i + 1), value)?;
        }
        map.end()
    }
}

fn deserialize_headers<'de, D>(deserializer: D) -> Result<HashMap<String, String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let mut map = HashMap::new();
    let mut temp_map: HashMap<String, String> = HashMap::deserialize(deserializer)?;

    let mut i = 1;
    while let (Some(name), Some(value)) = (
        temp_map.remove(&format!("headerName{}", i)),
        temp_map.remove(&format!("headerValue{}", i)),
    ) {
        map.insert(name, value);
        i += 1;
    }

    Ok(map)
}

const PRAGMA: &str = "pragma circom 2.1.9;\n\n";

fn build_http_circuit(
    data: &HttpData,
    output_filename: &String,
    debug: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut circuit_buffer = String::new();

    // Dump out the contents of the lockfile used into the circuit
    circuit_buffer += "/*\n";
    circuit_buffer += &format!("{:#?}", data);
    circuit_buffer += "\n*/\n";

    // Version and includes
    circuit_buffer += PRAGMA;
    circuit_buffer += "include \"../http/interpreter.circom\";\n";
    circuit_buffer += "include \"../http/parser/machine.circom\";\n";
    circuit_buffer += "include \"../utils/bytes.circom\";\n";
    circuit_buffer += "include \"../utils/search.circom\";\n";
    circuit_buffer += "include \"circomlib/circuits/gates.circom\";\n";
    circuit_buffer += "include \"@zk-email/circuits/utils/array.circom\";\n\n";

    {
        match data {
            HttpData::Request(_) => {
                circuit_buffer +=
                    "template LockHTTPRequest(DATA_BYTES, methodLen, targetLen, versionLen";
            }
            HttpData::Response(_) => {
                circuit_buffer +=
                    "template LockHTTPResponse(DATA_BYTES, maxContentLength, versionLen, statusLen, messageLen";
            }
        }

        for (i, _header) in data.headers().iter().enumerate() {
            circuit_buffer += &format!(", headerNameLen{}, headerValueLen{}", i + 1, i + 1);
        }
        circuit_buffer += ") {";
    }

    {
        circuit_buffer += r#"
    // Raw HTTP bytestream
    signal input data[DATA_BYTES];
"#;

        // Start line signals
        {
            match data {
                HttpData::Request(_) => {
                    circuit_buffer += r#"
    // Request line attributes
    signal input method[methodLen];
    signal input target[targetLen];
    signal input version[versionLen];

"#;
                }
                HttpData::Response(_) => {
                    circuit_buffer += r#"
    // Status line attributes
    signal input version[versionLen];
    signal input status[statusLen];
    signal input message[messageLen];

"#;
                }
            }
        }

        // Header signals
        circuit_buffer += "    // Header names and values to lock\n";
        for (i, _header) in data.headers().iter().enumerate() {
            circuit_buffer += &format!(
                "    signal input header{}[headerNameLen{}];\n",
                i + 1,
                i + 1
            );
            circuit_buffer += &format!(
                "    signal input value{}[headerValueLen{}];\n",
                i + 1,
                i + 1
            );
        }
    }

    // Create an output if circuit is for `Response`
    {
        if let HttpData::Response(_) = data {
            circuit_buffer += r#"
    // Set up mask bits for where the body of response lies
    signal output body[maxContentLength];

    signal bodyMask[DATA_BYTES];
    bodyMask[0] <== 0;
"#;
        }
    }

    // Setup for parsing the start line
    {
        match data {
            HttpData::Request(_) => {
                circuit_buffer += r#"
    // Check first method byte
    signal methodIsEqual[methodLen];
    methodIsEqual[0] <== IsEqual()([data[0],method[0]]);
    methodIsEqual[0] === 1;

    // Setup to check target and version bytes
    signal startLineMask[DATA_BYTES];
    signal targetMask[DATA_BYTES];
    signal versionMask[DATA_BYTES];

    var target_start_counter = 1;
    var target_end_counter   = 1;
    var version_end_counter  = 1;
"#;
            }
            HttpData::Response(_) => {
                circuit_buffer += r#"
    // Check first version byte
    signal versionIsEqual[versionLen];
    versionIsEqual[0] <== IsEqual()([data[0],version[0]]);
    versionIsEqual[0] === 1;

    // Setup to check status and message bytes
    signal startLineMask[DATA_BYTES];
    signal statusMask[DATA_BYTES];
    signal messageMask[DATA_BYTES];

    var status_start_counter = 1;
    var status_end_counter   = 1;
    var message_end_counter  = 1;
"#;
            }
        }
    }

    circuit_buffer += r#"
    component State[DATA_BYTES];
    State[0]                       = StateUpdate();
    State[0].byte                <== data[0];
    State[0].parsing_start       <== 1;
    State[0].parsing_header      <== 0;
    State[0].parsing_field_name  <== 0;
    State[0].parsing_field_value <== 0;
    State[0].parsing_body        <== 0;
    State[0].line_status         <== 0;

"#;

    // Create header match signals
    {
        for (i, _header) in data.headers().iter().enumerate() {
            circuit_buffer += &format!("    signal headerNameValueMatch{}[DATA_BYTES];\n", i + 1);
            circuit_buffer += &format!("    headerNameValueMatch{}[0] <== 0;\n", i + 1);
            circuit_buffer += &format!("    var hasMatchedHeaderValue{} = 0;\n\n", i + 1);
        }
    }

    // Intro loop
    {
        circuit_buffer += r#"
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                       = StateUpdate();
        State[data_idx].byte                <== data[data_idx];
        State[data_idx].parsing_start       <== State[data_idx - 1].next_parsing_start;
        State[data_idx].parsing_header      <== State[data_idx - 1].next_parsing_header;
        State[data_idx].parsing_field_name  <== State[data_idx-1].next_parsing_field_name;
        State[data_idx].parsing_field_value <== State[data_idx-1].next_parsing_field_value;
        State[data_idx].parsing_body        <== State[data_idx - 1].next_parsing_body;
        State[data_idx].line_status         <== State[data_idx - 1].next_line_status;

"#;
    }

    // If parsing a `Response`, create a mask of the body bytes
    {
        if let HttpData::Response(_) = data {
            circuit_buffer += r#"
        // Mask if parser is in the body of response
        bodyMask[data_idx] <== data[data_idx] * State[data_idx].next_parsing_body;
"#;
        }
    }

    // Start line matches
    {
        match data {
            HttpData::Request(_) => {
                circuit_buffer += r#"
        // Check remaining method bytes
        if(data_idx < methodLen) {
            methodIsEqual[data_idx] <== IsEqual()([data[data_idx], method[data_idx]]);
            methodIsEqual[data_idx] === 1;
        }

        // Get the target bytes
        startLineMask[data_idx]    <== inStartLine()(State[data_idx].parsing_start);
        targetMask[data_idx]       <== inStartMiddle()(State[data_idx].parsing_start);
        versionMask[data_idx]      <== inStartEnd()(State[data_idx].parsing_start);
        target_start_counter        += startLineMask[data_idx] - targetMask[data_idx] - versionMask[data_idx];

        // Get the version bytes
        target_end_counter          += startLineMask[data_idx] - versionMask[data_idx];
        version_end_counter         += startLineMask[data_idx];
"#;
            }
            HttpData::Response(_) => {
                circuit_buffer += r#"
        // Check remaining version bytes
        if(data_idx < versionLen) {
            versionIsEqual[data_idx] <== IsEqual()([data[data_idx], version[data_idx]]);
            versionIsEqual[data_idx] === 1;
        }

        // Get the status bytes
        startLineMask[data_idx]    <== inStartLine()(State[data_idx].parsing_start);
        statusMask[data_idx]       <== inStartMiddle()(State[data_idx].parsing_start);
        messageMask[data_idx]      <== inStartEnd()(State[data_idx].parsing_start);
        status_start_counter        += startLineMask[data_idx] - statusMask[data_idx] - messageMask[data_idx];

        // Get the message bytes
        status_end_counter          += startLineMask[data_idx] - messageMask[data_idx];
        message_end_counter         += startLineMask[data_idx];
"#;
            }
        }
    }

    // Header matches
    {
        for (i, _header) in data.headers().iter().enumerate() {
            circuit_buffer += &format!("        headerNameValueMatch{}[data_idx] <== HeaderFieldNameValueMatch(DATA_BYTES, headerNameLen{}, headerValueLen{})(data, header{}, value{}, 100, data_idx);\n", i + 1,i + 1,i + 1,i + 1,i + 1);
            circuit_buffer += &format!(
                "        hasMatchedHeaderValue{} += headerNameValueMatch{}[data_idx];\n",
                i + 1,
                i + 1
            );
        }
    }

    // debugging
    if debug {
        circuit_buffer += r#"
        // Debugging
        log("State[", data_idx, "].parsing_start      ", "= ", State[data_idx].parsing_start);
        log("State[", data_idx, "].parsing_header     ", "= ", State[data_idx].parsing_header);
        log("State[", data_idx, "].parsing_field_name ", "= ", State[data_idx].parsing_field_name);
        log("State[", data_idx, "].parsing_field_value", "= ", State[data_idx].parsing_field_value);
        log("State[", data_idx, "].parsing_body       ", "= ", State[data_idx].parsing_body);
        log("State[", data_idx, "].line_status        ", "= ", State[data_idx].line_status);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
"#;
    }

    circuit_buffer += "   }";

    // debugging
    if debug {
        circuit_buffer += r#"
    // Debugging
    log("State[", DATA_BYTES, "].parsing_start      ", "= ", State[DATA_BYTES-1].next_parsing_start);
    log("State[", DATA_BYTES, "].parsing_header     ", "= ", State[DATA_BYTES-1].next_parsing_header);
    log("State[", DATA_BYTES, "].parsing_field_name ", "= ", State[DATA_BYTES-1].parsing_field_name);
    log("State[", DATA_BYTES, "].parsing_field_value", "= ", State[DATA_BYTES-1].parsing_field_value);
    log("State[", DATA_BYTES, "].parsing_body       ", "= ", State[DATA_BYTES-1].next_parsing_body);
    log("State[", DATA_BYTES, "].line_status        ", "= ", State[DATA_BYTES-1].next_line_status);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

"#;
    }

    // Get the output body bytes
    {
        if let HttpData::Response(_) = data {
            circuit_buffer += r#"
    signal bodyStartingIndex[DATA_BYTES];
    signal isZeroMask[DATA_BYTES];
    signal isPrevStartingIndex[DATA_BYTES];
    bodyStartingIndex[0] <== 0;
    isZeroMask[0] <== IsZero()(bodyMask[0]);
    for (var i=1 ; i < DATA_BYTES; i++) {
        isZeroMask[i] <== IsZero()(bodyMask[i]);
        isPrevStartingIndex[i] <== IsZero()(bodyStartingIndex[i-1]);
        bodyStartingIndex[i] <== bodyStartingIndex[i-1] + i * (1-isZeroMask[i]) * isPrevStartingIndex[i];
    }

    body <== SelectSubArray(DATA_BYTES, maxContentLength)(bodyMask, bodyStartingIndex[DATA_BYTES-1]+1, DATA_BYTES - bodyStartingIndex[DATA_BYTES-1]);
"#;
        }
    }

    if debug {
        circuit_buffer += r#"
    for(var i = 0; i < maxContentLength; i++) {
        log("body[", i, "] = ", body[i]);
    }
"#;
    }

    // Verify all start line has matched
    {
        match data {
            HttpData::Request(_) => {
                circuit_buffer += r#"
    // Verify method had correct length
    methodLen === target_start_counter - 1;

    // Check target is correct by substring match and length check
    // TODO: change r
    signal targetMatch <== SubstringMatchWithIndex(DATA_BYTES, targetLen)(data, target, 100, target_start_counter);
    targetMatch        === 1;
    targetLen          === target_end_counter - target_start_counter - 1;

    // Check version is correct by substring match and length check
    // TODO: change r
    signal versionMatch <== SubstringMatchWithIndex(DATA_BYTES, versionLen)(data, version, 100, target_end_counter);
    versionMatch === 1;
    // -2 here for the CRLF
    versionLen   === version_end_counter - target_end_counter - 2;
"#;
            }
            HttpData::Response(_) => {
                circuit_buffer += r#"
    // Verify version had correct length
    versionLen === status_start_counter - 1;

    // Check status is correct by substring match and length check
    // TODO: change r
    signal statusMatch <== SubstringMatchWithIndex(DATA_BYTES, statusLen)(data, status, 100, status_start_counter);
    statusMatch        === 1;
    statusLen          === status_end_counter - status_start_counter - 1;

    // Check message is correct by substring match and length check
    // TODO: change r
    signal messageMatch <== SubstringMatchWithIndex(DATA_BYTES, messageLen)(data, message, 100, status_end_counter);
    messageMatch        === 1;
    // -2 here for the CRLF
    messageLen          === message_end_counter - status_end_counter - 2;
"#;
            }
        }
    }

    // Verify all headers have matched
    {
        for (i, _header) in data.headers().iter().enumerate() {
            circuit_buffer += &format!("    hasMatchedHeaderValue{} === 1;\n", i + 1);
        }
    }
    // End file
    circuit_buffer += "\n}";

    // write circuits to file
    let mut file_path = std::env::current_dir()?;
    file_path.push("circuits");
    file_path.push("main");

    // create dir if doesn't exist
    create_dir_all(&file_path)?;

    file_path.push(format!("{}.circom", output_filename));

    fs::write(&file_path, circuit_buffer)?;

    println!("Code generated at: {}", file_path.display());

    Ok(())
}

fn parse_http_file(
    locfile: &HttpData,
    input: Vec<u8>,
) -> Result<(HttpData, Vec<u8>), Box<dyn std::error::Error>> {
    let input_string = String::from_utf8(input)?;

    let parts: Vec<&str> = input_string.split("\r\n\r\n").collect();
    assert!(parts.len() <= 2);

    let mut body = vec![];
    if parts.len() == 2 {
        body = parts[1].as_bytes().to_vec();
    }

    let headers: Vec<&str> = parts[0].split("\r\n").collect();
    let start_line: Vec<&str> = headers[0].split(" ").collect();
    assert_eq!(start_line.len(), 3);

    let (_, headers) = headers.split_at(1);
    let mut headers_map = HashMap::<String, String>::new();
    let re = Regex::new(r":\s(.+)").unwrap();
    for &header in headers {
        let key_value: Vec<&str> = re.split(header).collect();
        assert_eq!(key_value.len(), 2);
        headers_map.insert(key_value[0].to_string(), key_value[1].to_string());
    }

    let http_data = match locfile {
        HttpData::Request(_) => HttpData::Request(Request {
            method: start_line[0].to_string(),
            target: start_line[1].to_string(),
            version: start_line[2].to_string(),
            headers: headers_map,
        }),
        HttpData::Response(_) => HttpData::Response(Response {
            version: start_line[0].to_string(),
            status: start_line[1].to_string(),
            message: start_line[2].to_string(),
            headers: headers_map,
        }),
    };

    Ok((http_data, body))
}

fn build_circuit_config(
    args: &ExtractorArgs,
    lockfile: &HttpData,
) -> Result<CircomkitCircuitsInput, Box<dyn std::error::Error>> {
    let input = read_input_file_as_bytes(WitnessType::Http, args.input_file.clone())?;

    let (_, http_body) = parse_http_file(lockfile, input.clone())?;

    let circuit_template_name = match lockfile {
        HttpData::Request(_) => String::from("LockHTTPRequest"),
        HttpData::Response(_) => String::from("LockHTTPResponse"),
    };

    let mut params = vec![input.len()];

    match lockfile {
        HttpData::Request(request) => {
            params.push(request.method.len());
            params.push(request.target.len());
            params.push(request.version.len());
            for (key, value) in request.headers.iter() {
                params.push(key.len());
                params.push(value.len());
            }
        }
        HttpData::Response(response) => {
            params.push(http_body.len());
            params.push(response.version.len());
            params.push(response.status.len());
            params.push(response.message.len());
            for (key, value) in response.headers.iter() {
                params.push(key.len());
                params.push(value.len());
            }
        }
    }

    Ok(CircomkitCircuitsInput {
        file: format!("main/{}", args.output_filename),
        template: circuit_template_name,
        params,
    })
}

pub fn http_circuit(args: ExtractorArgs) -> Result<(), Box<dyn Error>> {
    let data = std::fs::read(&args.lockfile)?;

    let http_data: HttpData = serde_json::from_slice(&data)?;

    build_http_circuit(&http_data, &args.output_filename, args.debug)?;

    let circomkit_circuit_input = build_circuit_config(&args, &http_data)?;

    write_circuit_config(args.circuit_name, &circomkit_circuit_input)?;

    Ok(())
}
