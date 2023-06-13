pub fn make_unique_name(src: &str, number: u32) -> String {
    use std::path::*;
    use std::ffi::OsStr;
    let p = Path::new(src);
    let suff = p.extension().and_then(OsStr::to_str).unwrap();
    let res = format!("{src}.{number:03}.{suff}");
    res
}

const MAX_TRIES:u32 = 999;

//type ExistsFn = dyn Fn(&str) -> bool;

pub fn find_unque_name<F>(src: &str, exists_fn: F) -> Option<String> 
where F: Fn(&str) -> bool {
    if !exists_fn(src) {
        return Some(src.to_owned());
    }

    for i in 1..MAX_TRIES {
        let new_name = make_unique_name(src, i);
        if !exists_fn(&new_name) {
            return Some(new_name);
        }
    }
    None
}


#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn check_unique() {
        let s = "my001.jpg";
        let o = make_unique_name(s, 1);
        assert_eq!(o, "my001.jpg.001.jpg");
        let o2 = make_unique_name(s, 11222);
        assert_eq!(o2, "my001.jpg.11222.jpg");
    }
    
    #[test]
    fn find_unique() {
        let s = "myaaa.jpg";
        let r1 = find_unque_name(s, |_| false);
        assert_eq!(r1, Some(s.to_owned()));
        let r2 = find_unque_name(s, |_| true);
        assert_eq!(r2, None);
        let r3 = find_unque_name(s, |a| a == s);
        assert_eq!(r3, Some("myaaa.jpg.001.jpg".to_owned()));
        let r4 = find_unque_name(s, |a| a == s || a == "myaaa.jpg.001.jpg");
        assert_eq!(r4, Some("myaaa.jpg.002.jpg".to_owned()));
    }
}