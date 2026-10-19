(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2026 funwithcthulhu *)



let (-:) name f = Alcotest.test_case name `Quick f



let tests = "log", [

  "default debug follows initialized level" -: begin fun () ->
    let called = ref false in
    Dream.initialize_log ~level:`Debug ();
    Dream.debug (fun log ->
      called := true;
      log "debug");
    !called
    |> Alcotest.(check bool) "debug enabled" true
  end;

  (* A sub-log created after initialization, with no explicit level, must
     inherit the global level. Setting the source's level to `None` in Logs
     means "never report", not "inherit", so this used to drop all messages. *)
  "sub-log after initialization inherits level" -: begin fun () ->
    Dream.initialize_log ~level:`Debug ();
    let log = Dream.sub_log "test.after-initialization" in
    let called = ref false in
    log.debug (fun log ->
      called := true;
      log "debug");
    !called
    |> Alcotest.(check bool) "debug enabled" true
  end;

  "explicit level overrides global level" -: begin fun () ->
    Dream.initialize_log ~level:`Debug ();
    let log = Dream.sub_log ~level:`Warning "test.explicit-level" in
    let called = ref false in
    log.info (fun log ->
      called := true;
      log "info");
    !called
    |> Alcotest.(check bool) "info suppressed" false
  end;

  "set_log_level overrides global level" -: begin fun () ->
    Dream.initialize_log ~level:`Debug ();
    let log = Dream.sub_log "test.set-log-level" in
    Dream.set_log_level "test.set-log-level" `Warning;
    let called = ref false in
    log.info (fun log ->
      called := true;
      log "info");
    !called
    |> Alcotest.(check bool) "info suppressed" false
  end;

  "custom log records success" -: begin fun () ->
    let called = ref false in
    let log = {
      Dream.error = (fun _ -> ());
      warning = (fun _ -> ());
      info = (fun _ -> called := true);
      debug = (fun _ -> ());
    } in
    let handler _request = Dream.respond "" in
    Dream.request ""
    |> Dream.logger ~log handler
    |> Lwt_main.run
    |> ignore;
    !called
    |> Alcotest.(check bool) "info logged" true
  end;

  "custom log records server error" -: begin fun () ->
    let called = ref false in
    let log = {
      Dream.error = (fun _ -> called := true);
      warning = (fun _ -> ());
      info = (fun _ -> ());
      debug = (fun _ -> ());
    } in
    let handler _request =
      Dream.respond ~status:`Internal_Server_Error ""
    in
    Dream.request ""
    |> Dream.logger ~log handler
    |> Lwt_main.run
    |> ignore;
    !called
    |> Alcotest.(check bool) "error logged" true
  end;

]
