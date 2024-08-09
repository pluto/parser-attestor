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
        data: data.clone(),
    };

    if !args.output_dir.exists() {
        std::fs::create_dir_all(&args.output_dir)?;
    }

    let output_file = args.output_dir.join(args.filename);
    let mut file = std::fs::File::create(output_file)?;
    file.write_all(serde_json::to_string_pretty(&witness)?.as_bytes())?;

    // Prepare lines to print
    let mut lines = Vec::new();
    lines.push(String::from("Key lengths:"));
    for (index, key) in args.keys.iter().enumerate() {
        lines.push(format!("key{} length: {}", index + 1, key.len()));
    }
    lines.push(format!("Data length: {}", data.len()));

    // Print the output inside a nicely formatted box
    print_boxed_output(lines);

    Ok(())
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
