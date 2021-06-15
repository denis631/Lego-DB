type name = string

type t =
  { name : name
  ; mutable schema : Schema.t
  ; mutable tuples : Tuple.t list
  }

module Iu = struct
  type t = name * Schema.column_name * Value_type.t

  let make name col t = (name, col, t)

  let eq a b = a = b
end

let name tbl = tbl.name

let schema tbl = tbl.schema

let tuples tbl = tbl.tuples

let create name schema = { name; schema; tuples = [] }

let insert tbl tuple = tbl.tuples <- tuple :: tbl.tuples

let ius tbl = List.map (fun (col, ty) -> Iu.make tbl.name col ty) tbl.schema
