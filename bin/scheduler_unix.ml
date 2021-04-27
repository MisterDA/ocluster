open Scheduler
open Cmdliner

let cmd =
  let doc = "Manage build workers" in
  Term.(const main $ Capnp_rpc_unix.Vat_config.cmd $ secrets_dir $ pools $ listen_prometheus $ state_dir $ default_clients),
  Term.info "ocluster-scheduler" ~doc ~version:Version.t

let () = Term.(exit @@ eval cmd)
