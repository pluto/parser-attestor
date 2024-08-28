use clap::{Parser, Subcommand};
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "witness")]
struct Args {
    #[command(subcommand)]
    command: Command,

    /// Output directory (will be created if it doesn't exist)
    #[arg(global = true, short, long, default_value = ".")]
    output_dir: PathBuf,

    /// Output filename (will be created if it doesn't exist)
    #[arg(global = true, short, long, default_value = "output.json")]
    output_filename: String,
}

#[derive(Subcommand, Debug)]
enum Command {
    Json {
        /// Path to the JSON file
        #[arg(short, long)]
        input_file: PathBuf,

        /// Keys to extract (can be specified multiple times)
        #[arg(short, long)]
        keys: Vec<String>,
    },
    Http {
        /// Path to the HTTP request file
        #[arg(short, long)]
        input_file: PathBuf,
    },
}

#[derive(serde::Serialize)]
pub struct Witness {
    #[serde(flatten)]
    keys: serde_json::Map<String, Value>,
    data: Vec<u8>,
}

pub fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let (data, keys_map) = match &args.command {
        Command::Json { input_file, keys } => {
            let data = std::fs::read(input_file)?;
            let mut keys_map = serde_json::Map::new();
            for (index, key) in keys.iter().enumerate() {
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
            (data, keys_map)
        }
        Command::Http { input_file } => {
            let data = std::fs::read(input_file)?;
            let keys_map = serde_json::Map::new();
            (data, keys_map)
        }
    };

    let witness = Witness {
        keys: keys_map,
        data: data.clone(),
    };

    if !args.output_dir.exists() {
        std::fs::create_dir_all(&args.output_dir)?;
    }

    let output_file = args.output_dir.join(args.output_filename);
    let mut file = std::fs::File::create(output_file)?;
    file.write_all(serde_json::to_string_pretty(&witness)?.as_bytes())?;

    // Prepare lines to print
    let mut lines = Vec::new();
    match &args.command {
        Command::Json { keys, .. } => {
            lines.push(String::from("Key lengths:"));
            for (index, key) in keys.iter().enumerate() {
                lines.push(format!("key{} length: {}", index + 1, key.len()));
            }
        }
        Command::Http { .. } => {
            lines.push(String::from("HTTP request processed"));
        }
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
