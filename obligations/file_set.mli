(** Syntactic form in [.fe.sexp] files for specifying a set of files. *)

open! Core.Std
open! Import

type t [@@deriving sexp]

val all_files : t

val files : File_name.t list -> t

val eval
  :  t
  -> universe : File_name.Set.t
  -> Error_context.t
  -> File_name.Set.t

val synthesize
  :  desired  : File_name.Set.t
  -> universe : File_name.Set.t
  -> t
