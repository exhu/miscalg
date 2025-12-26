(* LD_LIBRARY_PATH=./_build/default/foreign/ dune exec ocaml-clib *)
(* TODO figure out how to put .so along the program *)
(* -Wl,-rpath='$ORIGIN/../so' *)

let ctx = Myclibbind.C.Functions.myclib_init "hi"
let name = Myclibbind.C.Functions.myclib_get_name ctx
let () = Myclibbind.C.Functions.myclib_done ctx
let () = print_endline name
let () = print_endline "Hello, World!"
