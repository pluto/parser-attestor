use clap::Parser;
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "witness")]
struct Args {
    /// Path to the JSON file
    #[arg(short, long)]
    json_file: PathBuf,

    /// Keys to extract (can be specified multiple times)
    #[arg(short, long)]
    keys: Vec<String>,

    /// Output directory (will be created if it doesn't exist)
    #[arg(short, long, default_value = ".")]
    output_dir: PathBuf,

    /// Output filename (will be created if it doesn't exist)
    #[arg(short, long, default_value = "output.json")]
    filename: String,
}

#[derive(serde::Serialize)]
pub struct Witness {
    #[serde(flatten)]
    keys: serde_json::Map<String, Value>,
    data: Vec<u8>,
}

pub fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Read the JSON file
    let data = std::fs::read(&args.json_file)?;

    // Create a map to store keys
    let mut keys_map = serde_json::Map::new();
    for (index, key) in args.keys.iter().enumerate() {
        keys_map.insert(
            format!("key{}", index + 1),
            Value::Array(
                key.as_bytes()
                    .iter()
                    .map(|x| serde_json::json!(x))
                    .collect(),
            ),
        );
    }

    // Create a witness file as `input.json`
    let witness = Witness {
        keys: keys_map,
        data,
    };

    let output_file = args.output_dir.join(args.filename);
    let mut file = std::fs::File::create(output_file)?;
    file.write_all(serde_json::to_string_pretty(&witness)?.as_bytes())?;

    println!("Input file created successfully.");

    Ok(())
}
