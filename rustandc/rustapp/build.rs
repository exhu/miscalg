use cmake;
//use std::env;
//use std::fs;
//use std::path::Path;

fn main() {
    //let out_dir = env::var_os("OUT_DIR").unwrap();
    /*
        let dest_path = Path::new(&out_dir).join("hello.rs");
        fs::write(
            &dest_path,
            "pub fn message() -> &'static str {
                \"Hello, World!\"
            }
            "
        ).unwrap();
    */
    println!("cargo::rerun-if-changed=build.rs");
    //eprintln!("hello from build.rs!");
    let hellolib = cmake::build("../hellolib");
    println!("cargo:rustc-link-search=native={}/lib", hellolib.display());
    println!("cargo:rustc-link-lib=static=hellolib");
    println!("cargo:rustc-link-lib=static=printlib");
}
