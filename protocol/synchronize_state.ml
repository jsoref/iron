module Stable = struct

  open! Import_stable

  module Action = struct
    module V2 = struct
      type t =
        { remote_repo_path : Remote_repo_path.V1.t
        ; bookmarks        : Hydra_state_for_bookmark.Stable.V2.t list
        }
      [@@deriving bin_io, fields, sexp]

      let%expect_test _ =
        print_endline [%bin_digest: t];
        [%expect {| 892bd070c2f18c850c6a081659437d3e |}]
      ;;

      let of_model (t : t) = t
      let to_model (t : t) = t
    end

    module V1 = struct
      type t =
        { remote_repo_path : Remote_repo_path.V1.t
        ; bookmarks        : Hydra_state_for_bookmark.Stable.V1.t list
        }
      [@@deriving bin_io]

      let%expect_test _ =
        print_endline [%bin_digest: t];
        [%expect {| 4d15f34ac3361b8d8e21e214bee07c1c |}]
      ;;

      let of_model m =
        let { V2.remote_repo_path; bookmarks } = V2.of_model m in
        { remote_repo_path
        ; bookmarks
          = List.map bookmarks ~f:Hydra_state_for_bookmark.Stable.V1.of_v2
        }
      ;;

      let to_model { remote_repo_path; bookmarks } =
        V2.to_model
          { remote_repo_path
          ; bookmarks
            = List.map bookmarks ~f:Hydra_state_for_bookmark.Stable.V1.to_v2
          }
      ;;
    end

    module Model = V2
  end

  module Reaction = struct
    module V1 = struct
      type t =
        { bookmarks_to_rerun : string list
        }
      [@@deriving bin_io, sexp]

      let%expect_test _ =
        print_endline [%bin_digest: t];
        [%expect {| 4ec4f656953b5b54955c7127893a47e3 |}]
      ;;

      let of_model t = t
      let to_model t = t
    end

    module Model = V1
  end
end

include Iron_versioned_rpc.Make
    (struct let name = "synchronize-state" end)
    (struct let version = 2 end)
    (Stable.Action.V2)
    (Stable.Reaction.V1)

include Register_old_rpc_converting_both_ways
    (struct let version = 1 end)
    (Stable.Action.V1)
    (Stable.Reaction.V1)

module Action   = Stable.Action.   Model
module Reaction = Stable.Reaction. Model
