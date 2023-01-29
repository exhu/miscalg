use std::collections::HashMap;
use std::path::Path;

#[derive(Debug)]
enum FoundPaths {
    Single(Box<Path>),
    Multiple(Vec<Box<Path>>),
}

type PathList = HashMap<String, FoundPaths>;

fn append_to_multiple(m: &mut Vec<Box<Path>>, p: &Path) {
    m.push(Box::from(p));
}

fn append(files_map: &mut PathList, path: &Path) {
    let basename = path
        .file_name()
        .expect("failed to get basename")
        .to_str()
        .unwrap()
        .to_owned();

    match files_map.get_mut(&basename) {
        Some(v) => match v {
            FoundPaths::Single(s) => {
                let items = vec![s.clone(), Box::<Path>::from(path)];
                files_map.insert(basename, FoundPaths::Multiple(items));
            }
            FoundPaths::Multiple(m) => {
                append_to_multiple(m, path);
            }
        },
        None => {
            files_map.insert(basename, FoundPaths::Single(Box::from(path)));
        }
    }
}

fn grab_files(list: &mut PathList, root: &Path) {
    let mut dirs = Vec::<Box<Path>>::new();

    for entry in root.read_dir().expect("failed to read dir") {
        if let Ok(entry) = entry {
            let path = entry.path();
            if path.is_dir() {
                dirs.push(Box::<Path>::from(path));
            } else if path.is_file() {
                append(list, &path);
            }
        }
    }

    for entry in dirs {
        grab_files(list, &entry);
    }
}

fn gather_files(root: &Path) -> PathList {
    let mut result = PathList::new();

    grab_files(&mut result, root);

    result
}

fn print_paths(paths: &FoundPaths) {
    match paths {
        FoundPaths::Single(s) => {
            println!("{:}", s.display());
        }
        FoundPaths::Multiple(m) => {
            for i in m {
                println!("{:}", i.display());
            }
        }
    }
}

fn process_paths(path_a: &Path, path_b: &Path) {
    let list_a = gather_files(path_a);
    let list_b = gather_files(path_b);

    for (k, v) in &list_a {
        if list_b.contains_key(k) {
            print_paths(v);
            print_paths(list_b.get(k).unwrap());
        }
    }

    //println!("{:?}", list_a);
}

fn usage() {
    println!("Usage: find_dup_r <path a> <path b>")
}

fn main() {
    if std::env::args().count() != 3 {
        usage();
        std::process::exit(1);
    }

    let arg1 = std::env::args().nth(1).unwrap().to_owned();
    let arg2 = std::env::args().nth(2).unwrap().to_owned();
    let path_a = Path::new(&arg1);
    let path_b = Path::new(&arg2);

    if path_a.exists() && path_b.exists() && path_a.is_dir() && path_b.is_dir() {
        //println!("a={:?}, b={:?}", path_a, path_b);
        process_paths(path_a, path_b);
    } else {
        usage();
        std::process::exit(1);
    }
}
