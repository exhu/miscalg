(* https://en.wikipedia.org/wiki/Topological_sorting *)
(* "...for every directed edge (u,v) from vertex u to vertex v, u comes before
   v in the ordering." *)

(* Dependency application: u is the source, v is the product/dependent on u. *)

type edge = { from_cell : int; to_cell : int }
type edges = edge array
type t = { edges : edges; nodes_count : int }

let nodes_count t = t.nodes_count
let edges t = t.edges
let make_edge from_cell to_cell = { from_cell; to_cell }

let make_from_edges (e : edges) : t =
  let nodes_count =
    Array.fold_left (fun a c -> max a (max c.from_cell c.to_cell)) 0 e
  in
  { edges = e; nodes_count }

let print_edges edges =
  Array.iter
    (fun e -> Printf.printf "edge %d -> %d\n" e.from_cell e.to_cell)
    edges

let dump (t : t) : unit = print_edges t.edges

let all_dest_from t n =
  let lst = ref [] in
  Array.iter (fun e -> if e.from_cell = n then lst := e.to_cell :: !lst) t.edges;
  !lst

let all_dest_from2 t n =
  Array.to_seq t.edges |> Seq.filter (fun e -> e.from_cell = n) |> List.of_seq
