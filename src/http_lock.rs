use super::*;

#[derive(Debug, Serialize, Deserialize)]
struct HttpData {
    request: Request,
    response: Response,
}

#[derive(Debug, Serialize, Deserialize)]
struct Request {
    method: String,
    target: String,
    version: String,
    headers: Vec<(String, String)>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Response {
    version: String,
    status: String,
    message: String,
    headers: Vec<(String, serde_json::Value)>,
}

use std::fs::{self, create_dir_all};

const PRAGMA: &str = "pragma circom 2.1.9;\n\n";

fn request_locker_circuit(
    data: HttpData,
    output_filename: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut circuit_buffer = String::new();
    circuit_buffer += PRAGMA;
    circuit_buffer += "include \"../http/interpreter.circom\";\n";
    circuit_buffer += "include \"../http/parser/machine.circom\";\n";
    circuit_buffer += "include \"../utils/bytes.circom\";\n";
    circuit_buffer += "include \"../utils/search.circom\";\n";
    circuit_buffer += "include \"circomlib/circuits/gates.circom\";\n";
    circuit_buffer += "include \"@zk-email/circuits/utils/array.circom\";\n\n";

    // template LockHTTP(DATA_BYTES, beginningLen, middleLen, finalLen, headerNameLen1, headerValueLen1, ...) {
    {
        circuit_buffer += "template LockHTTP(DATA_BYTES, beginningLen, middleLen, finalLen,";
        for (i, _header) in data.request.headers.iter().enumerate() {
            circuit_buffer += &format!("keyLen{}, depth{}, ", i + 1, i + 1);
        }
    }

    /*
    signal input data[DATA_BYTES];

    signal input key1[keyLen1];
    signal input key3[keyLen3];
     */
    {
        circuit_buffer += "    signal input data[DATA_BYTES];\n\n";

        for (i, _header) in data.request.headers.iter().enumerate() {
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

    // Setup for parsing the start line
    {
        circuit_buffer += r#"
    // Check first beginning byte
    signal beginningIsEqual[beginningLen];
    beginningIsEqual[0] <== IsEqual()([data[0],beginning[0]]);
    beginningIsEqual[0] === 1;

    // Setup to check middle bytes
    signal startLineMask[DATA_BYTES];
    signal middleMask[DATA_BYTES];
    signal finalMask[DATA_BYTES];

    var middle_start_counter = 1;
    var middle_end_counter = 1;
    var final_end_counter = 1;
"#;
    }

    circuit_buffer += r#"
    component State[DATA_BYTES];
    State[0] = StateUpdate();
    State[0].byte           <== data[0];
    State[0].parsing_start  <== 1;
    State[0].parsing_header <== 0;
    State[0].parsing_field_name <== 0;
    State[0].parsing_field_value <== 0;
    State[0].parsing_body   <== 0;
    State[0].line_status    <== 0;

"#;

    // Create header match signals
    {
        for (i, _header) in data.request.headers.iter().enumerate() {
            circuit_buffer += &format!("    signal headerNameValueMatch{}[DATA_BYTES];\n", i + 1);
            circuit_buffer += &format!("    headerNameValueMatch{}[DATA_BYTES] <== 0;\n", i + 1);
            circuit_buffer += &format!("    var hasMatchedHeaderValue{} = 0", i + 1);
        }
    }
    circuit_buffer += "\n";

    circuit_buffer += r#"
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate();
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].parsing_start  <== State[data_idx - 1].next_parsing_start;
        State[data_idx].parsing_header <== State[data_idx - 1].next_parsing_header;
        State[data_idx].parsing_field_name <== State[data_idx-1].next_parsing_field_name;
        State[data_idx].parsing_field_value <== State[data_idx-1].next_parsing_field_value;
        State[data_idx].parsing_body   <== State[data_idx - 1].next_parsing_body;
        State[data_idx].line_status    <== State[data_idx - 1].next_line_status;

"#;
    // Start line matches
    {
        circuit_buffer += r#"
        // Check remaining beginning bytes
        if(data_idx < beginningLen) {
            beginningIsEqual[data_idx] <== IsEqual()([data[data_idx], beginning[data_idx]]);
            beginningIsEqual[data_idx] === 1;
        }

        // Middle
        startLineMask[data_idx] <== inStartLine()(State[data_idx].parsing_start);
        middleMask[data_idx] <==  inStartMiddle()(State[data_idx].parsing_start);
        finalMask[data_idx] <== inStartEnd()(State[data_idx].parsing_start);
        middle_start_counter += startLineMask[data_idx] - middleMask[data_idx] - finalMask[data_idx];
        // The end of middle is the start of the final 
        middle_end_counter += startLineMask[data_idx] - finalMask[data_idx];
        final_end_counter += startLineMask[data_idx];

"#;
    }

    // Header matches
    {
        for (i, _header) in data.request.headers.iter().enumerate() {
            circuit_buffer += &format!("        headerNameValueMatch{}[data_idx] <== HeaderFieldNameValueMatch(DATA_BYTES, headerNameLen{}, headerValueLen{})(data, header{}, value{}, 100, data_idx);\n", i + 1,i + 1,i + 1,i + 1,i + 1);
            circuit_buffer += &format!(
                "        hasMatchedHeaderValue{} += headerNameValueMatch{}[data_idx];\n",
                i + 1,
                i + 1
            );
        }
    }

    // debugging
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

    circuit_buffer += "   }";

    // debugging
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
    // Verify all start line has matched
    {
        circuit_buffer += r#"
    // Additionally verify beginning had correct length
    beginningLen === middle_start_counter - 1;

    // Check middle is correct by substring match and length check
    // TODO: change r
    signal middleMatch <== SubstringMatchWithIndex(DATA_BYTES, middleLen)(data, middle, 100, middle_start_counter);
    middleMatch === 1;
    middleLen === middle_end_counter - middle_start_counter - 1;
    
    // Check final is correct by substring match and length check
    // TODO: change r
    signal finalMatch <== SubstringMatchWithIndex(DATA_BYTES, finalLen)(data, final, 100, middle_end_counter);
    finalMatch === 1;
    // -2 here for the CRLF
    finalLen === final_end_counter - middle_end_counter - 2;
        
"#;
    }

    // Verify all headers have matched
    {
        for (i, _header) in data.request.headers.iter().enumerate() {
            circuit_buffer += &format!("    hasMatchedHeaderValue{} === 1;\n", i + 1);
        }
    }

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

// TODO: This needs to codegen a circuit now.
pub fn http_lock(args: HttpLockArgs) -> Result<(), Box<dyn Error>> {
    let data = std::fs::read(&args.lockfile)?;
    let http_data: HttpData = serde_json::from_slice(&data)?;

    request_locker_circuit(http_data, args.output_filename)?;

    Ok(())
}
