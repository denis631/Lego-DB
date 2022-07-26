open Common
open Core
open Ctypes
open Utils

type selection = {
  predicate : (char ptr -> bool) Lazy.t;
  child_op : op;
  input_schema : Schema.t;
}

type op += Selection of selection

let make fs ~child_op ~predicate =
  let input_schema = fs.output_schema child_op in
  let predicate =
    let func () =
      let ctx = Vm.Ctx.make () in
      let instructions = Vm.Instruction.of_match_expr ctx predicate in
      Vm.compile ctx input_schema instructions
    in
    Lazy.from_fun func
  in
  Selection { predicate; child_op; input_schema }

let has_iu root_has_iu iu selection = root_has_iu iu selection.child_op

let open_op fs ctx selection =
  (* Compile the predicate function *)
  (* ignore @@ Lazy.force_val selection.predicate; *)
  fs.open_op ctx selection.child_op

let close_op fs ctx selection = fs.close_op ctx selection.child_op

let next fs ctx selection =
  let rec probe () =
    match fs.next ctx selection.child_op with
    | Some record ->
        let f = Lazy.force_val selection.predicate in
        if f @@ RecordBuffer.to_ptr (snd record) then Some record else probe ()
    | None -> None
  in
  probe ()
