const EXAMPLE_JSON: &[u8] = include_bytes!("../example.json");

pub struct Machine<const MATCH_LENGTH: usize> {
    pub key_byte_match: [u8; MATCH_LENGTH],
    pub target_byte_start_index: Option<u8>,
    pub target_byte_end_index: Option<u8>,
}

impl<const MATCH_LENGTH: usize> Machine<MATCH_LENGTH> {
    pub fn new(key_byte_match: [u8; MATCH_LENGTH]) -> Self {
        Machine {
            key_byte_match,
            target_byte_start_index: None,
            target_byte_end_index: None,
        }
    }

    pub fn extract(&self, data_bytes: &'static [u8]) -> Option<&[u8]> {
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
                return Some(&data_bytes[i..i + MATCH_LENGTH]);
            } else {
                return None;
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {

    use super::*;

    #[test]
    fn get_title() {
        let key_byte_match = *b"\"title\"";
        let machine = Machine::new(key_byte_match);
        let title = String::from_utf8_lossy(machine.extract(EXAMPLE_JSON).unwrap());
        println!("{title:?}");
    }
}
