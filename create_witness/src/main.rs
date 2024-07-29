use std::io::Write;

pub const BYTES: &[u8] = include_bytes!("../../example.json");

#[derive(serde::Serialize)]
pub struct Witness {
    data: Vec<u8>, // Actually will always be bits
}

pub fn main() {
    let bits = get_bits(BYTES);
    println!("length: {}", bits.len());
    let witness = Witness {
        data: bits.into_iter().map(|b| b as u8).collect::<Vec<u8>>(),
    };
    let mut file = std::fs::File::create("witness.json").unwrap();
    file.write_all(serde_json::to_string_pretty(&witness).unwrap().as_bytes())
        .unwrap();
}

fn get_bits(bytes: &[u8]) -> Vec<bool> {
    bytes
        .iter()
        .flat_map(|&byte| {
            (0..8)
                .rev()
                .map(move |i| ((byte.to_be_bytes()[0] >> i) & 1) == 1) // ensure this is all big-endian
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    // Use example.json which has first two ASCII chars: `{` and `\n`
    // ASCII code for `{` 01111011
    // ASCII code for `\n` 00001010
    #[test]
    fn test_get_bits() {
        let bits = get_bits(BYTES);
        #[allow(clippy::inconsistent_digit_grouping)]
        let compare_bits: Vec<bool> = vec![0, 1, 1, 1, 1, 0, 1, 1_, 0, 0, 0, 0, 1, 0, 1, 0]
            .into_iter()
            .map(|x| x == 1)
            .collect();
        bits.iter()
            .zip(compare_bits.iter())
            .for_each(|(x, y)| assert_eq!(x, y));
    }
}
