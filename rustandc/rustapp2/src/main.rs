unsafe extern "C" {
    fn myhello(msg: *const std::ffi::c_char);
}

fn main() {
    println!("Hello, world!");
    unsafe {
        let msg = c"hell from rust!11";
        myhello(msg.as_ptr());
    }
}
