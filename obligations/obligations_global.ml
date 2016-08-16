module Unstable = struct
  open! Import
  module Hash_consing       = Hash_consing
end

module Stable = struct
  open! Core.Stable
  open! Import_stable

  module Groups = Groups.Stable
  module Scrutiny = Scrutiny.Stable

  module V4 = struct
    module Unshared = struct
      type t =
        { disallow_useless_dot_fe : bool
        ; scrutinies              : Scrutiny.V2.t Scrutiny_name.V1.Map.t
        ; tags                    : Tag.V1.Set.t
        ; users                   : Unresolved_name.V1.Set.t
        ; groups                  : Groups.V1.t
        ; obligations_version     : Obligations_version.V1.t
        }
      [@@deriving bin_io, compare, fields, sexp]

      let module_name = "Iron_obligations.Obligation_global"

      let hash t =
        let module Hash_consing = Unstable.Hash_consing in
        let hash field = Hash_consing.field t field in
        Fields.fold
          ~init:Hash_consing.init
          ~disallow_useless_dot_fe:(hash (Hashtbl.hash : bool -> int))
          ~scrutinies:(hash (Scrutiny_name.V1.Map.hash Scrutiny.V2.hash))
          ~tags:(hash Tag.V1.Set.hash)
          ~users:(hash Unresolved_name.V1.Set.hash)
          ~groups:(hash Groups.V1.hash)
          ~obligations_version:(hash Obligations_version.V1.hash)
      ;;
    end
    include Unshared
    include Hash_consing.Make_stable_public (Unshared) ()
  end

  module Model = V4
end

open! Core.Std
open! Import

module Declaration = struct
  type u = (syntax, Sexp.t) And_sexp.t
  and syntax =
    | Define_scrutiny of Scrutiny_name.t * Scrutiny.Syntax.t
    | Define_tags of Tag.t sexp_list
    | Define_group of Group_name.t * Unresolved_name.Set.t
    | Disallow_useless_dot_fe
    | Users of Unresolved_name.t sexp_list
    | Cr_comment_format of Cr_comment_format.t
    | Obligations_version of Obligations_version.t
  [@@deriving sexp]

  type t = (u, Sexp.Annotated.t) And_sexp.t

  let sexp_of_t (t : t) = t.syntax.syntax |> [%sexp_of: syntax]

  let of_annotated_sexp annotated_sexp : t =
    { syntax = annotated_sexp |> Sexp.Annotated.get_sexp |> [%of_sexp: u]
    ; sexp   = Some annotated_sexp
    }
  ;;
end

type t = Stable.Model.t =
  { disallow_useless_dot_fe : bool
  ; scrutinies              : Scrutiny.t Scrutiny_name.Map.t
  ; tags                    : Tag.Set.t
  ; users                   : Unresolved_name.Set.t
  ; groups                  : Groups.t
  ; obligations_version     : Obligations_version.t
  }
[@@deriving sexp_of]

let shared_t = Stable.Model.shared_t

let eval_aux e declarations ~aliases =
  let disallow_useless_dot_fe = ref false in
  let scrutinies = Scrutiny_name.Table.create () in
  let tags = Tag.Hash_set.create () in
  let users = Unresolved_name.Hash_set.create () in
  let groups = Group_name.Table.create () in
  let obligations_version = ref None in
  let process_declaration (declaration : Declaration.t) =
    let e =
      Error_context.augment e
        ?annotated_sexp:declaration.sexp
        ?sexp:declaration.syntax.sexp
    in
    match declaration.syntax.syntax with
    | Define_scrutiny (name, scrutiny) ->
      (match
         Hashtbl.add scrutinies ~key:name ~data:(e, scrutiny)
       with
       | `Ok -> ()
       | `Duplicate ->
         Error_context.raise_s e
           [%sexp "multiply defined scrutiny", (name : Scrutiny_name.t)])
    | Define_tags define_tags ->
      List.iter define_tags ~f:(fun tag ->
        if Hash_set.mem tags tag
        then Error_context.raise_s e [%sexp "multiply defined tag", (tag : Tag.t)]
        else Hash_set.add tags tag)
    | Define_group (group_name, users_in_group) ->
      (match Hashtbl.add groups ~key:group_name ~data:users_in_group with
       | `Ok -> ()
       | `Duplicate ->
         Error_context.raise_s e
           [%sexp "multiply defined group", (group_name : Group_name.t)])
    | Disallow_useless_dot_fe -> disallow_useless_dot_fe := true
    | Users people -> List.iter people ~f:(fun user -> Hash_set.add users user)
    | Obligations_version format ->
      (match !obligations_version with
       | None -> obligations_version := Some format
       | Some _ ->
         Error_context.raise_f e
           "multiple Obligations_version specifications" ())
    | Cr_comment_format format ->
      (match !obligations_version with
       | Some _ -> Error_context.raise_f e "multiple Cr_comment_format specifications" ()
       | None ->
         let (version : Obligations_version.t) =
           match format with
           | V1         -> V1
           | V2_sql_xml -> V2
         in
         obligations_version := Some version)
  in
  List.iter declarations ~f:process_declaration;
  let tags = tags |> Tag.Set.of_hash_set in
  let users = users |> Unresolved_name.Set.of_hash_set in
  let groups = groups |> Group_name.Map.of_hashtbl_exn in
  let obligations_version =
    Option.value !obligations_version ~default:Obligations_version.default
  in
  (match Groups.check_users groups ~known_users:users with
   | Ok () -> ()
   | Error err -> Error_context.raise e err);
  let scrutinies =
    scrutinies
    |> Scrutiny_name.Map.of_hashtbl_exn
    |> Map.mapi ~f:(fun ~key:name ~data:(e, syntax) ->
      Scrutiny.eval name syntax e ~aliases ~allowed_users:users ~known_groups:groups)
  in
  shared_t
    { disallow_useless_dot_fe = !disallow_useless_dot_fe
    ; tags
    ; scrutinies
    ; users
    ; groups
    ; obligations_version
    }
;;

let eval declarations ~obligations_global ~aliases =
  Error_context.within ~file:obligations_global (fun e ->
    eval_aux e declarations ~aliases)
;;
