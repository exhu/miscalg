let%test _ =
  let ctx = Myclibbind.C.Functions.myclib_init "hi1" in
  let name = Myclibbind.C.Functions.myclib_get_name ctx in
  let _ = Myclibbind.C.Functions.myclib_done ctx in
  name = "hi1"
