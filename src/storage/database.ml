open Core
open Ctypes
module WT = Wired_tiger

module Result = struct
  include Result

  (* maps wiredtiger error code to result with a message *)
  let of_code code ok err = if code = 0 then Result.Ok ok else Result.Error err
end

type record_id = Record.Id.t
type record_data = Record.Data.t
type record = Record.t

module Session = struct
  type t = WT.Session.t ptr
  type session_t = t

  let make ~path () =
    let open Result in
    let config =
      "create, direct_io=[data, log, checkpoint], log=(enabled,recover=on), \
       session_max=2000, cache_size=4096M"
    in
    let open_connection () =
      let conn_ptr_ptr = WT.Connection.alloc_ptr () in
      Result.of_code
        (WT.Bindings.WiredTiger.wiredtiger_open path null config conn_ptr_ptr)
        conn_ptr_ptr `FailedConnectionCreate
    in
    let open_session conn_ptr_ptr =
      assert (not (is_null !@conn_ptr_ptr));
      let conn_ptr = !@conn_ptr_ptr in
      let session_ptr_ptr = WT.Session.alloc_ptr () in
      let code =
        WT.Connection.open_session conn_ptr null "isolation=snapshot"
          session_ptr_ptr
      in
      Result.of_code code !@session_ptr_ptr `FailedSessionCreate
    in
    match open_connection () >>= open_session with
    | Ok session -> session
    | Error `FailedConnectionCreate ->
        failwith "Failed creating a connection to WT storage"
    | Error `FailedSessionCreate -> failwith "Failed creating a db session"

  module Table = struct
    let create session_ref tbl_name =
      let config = "key_format:r,value_format:u" in
      let code =
        WT.Session.create_tbl session_ref ("table:" ^ tbl_name) config
      in
      Result.of_code code () `FailedTableCreate

    let drop session_ref tbl_name =
      let code = WT.Session.drop_tbl session_ref ("table:" ^ tbl_name) "" in
      Result.of_code code () `FailedTableDrop
  end

  module Cursor = struct
    type t = WT.Cursor.t ptr

    module Options = struct
      type t = Bulk | Append

      let show = function Bulk -> "bulk" | Append -> "append"
    end

    module Buffer = struct
      type t = record_id ptr * WT.Item.t ptr

      let make () =
        ( allocate uint64_t @@ Unsigned.UInt64.zero,
          WT.Item.alloc (Ctypes.make WT.Item.t) )

      let get_key buffer = !@(fst buffer)
      let get_value buffer = WT.Item.to_bytes !@(snd buffer)

      let init_from_value x =
        (from_voidp uint64_t null, addr @@ WT.Item.of_bytes x)
    end

    let make session tbl_name options =
      let config = List.map ~f:Options.show options |> String.concat ~sep:"," in
      let cursor_ptr_ptr = WT.Cursor.alloc_ptr () in
      let code =
        WT.Session.open_cursor session ("table:" ^ tbl_name) null config
          cursor_ptr_ptr
      in
      Result.of_code code !@cursor_ptr_ptr `FailedCursorOpen

    let get_key_into_buffer cursor buffer =
      let code = WT.Cursor.get_key cursor (fst buffer) in
      Result.of_code code () `FailedCursorGetKey

    let get_value_into_buffer cursor buffer =
      let code = WT.Cursor.get_value cursor (snd buffer) in
      Result.of_code code () `FailedCursorGetValue

    let set_key = WT.Cursor.set_key

    let set_value_from_buffer cursor buffer =
      WT.Cursor.set_value cursor (snd buffer)

    let set_value cursor record_data =
      let buffer = Buffer.init_from_value record_data in
      set_value_from_buffer cursor buffer

    let insert cursor =
      let code = WT.Cursor.insert cursor in
      Result.of_code code () `FailedCursorInsert

    let remove cursor =
      let code = WT.Cursor.remove cursor in
      Result.of_code code () `FailedCursorRemove

    let search cursor key =
      set_key cursor key;
      if Int.(WT.Cursor.search cursor = 0) then
        let value_buffer = Buffer.make () in
        match get_value_into_buffer cursor value_buffer with
        | Ok () -> Some (Buffer.get_value value_buffer)
        | _ -> None
      else None

    let next cursor =
      let code = WT.Cursor.next cursor in
      Result.of_code code () `FailedCursorNext

    let seek cursor =
      let exact_ptr = allocate int 0 in
      let code = WT.Cursor.search_near cursor exact_ptr in
      if !@exact_ptr < 0 then next cursor
      else Result.of_code code () `FailedCursorSeek

    let close cursor =
      let code = WT.Cursor.close cursor in
      Result.of_code code () `FailedCursorClose
  end
end
