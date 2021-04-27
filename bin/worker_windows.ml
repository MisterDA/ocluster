let name = "ocluster-worker"

type worker_opts = {
    registration_path: string;
    capacity: int;
    name: string;
    allow_push: string list;
    prune_threshold: float option;
    state_dir: string;
    obuilder: Cluster_worker.Obuilder_config.t option;
  }

let worker_opts registration_path capacity name allow_push prune_threshold state_dir obuilder =
  {
    registration_path;
    capacity;
    name;
    allow_push;
    prune_threshold;
    state_dir;
    obuilder;
  }

let main {registration_path; capacity; name; allow_push; prune_threshold; state_dir; obuilder} =
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
      Worker.main registration_path capacity name allow_push prune_threshold state_dir obuilder
  with
  | Failure _ ->
     Worker.main registration_path capacity name allow_push prune_threshold state_dir obuilder
  | e -> raise e

let install (_, arguments) =
  let module Svc = Winsvc.Make
    (struct
      let name = name
      let display = "OCluster Worker"
      let text = "Run a build worker"
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

let worker_opts_t =
  let open Worker in
  Term.(const worker_opts $ connect_addr $ capacity $ worker_name $ allow_push
        $ prune_threshold $ state_dir $ Obuilder_config.v)

let install_cmd =
  let doc = "Install the worker as a Windows Service using the provided arguments." in
  Term.(const install $ with_used_args worker_opts_t),
  Term.info "service-install" ~doc ~exits:Term.default_exits

let remove_cmd =
  let doc = "Remove the worker from Windows Services." in
  Term.(const remove $ const ()),
  Term.info "service-remove" ~doc ~exits:Term.default_exits

let cmd =
  let doc = "Run a build worker" in
  Term.(const main $ worker_opts_t),
  Term.info name ~doc ~version:Version.t

let () = Term.(exit @@ eval_choice cmd [install_cmd; remove_cmd])
