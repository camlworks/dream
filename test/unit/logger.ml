(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2026 funwithcthulhu *)



let (-:) name f = Alcotest.test_case name `Quick f



type counts = {
  error : int;
  warning : int;
  info : int;
  debug : int;
}

let counting_log () =
  let error = ref 0
  and warning = ref 0
  and info = ref 0
  and debug = ref 0 in

  let log = {
    Dream.error = (fun _ -> incr error);
    warning = (fun _ -> incr warning);
    info = (fun _ -> incr info);
    debug = (fun _ -> incr debug);
  } in

  let counts () = {
    error = !error;
    warning = !warning;
    info = !info;
    debug = !debug;
  } in

  log, counts

let run_logger ?(status = `OK) () =
  let log, counts = counting_log () in
  let handler _request = Dream.respond ~status "" in
  Dream.request ""
  |> Dream.logger ~log handler
  |> Lwt_main.run
  |> ignore;
  counts ()



let counts =
  let pp ppf counts =
    Format.fprintf ppf
      "{ error = %i; warning = %i; info = %i; debug = %i }"
      counts.error counts.warning counts.info counts.debug
  in
  Alcotest.testable pp (=)



let tests = "logger", [

  "custom log records success" -: begin fun () ->
    run_logger ()
    |> Alcotest.(check counts) "counts"
      { error = 0; warning = 0; info = 2; debug = 0 }
  end;

  "custom log records server error" -: begin fun () ->
    run_logger ~status:`Internal_Server_Error ()
    |> Alcotest.(check counts) "counts"
      { error = 1; warning = 0; info = 1; debug = 0 }
  end;

]
