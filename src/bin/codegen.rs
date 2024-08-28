use clap::Parser;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "codegen")]
struct Args {
    /// Path to the JSON file
    #[arg(short, long)]
    json_file: PathBuf,
}

#[derive(Debug, Deserialize)]
enum ValueType {
    #[serde(rename = "string")]
    String,
    #[serde(rename = "number")]
    Number,
    #[serde(skip_deserializing)]
    Array,
    #[serde(skip_deserializing)]
    ArrayElement,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
enum Key {
    String(String),
    Num(i64),
}

#[derive(Debug, Deserialize)]
struct Data {
    keys: Vec<Key>,
    value_type: ValueType,
}

const PRAGMA: &str = "pragma circom 2.1.9;\n\n";

fn extract_string(data: Data, cfb: &mut String) {
    *cfb += "template ExtractStringValue(DATA_BYTES, MAX_STACK_HEIGHT, ";
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => *cfb += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
            Key::Num(_) => *cfb += &format!("index{}, depth{}, ", i + 1, i + 1),
        }
    }
    *cfb += "maxValueLen) {\n";

    *cfb += "    signal input data[DATA_BYTES];\n\n";

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => *cfb += &format!("    signal input key{}[keyLen{}];\n", i + 1, i + 1),
            _ => (),
        }
    }

    *cfb += r#"
    signal output value[maxValueLen];

    signal value_starting_index[DATA_BYTES];
"#;

    // value_starting_index <== ExtractValue2(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, index3, depth3, index4, depth4, maxValueLen)(data, key1, key2);
    {
        *cfb += "    value_starting_index <== ExtractValue2(DATA_BYTES, MAX_STACK_HEIGHT, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *cfb += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
                Key::Num(_) => *cfb += &format!("index{}, depth{}, ", i + 1, i + 1),
            }
        }
        *cfb += "maxValueLen)(data, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *cfb += &format!("key{}, ", i + 1),
                _ => (),
            }
        }
        cfb.pop();
        cfb.pop();
        *cfb += ");\n";
    }

    *cfb += r#"
    log("value_starting_index", value_starting_index[DATA_BYTES-2]);
    // TODO: why +1 not required here,when required on all other string implss?
    value <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2]+1, maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value[i]);
    }
}
"#;
}

fn extract_number(data: Data, cfb: &mut String) {
    *cfb += "template ExtractNumValue(DATA_BYTES, MAX_STACK_HEIGHT, ";
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => *cfb += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
            Key::Num(_) => *cfb += &format!("index{}, depth{}, ", i + 1, i + 1),
        }
    }
    *cfb += "maxValueLen) {\n";

    *cfb += "    signal input data[DATA_BYTES];\n\n";

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => *cfb += &format!("    signal input key{}[keyLen{}];\n", i + 1, i + 1),
            _ => (),
        }
    }

    *cfb += r#"
    signal value_string[maxValueLen];
    signal output value;

    signal value_starting_index[DATA_BYTES];
"#;

    // value_starting_index <== ExtractValue2(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, index3, depth3, index4, depth4, maxValueLen)(data, key1, key2);
    {
        *cfb += "    value_starting_index <== ExtractValue2(DATA_BYTES, MAX_STACK_HEIGHT, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *cfb += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
                Key::Num(_) => *cfb += &format!("index{}, depth{}, ", i + 1, i + 1),
            }
        }
        *cfb += "maxValueLen)(data, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *cfb += &format!("key{}, ", i + 1),
                _ => (),
            }
        }
        cfb.pop();
        cfb.pop();
        *cfb += ");\n";
    }

    *cfb += r#"
    log("value_starting_index", value_starting_index[DATA_BYTES-2]);
    // TODO: why +1 not required here,when required on all other string implss?
    value_string <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2], maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value_string[i]);
    }

    signal number_value[maxValueLen];
    number_value[0] <== (value_string[0]-48);
    for (var i=1 ; i<maxValueLen ; i++) {
        number_value[i] <== number_value[i-1] * 10 + (value_string[i]-48);
    }

    value <== number_value[maxValueLen-1];
"#;
}

fn parse_json_request(data: Data) -> Result<(), Box<dyn std::error::Error>> {
    let mut cfb = String::new();
    cfb += PRAGMA;
    cfb += "include \"./fetcher.circom\";\n\n";

    cfb += "template ExtractValue2(DATA_BYTES, MAX_STACK_HEIGHT, ";
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => cfb += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
            Key::Num(_) => cfb += &format!("index{}, depth{}, ", i + 1, i + 1),
        }
    }
    cfb += "maxValueLen) {\n";

    cfb += "    signal input data[DATA_BYTES];\n\n";

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => cfb += &format!("    signal input key{}[keyLen{}];\n", i + 1, i + 1),
            _ => (),
        }
    }

    cfb += r#"
    signal output value_starting_index[DATA_BYTES];

    signal mask[DATA_BYTES];
    // mask[0] <== 0;

    var logDataLen = log2Ceil(DATA_BYTES);

    component State[DATA_BYTES];
    State[0] = StateUpdate(MAX_STACK_HEIGHT);
    State[0].byte           <== data[0];
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        State[0].stack[i]   <== [0,0];
    }
    State[0].parsing_string <== 0;
    State[0].parsing_number <== 0;

    signal parsing_key[DATA_BYTES];
    signal parsing_value[DATA_BYTES];
