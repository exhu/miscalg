open Ocamlmisc.Tsorta

let () =
  print_endline "hi";
  let a : Graph.edge = { from_cell = 0; to_cell = 1 } in
  let b : Graph.edge = { from_cell = 2; to_cell = 1 } in
  let edges = [| a; b |] in
  let g = Graph.from_edges edges in
  let () = Graph.dump g in
  let sorted = Sort_depth_first.sorted_or_none g in
  print_endline "sorted result=";
  List.iter (fun item -> Printf.printf "%i\n" item) sorted
