open! Core.Std
open! Async.Std
open! Import

let main { Fe.Archive.Action. feature_path; for_ } =
  let%bind repo_root =
    Cmd_workspace.repo_for_hg_operations_exn feature_path ~use:`Clone
  in
  let%bind () = ensure_can_access_remote_repo ~for_root_of:feature_path in
  (* Deleting the workspace will fail if there are unpushed or uncommitted changes.
     Run it before the archive query to give a chance to the user to reconsider if
     that is the case. *)
  let%bind () = Cmd_workspace.If_enabled.delete_workspace feature_path in
  let%bind rev_zero = Hg.create_rev_zero repo_root in
  let%bind feature =
    Get_feature.rpc_to_server_exn { feature_path; rev_zero  = Some rev_zero }
  in
  let%bind { remote_repo_path; send_email_to } =
    Archive_feature.rpc_to_server_exn { feature_path; rev_zero; for_ }
  in
  let%bind () =
    Cmd_unbookmarked_head.prune
      ~root_feature:(Feature_path.root feature_path)
      (Rev.with_human_readable feature.tip
         ~human_readable:(Feature_path.to_string feature_path))
  in
  let%bind () =
    Hg.delete_bookmarks repo_root [ Feature feature_path ] (`Push_to remote_repo_path)
  in
  if not am_functional_testing
  && Set.mem feature.send_email_upon Send_email_upon.archive
  then
    Core_extended.Sendmail.send
      (Cmd_show.render_email_body feature ~included_features_order:`Name)
      ~subject:(sprintf !"feature was archived: %{Feature_path}" feature_path)
      ~recipients:(List.map (Set.to_list send_email_to) ~f:Email_address.to_string);
  return ()
;;

let command =
  Command.async'
    ~summary:"archive a feature (it can later be unarchived)"
    (let open Command.Let_syntax in
     let%map_open () = return ()
     and feature_path = feature_path
     and for_ = for_
     in
     fun () ->
       let open! Deferred.Let_syntax in
       let feature_path = ok_exn feature_path in
       main { feature_path; for_ }
    )
;;
