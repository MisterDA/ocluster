open Worker
open Cmdliner

let cmd =
  let doc = "Run a build worker" in
  Term.(const main $ connect_addr $ capacity $ worker_name $ allow_push $ prune_threshold $ state_dir $ Obuilder_config.v),
  Term.info "ocluster-worker" ~doc ~version:Version.t

let () = Term.(exit @@ eval cmd)