"#;

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => {
                cfb += &format!("    signal parsing_object{}_value[DATA_BYTES];\n", i + 1)
            }
            Key::Num(_) => cfb += &format!("    signal parsing_array{}[DATA_BYTES];\n", i + 1),
        }
    }

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => cfb += &format!("    signal is_key{}_match[DATA_BYTES];\n    signal is_key{}_match_for_value[DATA_BYTES];\n    is_key{}_match_for_value[0] <== 0;\n    signal is_next_pair_at_depth{}[DATA_BYTES];\n", i+1, i+1, i+1, i+1),
            _ => (),
        }
    }

    cfb += r#"
    signal is_value_match[DATA_BYTES];
    is_value_match[0] <== 0;
    signal value_mask[DATA_BYTES];
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx-1, "].stack[", i,"]    ", "= [",State[data_idx-1].next_stack[i][0], "][", State[data_idx-1].next_stack[i][1],"]" );
        }
        log("State[", data_idx-1, "].byte", "= ", data[data_idx-1]);
        log("State[", data_idx-1, "].parsing_string", "= ", State[data_idx-1].next_parsing_string);
        log("State[", data_idx-1, "].parsing_number", "= ", State[data_idx-1].next_parsing_number);

        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        // - parsing key
        // - parsing value (different for string/numbers and array)
        // - key match (key 1, key 2)
        // - is next pair
        // - is key match for value
        // - value_mask
        // - mask

        parsing_key[data_idx-1] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing key:", parsing_key[data_idx]);

"#;

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => {
                cfb += &format!("        parsing_object{}_value[data_idx-1] <== InsideObjectAtDepth(MAX_STACK_HEIGHT, depth{})(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);\n", i+1, i+1);
            }
            Key::Num(_) => {
                cfb += &format!("        parsing_array{}[data_idx-1] <== InsideArrayIndexAtDepth(MAX_STACK_HEIGHT, index{}, depth{})(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);\n", i+1, i+1, i+1);
            }
        }
    }

    cfb += &format!(
        "        parsing_value[data_idx-1] <== MultiAND({})([",
        data.keys.len()
    );

    for (i, key) in data.keys.iter().take(data.keys.len() - 1).enumerate() {
        match key {
            Key::String(_) => cfb += &format!("parsing_object{}_value[data_idx-1], ", i + 1),
            Key::Num(_) => cfb += &format!("parsing_array{}[data_idx-1], ", i + 1),
        }
    }
    match data.keys[data.keys.len() - 1] {
        Key::String(_) => {
            cfb += &format!("parsing_object{}_value[data_idx-1]]);\n", data.keys.len())
        }
        Key::Num(_) => cfb += &format!("parsing_array{}[data_idx-1]]);\n)", data.keys.len()),
    }

    // optional debug logs
    cfb += "        // log(\"parsing value:\", ";
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => cfb += &format!("parsing_object{}_value[data_idx-1], ", i + 1),
            Key::Num(_) => cfb += &format!("parsing_array{}[data_idx-1], ", i + 1),
        }
    }
    cfb += "parsing_value[data_idx-1]);\n\n";

    let mut num_objects = 0;
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => {
                num_objects += 1;
                cfb += &format!("        is_key{}_match[data_idx-1] <== KeyMatchAtDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen{}, depth{})(data, key{}, 100, data_idx-1, parsing_key[data_idx-1], State[data_idx-1].stack);\n", i+1, i+1, i+1, i+1);
                cfb += &format!("        is_next_pair_at_depth{}[data_idx-1] <== NextKVPairAtDepth(MAX_STACK_HEIGHT, depth{})(State[data_idx-1].stack, data[data_idx-1]);\n", i+1, i+1);
                cfb += &format!("        is_key{}_match_for_value[data_idx] <== Mux1()([is_key{}_match_for_value[data_idx-1] * (1-is_next_pair_at_depth{}[data_idx-1]), is_key{}_match[data_idx-1] * (1-is_next_pair_at_depth{}[data_idx-1])], is_key{}_match[data_idx-1]);\n", i+1, i+1, i+1, i+1, i+1, i+1);
            }
            _ => (),
        }
    }

    cfb += &format!(
        "        is_value_match[data_idx] <== MultiAND({})([",
        num_objects
    );
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => cfb += &format!("is_key{}_match_for_value[data_idx], ", i + 1),
            Key::Num(_) => (),
        }
    }

    // remove last 2 chars `, ` from string buffer
    cfb.pop();
    cfb.pop();
    cfb += "]);\n";

    cfb += r#"        // log("is_value_match", is_value_match[data_idx]);

        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx-1] <== data[data_idx-1] * parsing_value[data_idx-1];
        mask[data_idx-1] <== value_mask[data_idx-1] * is_value_match[data_idx];
        log("mask", mask[data_idx-1]);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES-1, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES-1, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES-1, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    // signal value_starting_index[DATA_BYTES];
    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES-1 ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }
"#;

    // template ends
    cfb += "}\n";

    match data.value_type {
        ValueType::String => extract_string(data, &mut cfb),
        ValueType::Number => extract_number(data, &mut cfb),
        _ => unimplemented!(),
    }

    // write circuits to file
    let mut file_path = std::env::current_dir()?;
    file_path.push("circuits");
    file_path.push("extractor.circom");

    println!("file_path: {:?}", file_path);
    fs::write(file_path, cfb)?;
    Ok(())
}

pub fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let data = std::fs::read(&args.json_file)?;
    let json_data: Data = serde_json::from_slice(&data)?;
    parse_json_request(json_data)?;
    Ok(())
}
