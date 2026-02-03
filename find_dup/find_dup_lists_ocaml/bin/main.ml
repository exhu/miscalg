(* program arguments *)
type program_settings_t = {
  ignore_contents : bool ref;
  input_files : string list ref;
}

let process list1 list2 _ignore_contents =
  print_endline (Find_dup_lists_ocaml.Lib.string_of_string_list list1);
  print_endline (Find_dup_lists_ocaml.Lib.string_of_string_list list2)
(* TODO process lists *)

let usage_msg =
  "find_dup_lists_ocaml [options] file1 file2\n\
   Where files contain absolute file names separated by new line.\n\
   You can generate those lists with 'fd -t f . /my-dir-to-list/subdir/'\n\n\
   Note: case folding is basic, i.e. no special rules are used for Greek, \
   Germanetc. where letters not merely change case, but may be replaced with \
   severalletters."

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
  print_endline (first ^ second);
  process (read_lines first) (read_lines second) !(psettings.ignore_contents)
