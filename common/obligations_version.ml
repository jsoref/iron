module Stable_format = struct
  open! Core.Stable
  module V1 = struct
    type t = int [@@deriving bin_io, compare, sexp]
  end
end

open! Core.Std
open! Import

type t =
  | V1
  | V2
  | V3
[@@deriving compare, enumerate]

let to_int = function
  | V1 -> 1
  | V2 -> 2
  | V3 -> 3
;;

let of_int = function
  | 1 -> V1
  | 2 -> V2
  | 3 -> V3
  | n -> failwiths "Obligations_version: version is out of range" n [%sexp_of: int]
;;

let sexp_of_t t = sexp_of_int (to_int t)

let t_of_sexp sexp = of_int (int_of_sexp sexp)

let default = V1

let latest = List.hd_exn (List.sort all ~cmp:(fun x y -> compare y x))

let is_at_least_version t ~version = compare t version >= 0

let cr_comment_format = function
  | V1 -> Cr_comment_format.V1
  | V2
  | V3 -> Cr_comment_format.V2_sql_xml
;;

let hash t = Int.hash (to_int t)

module Stable = struct
  module V1 = struct
    let hash = hash
    include Wrap_stable.F
        (Stable_format.V1)
        (struct
          type nonrec t = t
          let to_stable = to_int
          let of_stable = of_int
        end)
  end
end