open Dep_model

let () =
  Graph.(
  let e1 = make_edge 0 1 in
  let edges = [| e1 ; make_edge 2 1 |] in
  let g1 = make_from_edges edges in
  Dep_model.Graph.dump g1)
