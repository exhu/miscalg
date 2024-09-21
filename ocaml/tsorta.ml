
let () = print_endline "hello";

(* https://en.wikipedia.org/wiki/Topological_sorting *)
(* "...for every directed edge (u,v) from vertex u to vertex v, u comes before v in the ordering." *)

(* Dependency application: u is the source, v is the product/dependent on u. *)

(* TODO cells must be indexed, array or map? *)
type cells = string list



module Graph = struct
        type edge = { from_cell: int;
                to_cell: int }

        type edges = edge list
        type t = { edges: edges ; nodes_count: int }

let from_edges edges =
        let nodes_count = List.fold_left (fun a c -> max a c) 0 edges in
                (* edges ; nodes_count *)
        ()
end


(* TODO implement different algorigthms *)

(*
let tsortdf e: edges =
        let all_indexes = List.fold_left (fun a c -> (a :: [c.from_cell ; c.to_cell])) [] in
        ;
*)
