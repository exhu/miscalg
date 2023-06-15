use clap::Parser;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(version, about)]
struct Arguments {
    /// text file with file name per line, "file://" is allowed.
    pub list_file: String,
    /// program to run and pass directory path
    pub program_name: Option<String>,
    /// print to stdout, and keep created directory after running program
    #[arg(short, long, default_value_t = false)]
    pub keep: bool,
}

fn main() -> ExitCode {
    // read text file with file names, remove file:///
    // create links in destination
    // if program name is given, run program
    let parsed = Arguments::parse();
    let dirname = paths_to_links::temp_dir("p2l");
    if parsed.program_name.is_none() {
        println!("{dirname}");
    } else {
        eprintln!("{dirname}");
    }
    let dirpath = std::path::Path::new(&dirname);
    std::fs::create_dir(dirpath).expect("Failed to create dir.");
    // TODO make links
    println!("succc");
    if let Some(prog) = parsed.program_name {
        // TODO run and wait
    }
    if !parsed.keep {
        std::fs::remove_dir_all(dirpath).expect("Failed to delete dir.");
    }
    ExitCode::SUCCESS
}
