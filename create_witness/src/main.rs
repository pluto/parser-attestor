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
    key_sizes: Vec<usize>,
    keys: Vec<Vec<u8>>,
    num_data_bits: usize,
    data: Vec<u8>,
}

pub fn main() {
    // Properly serialize information about the keys we want to extract
    let mut max_num_keys = 0;
    let mut max_num_key_bytes = 0;
    let mut key_sizes = vec![];
    let mut keys = vec![];
    for &key in KEYS {
        let key_len = key.len();
        key_sizes.push(key_len);
        if key_len > max_num_key_bytes {
            max_num_key_bytes = key_len;
        }
        keys.push(key.to_vec());
        max_num_keys += 1;
    }
    println!("MAX_NUM_KEYS: {max_num_keys}");
    println!("MAX_NUM_KEY_BYTES: {max_num_key_bytes}");

    // Enforce that each key comes in as af fixed length (TODO: we need to make sure we encode this somehow, perhaps we pass in a vector of key lengths)
    for key in &mut keys {
        key.extend(vec![0; max_num_key_bytes - key.len()]);
    }

    // Properly serialize information about the data we extract from
    println!("MAX_NUM_DATA_BYTES: {}", DATA.len());

    // Create a witness file as `input.json`
    let witness = Witness {
        num_keys: max_num_keys, // For now we can set this to be the same
        key_sizes,
        keys,
        num_data_bits: DATA.len(), // For now we can set this to be the same
        data: DATA.to_vec(),
    };
    let mut file = std::fs::File::create("circuit/witness.json").unwrap();
    file.write_all(serde_json::to_string_pretty(&witness).unwrap().as_bytes())
        .unwrap();
}

// fn get_bits(bytes: &[u8]) -> Vec<bool> {
//     bytes
//         .iter()
//         .flat_map(|&byte| {
//             (0..8)
//                 .rev()
//                 .map(move |i| ((byte.to_be_bytes()[0] >> i) & 1) == 1) // ensure this is all big-endian
//         })
//         .collect()
// }

// #[cfg(test)]
// mod tests {
//     use super::*;
//     // Use example.json which has first two ASCII chars: `{` and `\n`
//     // ASCII code for `{` 01111011
//     // ASCII code for `\n` 00001010
//     #[test]
//     fn test_get_bits() {
//         let bits = get_bits(DATA);
//         #[allow(clippy::inconsistent_digit_grouping)]
//         let compare_bits: Vec<bool> = vec![0, 1, 1, 1, 1, 0, 1, 1_, 0, 0, 0, 0, 1, 0, 1, 0]
//             .into_iter()
//             .map(|x| x == 1)
//             .collect();
//         bits.iter()
//             .zip(compare_bits.iter())
//             .for_each(|(x, y)| assert_eq!(x, y));
//     }
// }
