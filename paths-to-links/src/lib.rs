pub fn make_unique_name(src: &str, number: u32) -> String {
    use std::path::*;
    use std::ffi::OsStr;
    let p = Path::new(src);
    let suff = p.extension().and_then(OsStr::to_str).unwrap();
    let res = format!("{src}.{number:04}.{suff}");
    res
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn check_unique() {
        let s = "my001.jpg";
        let o = make_unique_name(s, 1);
        assert_eq!(o, "my001.jpg.0001.jpg");
        let o2 = make_unique_name(s, 11222);
        assert_eq!(o2, "my001.jpg.11222.jpg");
    }
}