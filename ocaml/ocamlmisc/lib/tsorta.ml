
let () = print_endline "hello";

(* https://en.wikipedia.org/wiki/Topological_sorting *)
(* "...for every directed edge (u,v) from vertex u to vertex v, u comes before v in the ordering." *)

(* Dependency application: u is the source, v is the product/dependent on u. *)

(* TODO cells must be indexed, array or map? *)
type cells = string list



module Graph = struct
        type edge = { from_cell: int;
                to_cell: int }

        type edges = edge array
        type t = { edges: edges ; nodes_count: int }

let from_edges (e: edges) =
        let nodes_count = Array.fold_left (fun a c -> max a (max c.from_cell c.to_cell)) 0 e in
                { edges = e ; nodes_count }


let dump (t: t): unit = for i = 0 to (Array.length t.edges-1) do
        let e = t.edges.(i) in
               Printf.printf "edge %d -> %d\n" e.from_cell e.to_cell
        done
end


(* TODO implement different algorigthms *)

(*
let tsortdf e: edges =
        let all_indexes = List.fold_left (fun a c -> (a :: [c.from_cell ; c.to_cell])) [] in
        ;
*)

let () = print_endline "hi" ;
        let a: Graph.edge = {
                from_cell = 0 ;
                to_cell = 1
        }
        in
        let b: Graph.edge  = { from_cell = 2 ; to_cell = 1 }  in
        let edges = [| a ; b |] in
        let g = Graph.from_edges edges in
        Graph.dump g
 
