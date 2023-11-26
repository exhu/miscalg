pub fn make_unique_name(src: &str, number: u32) -> String {
    use std::path::*;
    let p = Path::new(src);
    let ext = p.extension();
    match ext {
        None => format!("{src}.{number:03}"),
        Some(e) => {
            let suff = e.to_str().unwrap();
            format!("{src}.{number:03}.{suff}")
        }
    }
}

const MAX_TRIES: u32 = 999;

//type ExistsFn = dyn Fn(&str) -> bool;

pub fn find_unque_name<F>(src: &str, exists_fn: F) -> Option<String>
where
    F: Fn(&str) -> bool,
{
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

pub fn read_list(filename: &str) -> Option<Vec<String>> {
    let r = std::fs::read_to_string(filename);
    if r.is_err() {
        return None;
    }

    Some(r.unwrap().lines().map(str::to_owned).collect())
}

pub fn temp_dir(base_name: &str) -> String {
    use std::env;
    let root = env::temp_dir();
    let mut sub = root.clone();
    sub.push(base_name);
    let new_temp = find_unque_name(sub.as_os_str().to_str().unwrap(), |a| {
        let mut n = root.clone();
        n.push(a);
        n.exists()
    });
    new_temp.unwrap()
}

pub fn remove_file_prefix(name: &str) -> &str {
    match name.strip_prefix("file://") {
        Some(unprefixed) => unprefixed,
        None => name,
    }
}

pub fn create_symlink(link_name: &str, target: &str) -> std::io::Result<()> {
    std::os::unix::fs::symlink(target, link_name)
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

    #[test]
    fn read_lines_test() {
        let r = read_list("Cargo.toml").unwrap();
        assert_eq!(r[0], "[package]");
        assert_eq!(r[1], "name = \"paths-to-links\"");
    }

    #[test]
    fn tmpdir() {
        let td = temp_dir("tmplinkstest");
        let np = std::path::Path::new(&td);
        assert!(!np.exists());
        println!("temp dir = {}", np.to_str().unwrap());
        assert!(std::fs::create_dir(np).is_ok());
        assert!(np.exists());
        assert!(std::fs::remove_dir(np).is_ok());
    }
}
