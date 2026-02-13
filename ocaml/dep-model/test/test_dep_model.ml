open Dep_model

let () =
  Graph.(
    let e1 = make_edge 0 1 in
    let edges = [| e1; make_edge 2 1; make_edge 1 3; make_edge 3 2 |] in
    let g1 = make_from_edges edges in
    Dep_model.Graph.dump g1;
    let dot_text = generate_dot_text "test cycled graph" g1 in
    print_endline dot_text;
    Out_channel.with_open_text "temp.gv" (fun f ->
        Out_channel.output_string f dot_text);
    match Sort_depth_first.tsort g1 with
    | Sort_depth_first.Cycle n -> Printf.printf "cycle %d!" n
    | Sort_depth_first.Sorted lst ->
        List.iter (fun i -> Printf.printf "%d\n" i) lst)
