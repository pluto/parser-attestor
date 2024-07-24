pub const EXAMPLE_JSON: &[u8] = include_bytes!("../example.json");
pub const VENMO_JSON: &[u8] = include_bytes!("../venmo_response.json");

pub struct Machine<const MATCH_LENGTH: usize> {
    pub key_byte_match: [u8; MATCH_LENGTH],
}

impl<const MATCH_LENGTH: usize> Machine<MATCH_LENGTH> {
    pub fn new(key_byte_match: [u8; MATCH_LENGTH]) -> Self {
        Machine { key_byte_match }
    }

    pub fn extract<'a>(&self, data_bytes: &'a [u8]) -> Option<&'a [u8]> {
        assert!(data_bytes.len() > MATCH_LENGTH);
        let mut flag = false;
        'outer: for i in 0..(data_bytes.len() - MATCH_LENGTH) {
            for j in 0..MATCH_LENGTH {
                if self.key_byte_match[j] ^ data_bytes[i..i + MATCH_LENGTH][j] != 0 {
                    continue 'outer;
                }
                flag = true;
            }
            if flag {
                let start_index = i + MATCH_LENGTH + 1;
                let mut value_length = 0;
                while data_bytes[start_index + value_length] != b"}"[0] {
                    value_length += 1;
                }
                return Some(&data_bytes[start_index..start_index + value_length]);
            } else {
                return None;
            }
        }
        unreachable!()
    }
}

#[cfg(test)]
mod tests {

    use super::*;

    #[test]
    fn get_value() {
        let key_byte_match = *b"\"value\"";
        let machine = Machine::new(key_byte_match);
        let value = String::from_utf8_lossy(machine.extract(VENMO_JSON).unwrap());
        println!("{value:?}");
    }
}
