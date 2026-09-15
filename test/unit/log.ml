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
    |> Alcotest.(check bool) "called" true
  end;

]
