use std::io::Write;

pub const KEYS: &[&[u8]] = &[
    b"\"glossary\"".as_slice(),
    b"\"GlossDiv\"".as_slice(),
    b"\"title\"".as_slice(),
];
pub const DATA: &[u8] = include_bytes!("../../example.json");

#[derive(serde::Serialize)]
pub struct Witness {
    num_keys: usize,
    keys: Vec<Vec<u8>>, // Actually will contain bits on the inside vec
    num_data_bits: usize,
    data: Vec<u8>, // Actually will always be bits
}

pub fn main() {
    // Properly serialize information about the keys we want to extract
    let mut max_num_keys = 0;
    let mut max_num_key_bits = 0;
    let mut keys = vec![];
    for &key in KEYS {
        let key = get_bits(key)
            .into_iter()
            .map(|b| b as u8)
            .collect::<Vec<u8>>();
        if key.len() > max_num_key_bits {
            max_num_key_bits = key.len();
        }
        keys.push(key);
        max_num_keys += 1;
    }
    println!("MAX_NUM_KEYS: {max_num_keys}");
    println!("MAX_NUM_KEY_BITS: {max_num_key_bits}");

    // Enforce that each key comes in as af fixed length (TODO: we need to make sure we encode this somehow, perhaps we pass in a vector of key lengths)
    for key in &mut keys {
        key.extend(vec![0; max_num_key_bits - key.len()]);
    }

    // Properly serialize information about the data we extract from
    let data = get_bits(DATA)
        .into_iter()
        .map(|b| b as u8)
        .collect::<Vec<u8>>();
    println!("MAX_NUM_DATA_BITS: {}", data.len());

    // Create a witness file as `input.json`
    let witness = Witness {
        num_keys: max_num_keys, // For now we can set this to be the same
        keys,
        num_data_bits: data.len(), // For now we can set this to be the same
        data,
    };
    let mut file = std::fs::File::create("circuit/input.json").unwrap();
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
        let bits = get_bits(DATA);
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
