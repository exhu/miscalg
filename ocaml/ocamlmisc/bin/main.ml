open Ocamlmisc.Tsorta

let () =
  print_endline "hi";
  let a : Graph.edge = { from_cell = 0; to_cell = 1 } in
  let b : Graph.edge = { from_cell = 2; to_cell = 1 } in
  let edges = [| a; b |] in
  let g = Graph.from_edges edges in
  Graph.dump g
