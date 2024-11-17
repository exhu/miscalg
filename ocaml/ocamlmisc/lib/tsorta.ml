open Base

(* https://en.wikipedia.org/wiki/Topological_sorting *)
(* "...for every directed edge (u,v) from vertex u to vertex v, u comes before
   v in the ordering." *)

(* Dependency application: u is the source, v is the product/dependent on u. *)

(* TODO cells must be indexed, array or map? *)
type cells = string list

module Graph = struct
  type edge = { from_cell : int; to_cell : int }
  type edges = edge array
  type t = { edges : edges; nodes_count : int }

  let nodes_count t = t.nodes_count
  let from_cell (e : edge) = e.from_cell

  let from_edges (e : edges) =
    let nodes_count =
      Array.fold ~f:(fun a c -> max a (max c.from_cell c.to_cell)) ~init:0 e
    in
    { edges = e; nodes_count }

  let dump (t : t) : unit =
    for i = 0 to Array.length t.edges - 1 do
      let e = t.edges.(i) in
      Stdio.printf "edge %d -> %d\n" e.from_cell e.to_cell
    done
end

(* depth first
   L ← Empty list that will contain the sorted nodes
   while exists nodes without a permanent mark
   do select an unmarked node n
   visit(n)

   function visit(node n)
   if n has a permanent mark then return
   if n has a
   temporary mark then stop   (graph has at least one cycle)

       mark n with a temporary mark

       for each node m with an edge from n to m do visit(m)

       mark n with a permanent mark add n to head of L
*)

let sorted_l = []
let perm_marked = []
let temp_marked = []

let source_nodes (e : Graph.edges) =
  Array.map ~f:Graph.from_cell e |> List.of_array

let visit n perm_marked temp_marked sorted_l =
  match List.find perm_marked ~f:(( = ) n) with
  | Some _ -> Some sorted_l
  | None -> None (*todo*)

let sorted_or_none = []

(* let depth_first a:Graph.t = let unmarked_nodes = List.range 0
   (Graph.nodes_count a) in unmarked_nodes
*)
(* TODO implement different algorigthms *)

(* let tsortdf e: edges = let all_indexes = List.fold_left (fun a c -> (a ::
   [c.from_cell ; c.to_cell])) [] in ;
*)
