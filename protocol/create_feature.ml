module Stable = struct

  open Import_stable

  module Action = struct
    module V4 = struct
      type t =
        { feature_path                : Feature_path.V1.t
        ; owners                      : User_name.V1.t list
        ; is_permanent                : bool
        ; description                 : string
        ; base                        : Rev.V1.t option
        ; tip                         : Rev.V1.t option
        ; add_whole_feature_reviewers : User_name.V1.Set.t
        ; rev_zero                    : Rev.V1.t
        ; remote_repo_path            : Remote_repo_path.V1.t option
        ; allow_non_cr_clean_base     : bool
        ; properties                  : Properties.V1.t option
        }
      [@@deriving bin_io, fields, sexp]

      let to_model t = t
    end
  end

  module Reaction = struct
    module V3 = struct
      type t =
        { remote_repo_path : Remote_repo_path.V1.t
        ; tip              : Rev.V1.t
        }
      [@@deriving bin_io, sexp]

      let of_model t = t
    end
  end
end

include Iron_versioned_rpc.Make
    (struct let name = "create-feature" end)
    (struct let version = 5 end)
    (Stable.Action.V4)
    (Stable.Reaction.V3)

module Action   = Stable.Action.V4
module Reaction = Stable.Reaction.V3