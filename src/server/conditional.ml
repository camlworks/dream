(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



module Message = Dream_pure.Message
module Stream = Dream_pure.Stream



(* Conditional-request handling for [Dream.static], shared by the Unix and
   MirageOS backends. It evaluates the request's preconditions against whatever
   validators ([ETag:], [Last-Modified:]) the loader put on its response. *)

(* Weak comparison of an [If-None-Match] entity-tag list against our tag, per
   RFC 9110 §8.8.3.2 / §13.1.2. [*] matches any current representation, and the
   weakness prefix [W/] is ignored when comparing. *)
let strip_weak tag =
  if String.length tag >= 2 && tag.[0] = 'W' && tag.[1] = '/' then
    String.sub tag 2 (String.length tag - 2)
  else
    tag

(* An entity-tag list (RFC 9110 §8.8.3): entity-tags, each an optional weakness
   prefix [W/] and a quoted opaque tag, separated by commas and optional
   whitespace. Opaque tags may contain commas. Returns the opaque tags with
   their quotes, or [None] if the list is malformed. *)
let parse_entity_tags value =
  let length = String.length value in
  let is_separator c = c = ' ' || c = '\t' || c = ',' in
  let rec skip_separators index =
    if index < length && is_separator value.[index] then
      skip_separators (index + 1)
    else
      index
  in
  let rec parse tags index =
    let index = skip_separators index in
    if index >= length then
      Some (List.rev tags)
    else
      let index =
        if index + 1 < length && value.[index] = 'W' && value.[index + 1] = '/'
        then index + 2
        else index
      in
      if index >= length || value.[index] <> '"' then
        None
      else
        match String.index_from_opt value (index + 1) '"' with
        | None -> None
        | Some closing ->
          let next = closing + 1 in
          if next < length && not (is_separator value.[next]) then
            None
          else
            parse (String.sub value index (next - index)::tags) next
  in
  parse [] 0

let if_none_match request etag =
  let etag = strip_weak (String.trim etag) in
  match Message.header request "If-None-Match" with
  | None -> false
  | Some value ->
    let value = String.trim value in
    value = "*" ||
    match parse_entity_tags value with
    | Some tags -> List.mem etag tags
    | None -> false

(* [If-Modified-Since] is only consulted when there is no [If-None-Match]
   (RFC 9110 §13.1.3). We generate [Last-Modified] ourselves, so a conservative
   exact-match against the value we would send covers the usual case where the
   client echoes it back; a mismatch simply falls through to a normal [200],
   which is always safe. *)
let if_modified_since request last_modified =
  match Message.header request "If-Modified-Since" with
  | None -> false
  | Some value -> String.trim value = last_modified

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

(* Turn a fresh (validated) response into a [304 Not Modified]: no body, and only
   the headers a 304 is allowed to carry (RFC 9110 §15.4.5), plus
   [Last-Modified:], which that section permits for guiding cache updates. The
   original body is closed, since a custom loader may have given it a streamed
   body that would otherwise be left open. *)
let not_modified response =
  let allowed = [
    "cache-control";
    "content-location";
    "date";
    "etag";
    "expires";
    "last-modified";
    "vary";
  ] in
  let is_allowed (name, _) = List.mem (String.lowercase_ascii name) allowed in
  let headers = List.filter is_allowed (Message.all_headers response) in
  let%lwt () = Message.close (Message.client_stream response) in
  Message.response ~status:`Not_Modified ~headers Stream.empty Stream.null
  |> Lwt.return

let respond request response =
  if Message.status response = `OK && is_fresh request response then
    not_modified response
  else
    Lwt.return response
