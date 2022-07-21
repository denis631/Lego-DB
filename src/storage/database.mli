type record_id = Record.Id.t
type record_data = Record.Data.t
type record = Record.t

module Session : sig
  type t
  type session_t = t

  module Crud : sig
    module Table : sig
      val exists : t -> string -> bool
      val create : t -> string -> (unit, [> `FailedTableCreate]) result
      val drop : t -> string -> (unit, [> `FailedTableDrop]) result
    end

    module Record : sig
      val read_all : t -> string -> record Core.Sequence.t
    end
  end

  module Cursor : sig
    type t

    module Options : sig
      type t = Bulk | Append

      val show : t -> string
    end

    module ValueBuffer : sig
      type t

      val make : unit -> t
      val get_key : t -> record_id
      val get_value : t -> record_data
      val init_from_value : record_data -> t
    end

    val make :
      session_t ->
      string ->
      Options.t list ->
      (t, [> `FailedCursorOpen ]) result

    val get_key_into_buffer :
      t -> ValueBuffer.t -> (unit, [> `FailedCursorGetKey ]) result

    val get_value_into_buffer :
      t -> ValueBuffer.t -> (unit, [> `FailedCursorGetValue ]) result

    val set_key : t -> record_id -> unit
    val set_value : t -> record_data -> unit
    val set_value_from_buffer : t -> ValueBuffer.t -> unit
    val insert : t -> (unit, [> `FailedCursorInsert ]) result
    val remove : t -> (unit, [> `FailedCursorRemove ]) result
    val search : t -> record_id -> record_data option

    val seek :
      t -> (unit, [> `FailedCursorNext | `FailedCursorSeek ]) result

    val next : t -> (unit, [> `FailedCursorNext ]) result
    val close : t -> (unit, [> `FailedCursorClose ]) result
  end
end

val make : unit -> Session.t
