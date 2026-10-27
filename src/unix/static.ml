(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



module Formats = Dream_pure.Formats
module Message = Dream_pure.Message
module Method = Dream_pure.Method
module Router = Dream__server.Router
module Stream = Dream_pure.Stream



(* TODO Not at all efficient; can at least stream the file, maybe even cache. *)
(* TODO Also mind newlines on Windows. *)
(* TODO NOTE Using Lwt_io because it has a nice "read the whole thing"
   function. *)

let mime_lookup filename =
  let content_type =
    match Magic_mime.lookup filename with
    | "text/html" -> Formats.text_html
    | content_type -> content_type
  in
  ["Content-Type", content_type]

(* HTTP-date (IMF-fixdate) formatting, RFC 9110 §5.6.7, e.g.
   [Sun, 06 Nov 1994 08:49:37 GMT]. Built from [Unix.gmtime] rather than pulling
   in [ptime] as a dependency of this sub-library. Mirrors the date formatting in
   [Dream_pure.Formats.to_set_cookie]. *)
let http_date seconds =
  let tm = Unix.gmtime seconds in
  let weekday =
    match tm.Unix.tm_wday with
    | 0 -> "Sun" | 1 -> "Mon" | 2 -> "Tue" | 3 -> "Wed"
    | 4 -> "Thu" | 5 -> "Fri" | 6 -> "Sat"
    | _ -> assert false
  in
  let month =
    match tm.Unix.tm_mon with
    | 0 -> "Jan" | 1 -> "Feb" | 2 -> "Mar" | 3 -> "Apr" | 4 -> "May"
    | 5 -> "Jun" | 6 -> "Jul" | 7 -> "Aug" | 8 -> "Sep" | 9 -> "Oct"
    | 10 -> "Nov" | 11 -> "Dec"
    | _ -> assert false
  in
  let d = tm.Unix.tm_mday in
  let y = tm.Unix.tm_year + 1900 in
  let hh = tm.Unix.tm_hour in
  let mm = tm.Unix.tm_min in
  let ss = tm.Unix.tm_sec in
  Printf.sprintf "%s, %02d %s %04d %02d:%02d:%02d GMT" weekday d month y hh mm ss

(* A strong ETag derived from the file's contents, so that a redeploy that
   rewrites a file without changing it (same bytes, new mtime) still validates.
   The file is already fully read into memory, so hashing it is cheap relative to
   the read. *)
let etag content =
  Printf.sprintf "\"%s\"" Digestif.SHA1.(to_hex (digest_string content))

let from_filesystem local_root path _ =
  let file = Filename.concat local_root path in
  Lwt.catch
    (fun () ->
      let%lwt stats = Lwt_unix.stat file in
      Lwt_io.(with_file ~mode:Input file) (fun channel ->
        let%lwt content = Lwt_io.read channel in
        let headers =
          mime_lookup path @ [
            "ETag", etag content;
            "Last-Modified", http_date stats.Unix.st_mtime;
          ]
        in
        Message.response
          ~headers (Stream.string content) Stream.null
        |> Lwt.return))
    (fun _exn ->
      Message.response ~status:`Not_Found Stream.empty Stream.null
      |> Lwt.return)

(* TODO Add Content-Length handling? *)
(* TODO Support HEAD requests? *)

(* TODO On Windows, should we also check for \ and drive letters? *)
(* TODO Not an efficient implementation at the moment. *)
let validate_path request =
  let path = Router.path request in

  let has_slash component = String.contains component '/' in
  let has_backslash component = String.contains component '\\' in
  let has_slash = List.exists has_slash path in
  let has_backslash = List.exists has_backslash path in
  let has_dot = List.exists ((=) Filename.current_dir_name) path in
  let has_dotdot = List.exists ((=) Filename.parent_dir_name) path in
  let has_empty = List.exists ((=) "") path in
  let is_empty = path = [] in

  if has_slash ||
     has_backslash ||
     has_dot ||
     has_dotdot ||
     has_empty ||
     is_empty then
    None

  else
    let path = String.concat Filename.dir_sep path in
    if Filename.is_relative path then
      Some path
    else
      None

(* Weak comparison of an [If-None-Match] entity-tag list against our tag, per
   RFC 9110 §8.8.3.2 / §13.1.2. [*] matches any current representation, and the
   weakness prefix [W/] is ignored when comparing. *)
let strip_weak tag =
  if String.length tag >= 2 && tag.[0] = 'W' && tag.[1] = '/' then
    String.sub tag 2 (String.length tag - 2)
  else
    tag

let if_none_match request etag =
  let matches tag = strip_weak (String.trim tag) = strip_weak etag in
  match Message.header request "If-None-Match" with
  | None -> false
  | Some value ->
    let value = String.trim value in
    value = "*" || List.exists matches (String.split_on_char ',' value)

(* [If-Modified-Since] is only consulted when there is no [If-None-Match]
   (RFC 9110 §13.1.3). We generate [Last-Modified] ourselves, so a conservative
   exact-match against the value we would send covers the usual case where the
   client echoes it back; a mismatch simply falls through to a normal [200],
   which is always safe. *)
let if_modified_since request last_modified =
  match Message.header request "If-Modified-Since" with
  | None -> false
  | Some value -> String.trim value = last_modified

(* Turn a fresh (validated) response into a [304 Not Modified]: no body, and only
   the headers a 304 is allowed to carry (RFC 9110 §15.4.5). *)
let not_modified response =
  let allowed =
    ["etag"; "last-modified"; "cache-control"; "expires"; "vary"; "date"]
  in
  let is_allowed (name, _) = List.mem (String.lowercase_ascii name) allowed in
  let headers = List.filter is_allowed (Message.all_headers response) in
  Message.response ~status:`Not_Modified ~headers Stream.empty Stream.null

(* Precedence follows the request, not the response: [If-Modified-Since] is
   consulted only when the request has no [If-None-Match] (RFC 9110 §13.1.3), so
   dispatch on which request header is present rather than on which validator the
   response happens to carry. *)
let is_fresh request response =
  if Message.has_header request "If-None-Match" then
    match Message.header response "ETag" with
    | Some etag -> if_none_match request etag
    | None -> false
  else
    match Message.header response "Last-Modified" with
    | Some last_modified -> if_modified_since request last_modified
    | None -> false

let static ?(loader = from_filesystem) local_root = fun request ->

  if not @@ Method.methods_equal (Message.method_ request) `GET then
    Message.response ~status:`Not_Found Stream.empty Stream.null
    |> Lwt.return

  else
    match validate_path request with
    | None ->
      Message.response ~status:`Not_Found Stream.empty Stream.null
      |> Lwt.return

    | Some path ->
      let%lwt response = loader local_root path request in
      if not (Message.has_header response "Content-Type") then begin
        match Message.status response with
        | `OK
        | `Non_Authoritative_Information
        | `No_Content
        | `Reset_Content
        | `Partial_Content ->
          Message.add_header response "Content-Type" (Magic_mime.lookup path)
        | _ ->
          ()
      end;
      if Message.status response = `OK && is_fresh request response then
        Lwt.return (not_modified response)
      else
        Lwt.return response
