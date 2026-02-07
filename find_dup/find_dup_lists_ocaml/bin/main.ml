(* program arguments *)
type program_settings_t = {
  ignore_contents : bool ref;
  input_files : string list ref;
}

(** reversed list of uchars *)
let uchars_of_string s =
  (* TODO rewrite with tail rec? *)
  let i = ref 0 in
  let len = String.length s in
  let out = ref [] in
  while !i < len do
    let decoded = String.get_utf_8_uchar s !i in
    i := !i + Uchar.utf_decode_length decoded;
    out := Uchar.utf_decode_uchar decoded :: !out
  done;
  !out

(** accepts reversed list of uchars *)
let casefold_uchars_of_uchars srclist =
  List.map
    (fun x ->
      match Uucp.Case.Fold.fold x with `Self -> [ x ] | `Uchars y -> y)
    srclist

(* unicode casefold https://erratique.ch/software/uucp/doc/Uucp/index.html *)
let casefold a =
  let uchars = uchars_of_string a in
  let casefold_uchars = casefold_uchars_of_uchars uchars in
  let outbuf = Buffer.create (String.length a) in
  List.iter
    (fun lst -> List.iter (fun x -> Buffer.add_utf_8_uchar outbuf x) lst)
    casefold_uchars;
  Buffer.contents outbuf

let is_same_name a b =
  casefold (Filename.basename a) = casefold (Filename.basename b)

module PathToGroup = Hashtbl.Make (String)
module IntHashMap = Hashtbl.Make (Int)

type path_group = { number : int ref; path_to_group : int PathToGroup.t }

let update_group g path_a path_b =
  let get_group_for_path = PathToGroup.find g.path_to_group in
  let update_path = PathToGroup.replace g.path_to_group in
  let path_in_group = PathToGroup.mem g.path_to_group in
  if not (path_in_group path_a) then begin
    if not (path_in_group path_b) then begin
      update_path path_a !(g.number);
      update_path path_b !(g.number);
      incr g.number
    end
    else update_path path_a (get_group_for_path path_b)
  end
  else begin
    if not (path_in_group path_b) then
      update_path path_b (get_group_for_path path_a)
  end

let same_file_contents path_a path_b =
  let chunk_len = 4096 in
  let temp_buf_a = Bytes.create chunk_len in
  let temp_buf_b = Bytes.create chunk_len in
  let success = ref false in
  In_channel.with_open_bin path_a (fun ca ->
      In_channel.with_open_bin path_b (fun cb ->
          let file_len = In_channel.length ca in
          let file_len_b = In_channel.length cb in
          let should_stop = ref (file_len <> file_len_b) in
          let cur_pos = ref 0L in
          while not !should_stop do
            let read_count = In_channel.input ca temp_buf_a 0 chunk_len in
            let read_count2 = In_channel.input cb temp_buf_b 0 chunk_len in
            if
              read_count <> read_count2 || read_count = 0
              || temp_buf_a <> temp_buf_b
            then should_stop := true
            else cur_pos := Int64.add !cur_pos (Int64.of_int read_count);
            if !cur_pos >= file_len then begin
              should_stop := true;
              success := true
            end
          done));
  !success

let process list1 list2 ignore_contents =
  print_endline (Find_dup_lists_ocaml.Lib.string_of_string_list list1);
  print_endline (Find_dup_lists_ocaml.Lib.string_of_string_list list2);
  let group =
    {
      number = ref 0;
      path_to_group = PathToGroup.create (List.length list1 + List.length list2);
    }
  in
  let update_fn path_a path_b =
    if
      is_same_name path_a path_b
      && (ignore_contents || same_file_contents path_a path_b)
    then update_group group path_a path_b
  in
  let path_b_filtered path_a =
    List.filter (fun path_b -> not (path_a = path_b)) list2
  in
  let filtered_iter path_a =
    List.iter (update_fn path_a) (path_b_filtered path_a)
  in
  List.iter filtered_iter list1;
  let groups = IntHashMap.create !(group.number) in
  let append_kv k v =
    match IntHashMap.find_opt groups k with
    | None -> IntHashMap.replace groups k [ v ]
    | Some x -> IntHashMap.replace groups k (v :: x)
  in
  PathToGroup.iter (fun k v -> append_kv v k) group.path_to_group;

  print_endline "matches:";
  IntHashMap.iter
    (fun k v ->
      print_endline (string_of_int k ^ "=" ^ Filename.basename (List.hd v));
      List.iter (fun i -> print_endline i) v)
    groups

let usage_msg =
  "find_dup_lists_ocaml [options] file1 file2\n\
   Where files contain absolute file names separated by new line.\n\
   You can generate those lists with 'fd -t f . /my-dir-to-list/subdir/'\n\n\
   Note: case folding is basic, i.e. no special rules are used for Greek, \
   German etc. where letters not merely change case, but may be replaced with \
   several letters."

let spec_list (ignore_contents : bool ref) =
  [
    ( "-n",
      Arg.Set ignore_contents,
      "Do not check file contents, print only matching filenames \
       (case-insensitive)" );
  ]

let anon_fun (input_files : string list ref) filename =
  input_files := filename :: !input_files

let parse_args : program_settings_t =
  let psettings = { ignore_contents = ref false; input_files = ref [] } in
  Arg.parse
    (spec_list psettings.ignore_contents)
    (anon_fun psettings.input_files)
    usage_msg;
  if List.length !(psettings.input_files) != 2 then begin
    Arg.usage (spec_list psettings.ignore_contents) usage_msg;
    exit 1
  end;
  psettings

let read_lines fname =
  print_endline fname;
  In_channel.with_open_text fname (fun c -> In_channel.input_lines c)

let fnames_of_list = function
  | [ second; first ] -> (first, second)
  | _ -> ("", "")

let () =
  let psettings = parse_args in
  let input_files = !(psettings.input_files) in
  print_endline (Find_dup_lists_ocaml.Lib.string_of_string_list input_files);
  let first, second = fnames_of_list input_files in
  process (read_lines first) (read_lines second) !(psettings.ignore_contents)
