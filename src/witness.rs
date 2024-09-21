use crate::{
    codegen::{
        http::HttpData,
        json::{json_max_stack_height, Lockfile},
    },
    ExtractorWitnessArgs, FileType, ParserWitnessArgs,
};
use std::{collections::HashMap, io::Write, path::Path};

#[derive(serde::Serialize)]
pub struct ParserWitness {
    data: Vec<u8>,
}

#[derive(serde::Serialize)]
pub struct JsonExtractorWitness {
    data: Vec<u8>,

    #[serde(flatten)]
    keys: HashMap<String, Vec<u8>>,
}

#[derive(serde::Serialize)]
pub struct HttpExtractorWitness {
    data: Vec<u8>,

    #[serde(flatten)]
    http_data: HttpData,
}

fn print_boxed_output(lines: Vec<String>) {
    // Determine the maximum length of the lines
    let max_length = lines.iter().map(|line| line.len()).max().unwrap_or(0);

    // Characters for the box
    let top_border = format!("┌{}┐", "─".repeat(max_length + 2));
    let bottom_border = format!("└{}┘", "─".repeat(max_length + 2));

    // Print the box with content
    println!("{}", top_border);
    for line in lines {
        println!("│ {:<width$} │", line, width = max_length);
    }
    println!("{}", bottom_border);
}

pub fn read_input_file_as_bytes(
    file_type: &FileType,
    file_path: &Path,
) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    match file_type {
        FileType::Json | FileType::Extended => Ok(std::fs::read(file_path)?),
        FileType::Http => {
            let mut data = std::fs::read(file_path)?;
            let mut i = 0;
            // convert LF to CRLF
            while i < data.len() {
                if data[i] == 10 && (i == 0 || data[i - 1] != 13) {
                    data.insert(i, 13);
                    i += 2;
                } else {
                    i += 1;
                }
            }
            Ok(data)
        }
    }
}

pub fn parser_witness(args: ParserWitnessArgs) -> Result<(), Box<dyn std::error::Error>> {
    let data = read_input_file_as_bytes(&args.subcommand, &args.input_file)?;

    let witness = ParserWitness { data: data.clone() };

    let mut output_dir = std::env::current_dir()?;
    output_dir.push("inputs");
    output_dir.push(args.circuit_name);

    if !output_dir.exists() {
        std::fs::create_dir_all(&output_dir)?;
    }

    let output_file = output_dir.join("inputs.json");
    let mut file = std::fs::File::create(output_file)?;

    file.write_all(serde_json::to_string_pretty(&witness)?.as_bytes())?;

    // Prepare lines to print
    let mut lines = Vec::new();
    lines.push(format!("Data length: {}", data.len()));

    if args.subcommand == FileType::Json {
        lines.push(format!(
            "Max stack height: {}",
            json_max_stack_height(&data)
        ))
    }
    // Print the output inside a nicely formatted box
    print_boxed_output(lines);

    Ok(())
}

fn json_extractor_witness(args: ExtractorWitnessArgs) -> Result<(), Box<dyn std::error::Error>> {
    // read input and lockfile
    let input_data = read_input_file_as_bytes(&args.subcommand, &args.input_file)?;

    let lockfile_data = std::fs::read(&args.lockfile)?;
    let lockfile: Lockfile = serde_json::from_slice(&lockfile_data)?;

    // create extractor witness data
    let witness = JsonExtractorWitness {
        data: input_data.clone(),
        keys: lockfile.as_bytes(),
    };

    // create output dir if not exists
    let mut output_dir = std::env::current_dir()?;
    output_dir.push("inputs");
    output_dir.push(&args.circuit_name);
    if !output_dir.exists() {
        std::fs::create_dir_all(&output_dir)?;
    }

    // write input file
    let output_file = output_dir.join("inputs.json");
    let mut file = std::fs::File::create(output_file)?;
    file.write_all(serde_json::to_string_pretty(&witness)?.as_bytes())?;

    // Prepare lines to print
    let mut lines = Vec::new();
    lines.push(format!("Data length: {}", input_data.len()));
    lines.push(format!(
        "Max stack height: {}",
        json_max_stack_height(&input_data)
    ));

    // Print the output inside a nicely formatted box
    print_boxed_output(lines);

    Ok(())
}

fn http_extractor_witness(args: ExtractorWitnessArgs) -> Result<(), Box<dyn std::error::Error>> {
    // read input and lockfile
    let input_data = read_input_file_as_bytes(&args.subcommand, &args.input_file)?;

    let lockfile_data = std::fs::read(&args.lockfile)?;
    let http_data: HttpData = serde_json::from_slice(&lockfile_data)?;

    // create witness data
    let witness = HttpExtractorWitness {
        data: input_data.clone(),
        http_data,
    };

    // create witness dir
    let mut output_dir = std::env::current_dir()?;
    output_dir.push("inputs");
    output_dir.push(&args.circuit_name);
    if !output_dir.exists() {
        std::fs::create_dir_all(&output_dir)?;
    }

    // write witness to file
    let output_file = output_dir.join("inputs.json");
    let mut file = std::fs::File::create(output_file)?;
    file.write_all(serde_json::to_string_pretty(&witness)?.as_bytes())?;

    // Prepare lines to print
    let mut lines = Vec::new();
    lines.push(format!("Data length: {}", input_data.len()));

    // Print the output inside a nicely formatted box
    print_boxed_output(lines);

    Ok(())
}

pub fn extractor_witness(args: ExtractorWitnessArgs) -> Result<(), Box<dyn std::error::Error>> {
    match args.subcommand {
        FileType::Json => json_extractor_witness(args),
        FileType::Http => http_extractor_witness(args),
        FileType::Extended => todo!(),
    }
}
