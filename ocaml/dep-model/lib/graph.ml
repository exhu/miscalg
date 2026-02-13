(** DAG is represented by edges which reference the graph nodes by integers.
    Maximum used integer defines the nodes count in the graph. *)

type edge = { from_cell : int; to_cell : int }
type edges = edge array
type t = { edges : edges; nodes_count : int }

let nodes_count t = t.nodes_count
let edges t = t.edges
let make_edge from_cell to_cell = { from_cell; to_cell }

let make_from_edges (e : edges) : t =
  let max_node =
    Array.fold_left (fun a c -> max a (max c.from_cell c.to_cell)) 0 e
  in
  { edges = e; nodes_count = max_node + 1 }

let print_edges edges =
  Array.iter
    (fun e -> Printf.printf "edge %d -> %d\n" e.from_cell e.to_cell)
    edges

let dump (t : t) : unit = print_edges t.edges
(*
let all_dest_from t n =
  let lst = ref [] in
  Array.iter (fun e -> if e.from_cell = n then lst := e.to_cell :: !lst) t.edges;
  !lst
   *)

let all_dest_from t n =
  Array.to_seq t.edges
  |> Seq.filter (fun e -> e.from_cell = n)
  |> Seq.map (fun e -> e.to_cell)

(* https://en.wikipedia.org/wiki/Topological_sorting *)
(* "...for every directed edge (u,v) from vertex u to vertex v, u comes before
   v in the ordering." *)

(* Dependency application: u is the source, v is the product/dependent on u. *)

(* depth first
   L ← Empty list that will contain the sorted nodes
   while exists nodes without a permanent mark
   do select an unmarked node n
   visit(n)

   function visit(node n)
   if n has a permanent mark then return
   if n has a temporary mark then stop   (graph has at least one cycle)

       mark n with a temporary mark

       for each node m with an edge from n to m do visit(m)

       mark n with a permanent mark add n to head of L
*)

module Sort_depth_first = struct
  type sort_context = {
    graph : t;
    sorted_l : int list ref;
    perm_marked : int list ref;
    temp_marked : int list ref;
    perm_marked_count : int ref;
  }

  type visit_status = Continue | Stop_on_cycle of int

  let mark_perm sort_context n =
    let perm_marked = sort_context.perm_marked in
    perm_marked := n :: !perm_marked;
    incr sort_context.perm_marked_count

  let add_to_sorted sort_context n =
    let sorted = sort_context.sorted_l in
    sorted := n :: !sorted

  let rec visit sort_context n =
    if List.mem n !(sort_context.perm_marked) then Continue
    else if List.mem n !(sort_context.temp_marked) then Stop_on_cycle n
    else begin
      sort_context.temp_marked := n :: !(sort_context.temp_marked);
      let nodes_of_n = all_dest_from sort_context.graph n in
      let found_cycle =
        Seq.find
          (fun m ->
            match visit sort_context m with
            | Stop_on_cycle c -> true (* TODO propagate c value as cycle *)
            | Continue -> false)
          nodes_of_n
      in
      mark_perm sort_context n;
      add_to_sorted sort_context n;
      match found_cycle with Some c -> Stop_on_cycle c | None -> Continue
    end

  type tsort_status = Sorted of int list | Cycle of int

  let tsort graph =
    let ctx =
      {
        graph;
        sorted_l = ref [];
        perm_marked = ref [];
        temp_marked = ref [];
        perm_marked_count = ref 0;
      }
    in
    let found_cycle =
      Printf.printf "nodes_count=%d\n" graph.nodes_count;
      Seq.ints 0 |> Seq.take graph.nodes_count
      |> Seq.find (fun e ->
          match visit ctx e with Continue -> false | Stop_on_cycle _ -> true)
    in
    match found_cycle with Some c -> Cycle c | None -> Sorted !(ctx.sorted_l)
end
