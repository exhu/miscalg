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
    let _parsed = Arguments::parse();
    //println!("usage: <file names.txt> [-o destination path] [-k keep temp dir] [program name to pass directory]");
    println!("succc");
    ExitCode::SUCCESS
}