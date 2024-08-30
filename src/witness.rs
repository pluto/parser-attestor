use super::*;
use std::io::Write;

#[derive(serde::Serialize)]
pub struct Witness(Vec<u8>);

pub fn witness(args: WitnessArgs) -> Result<(), Box<dyn std::error::Error>> {
    let data = match &args.subcommand {
        WitnessSubcommand::Json => std::fs::read(args.input_file)?,
        WitnessSubcommand::Http => {
            let mut data = std::fs::read(args.input_file)?;
            let mut i = 0;
            while i < data.len() {
                if data[i] == 10 && (i == 0 || data[i - 1] != 13) {
                    data.insert(i, 13);
                    i += 2;
                } else {
                    i += 1;
                }
            }
            data
        }
    };

    let witness = Witness(data.clone());

    if !args.output_dir.exists() {
        std::fs::create_dir_all(&args.output_dir)?;
    }

    let output_file = args.output_dir.join(args.output_filename);
    let mut file = std::fs::File::create(output_file)?;
    file.write_all(serde_json::to_string_pretty(&witness)?.as_bytes())?;

    // Prepare lines to print
    let mut lines = Vec::new();
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
