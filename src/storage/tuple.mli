type t

val parse: Schema.t -> string -> t

val get: t -> int -> Value.t

val extract_values: int list -> t -> t

val show: t -> string
