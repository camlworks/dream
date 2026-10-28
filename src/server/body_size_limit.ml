(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



module Message = Dream_pure.Message
module Stream = Dream_pure.Stream



(* Raised internally when a request body exceeds the configured limit. It is
   caught by the middleware below and turned into a 413 response. It travels
   through the request body stream's [~exn] callback, so it surfaces from
   [Dream.body], [Dream.read], and anything built on them. *)
exception Payload_too_large

(* Marks a request whose body exceeded the size limit. Adapters use this to
   stop reading the body and to choose the protocol-specific response. *)
let exceeded_field =
  Message.new_field
    ~name:"dream.body_size_limit.exceeded"
    ~show_value:string_of_bool
    ()

let exceeded request =
  Message.field request exceeded_field = Some true

(* Wraps a request body stream's reader so that it counts the bytes read, and
   raises [Payload_too_large] through [~exn] as soon as the running total would
   exceed [max_length]. The overflowing chunk is not forwarded, so a reader that
   accumulates (such as [Dream.body]) never buffers more than [max_length] plus
   one chunk. *)
let limit_reader max_length stream =
  let read = ref 0 in
  let read_fn ~data ~flush ~ping ~pong ~close ~exn =
    Stream.read stream
      ~data:(fun buffer offset length binary fin ->
        read := !read + length;
        if !read > max_length then
          exn Payload_too_large
        else
          data buffer offset length binary fin)
      ~flush ~ping ~pong ~close ~exn
  in
  Stream.reader
    ~read:read_fn
    ~close:(fun code -> Stream.close stream code)
    ~abort:(fun exn -> Stream.abort stream exn)

(* The declared length, if the request carries a single well-formed
   [Content-Length] header. httpun already rejects duplicate or malformed
   [Content-Length] values before the request reaches the application. *)
let declared_length request =
  match Message.header request "Content-Length" with
  | None -> None
  | Some value -> int_of_string_opt (String.trim value)

let body_size_limit max_length =
  if max_length < 0 then
    invalid_arg "Dream.body_size_limit: negative limit";

  fun next_handler request ->
    let too_large () =
      Message.set_field request exceeded_field true;
      Helpers.respond ~status:`Payload_Too_Large ""
    in
    match declared_length request with
    (* Fast path: reject on the advertised length without reading the body. *)
    | Some length when length > max_length -> too_large ()
    | _ ->
      let limited =
        Stream.stream
          (limit_reader max_length (Message.server_stream request))
          Stream.no_writer
      in
      Message.set_server_stream request limited;
      Lwt.catch
        (fun () -> next_handler request)
        (function
          | Payload_too_large -> too_large ()
          | exn -> Lwt.fail exn)
