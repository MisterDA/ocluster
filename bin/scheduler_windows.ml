let name = "ocluster-scheduler"

type scheduler_opts = {
    capnp: Capnp_rpc_unix.Vat_config.t;
    secrets_dir: string;
    pools: string list;
    prometheus_config: int option;
    state_dir: string;
    default_clients: string list;
  }

let scheduler_opts capnp secrets_dir pools prometheus_config state_dir default_clients =
  {
    capnp;
    secrets_dir;
    pools;
    prometheus_config;
    state_dir;
    default_clients;
  }

let main {capnp; secrets_dir; pools; prometheus_config; state_dir; default_clients} =
  let module Svc = Winsvc.Make
    (struct
      let name = name
      let display = ""
      let text = ""
      let arguments = []
      let stop () = () (* No easy way of stopping the service, let the Service
                          Manager kill it. *)
    end)
  in
  try
    Svc.run @@ fun () ->
      (* Services don't have access to stdout and stderr. Short-circuit any
        output here until we're sure that Logging doesn't use them. *)
      let sink = open_out_bin Filename.null in
      Unix.(dup2 (descr_of_out_channel sink) stderr;
            dup2 (descr_of_out_channel sink) stdout);
      Scheduler.main capnp secrets_dir pools prometheus_config state_dir default_clients
  with
  | Winsvc.Error_failed_service_controller_connect ->
     Scheduler.main capnp secrets_dir pools prometheus_config state_dir default_clients
  | e -> raise e

let install (_, arguments) =
  let module Svc = Winsvc.Make
    (struct
      let name = name
      let display = "OCluster Scheduler"
      let text = "Manage build workers"
      let arguments = arguments
      let stop () = ()
    end)
  in
  Svc.install ()

let remove () =
  let module Svc = Winsvc.Make
    (struct
      let name = name
      let display = ""
      let text = ""
      let arguments = []
      let stop () = ()
    end)
  in
  Svc.remove ()

open Cmdliner

let scheduler_opts_t =
  let open Scheduler in
  Term.(const scheduler_opts $ Capnp_rpc_unix.Vat_config.cmd $ secrets_dir $ pools $ listen_prometheus $ state_dir $ default_clients)

let install_cmd =
  let doc = "Install the scheduler as a Windows Service using the provided arguments." in
  Term.(const install $ with_used_args scheduler_opts_t),
  Term.info "service-install" ~doc ~exits:Term.default_exits

let remove_cmd =
  let doc = "Remove the scheduler from Windows Services." in
  Term.(const remove $ const ()),
  Term.info "service-remove" ~doc ~exits:Term.default_exits

let cmd =
  let doc = "Manage build workers" in
  Term.(const main $ scheduler_opts_t),
  Term.info name ~doc ~version:Version.t

let () = Term.(exit @@ eval_choice cmd [install_cmd; remove_cmd])
