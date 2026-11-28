(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



module Formats = Dream_pure.Formats
module Message = Dream_pure.Message
module Stream = Dream_pure.Stream



(* Conditional-request handling for [Dream.static], shared by the Unix and
   MirageOS backends. It evaluates the request's preconditions against whatever
   validators ([ETag:], [Last-Modified:]) the loader put on its response. *)

(* The value of all [name] headers of [request], joined as a list (RFC 9110
   section 5.3), or [None] if there is none. *)
let header request name =
  match Message.headers request name with
  | [] -> None
  | values -> Some (String.trim (String.concat "," values))

(* An entity-tag list (RFC 9110 section 8.8.3): entity-tags, each an optional
   weakness prefix [W/] and a quoted opaque tag, separated by commas and
   optional whitespace. Opaque tags may contain commas. Returns the tags as
   (weak, opaque tag with its quotes), or [None] if the list is malformed. *)
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
      let weak, index =
        if index + 1 < length && value.[index] = 'W' && value.[index + 1] = '/'
        then true, index + 2
        else false, index
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
            let opaque = String.sub value index (next - index) in
            parse ((weak, opaque)::tags) next
  in
  parse [] 0

(* A precondition header: absent, [*], a list of entity-tags, or malformed. A
   header with no entity-tags, such as an empty one, counts as absent, as in Go
   and Starlette. *)
let entity_tag_condition request name =
  match header request name with
  | None -> `Absent
  | Some "*" -> `Any
  | Some value ->
    match parse_entity_tags value with
    | Some [] -> `Absent
    | Some tags -> `Tags tags
    | None -> `Malformed

let http_date request name =
  Option.bind (header request name) Formats.from_http_date

(* What evaluating the preconditions of a request for a [200 OK] response gives
   (RFC 9110 section 13.2.2): the response itself, [304 Not Modified], or
   [412 Precondition Failed]. Only [Dream.static] calls this, so the method is
   GET or HEAD. A validator the response does not carry, or a date that does
   not parse, makes the corresponding precondition ignored, except that an
   [If-Match] listing entity-tags fails without a strong ETag to compare
   with. *)
let evaluate request response =
  let etag =
    match Message.header response "ETag" with
    | None -> None
    | Some value ->
      match parse_entity_tags (String.trim value) with
      | Some [tag] -> Some tag
      | _ -> None
  in
  let last_modified =
    Option.bind (Message.header response "Last-Modified") (fun value ->
      Formats.from_http_date (String.trim value))
  in
  let strong_match (weak, opaque) =
    match etag with
    | Some (false, etag) -> not weak && opaque = etag
    | _ -> false
  in
  let weak_match (_, opaque) =
    match etag with
    | Some (_, etag) -> opaque = etag
    | None -> false
  in
  let modified_since date =
    match last_modified with
    | Some last_modified -> last_modified > date
    | None -> true
  in
  (* Steps 1 and 2: If-Match, or else If-Unmodified-Since. *)
  let precondition_failed =
    match entity_tag_condition request "If-Match" with
    | `Any -> false
    | `Tags tags -> not (List.exists strong_match tags)
    | `Malformed -> true
    | `Absent ->
      match http_date request "If-Unmodified-Since", last_modified with
      | Some date, Some _ -> modified_since date
      | _ -> false
  in
  if precondition_failed then
    `Precondition_failed
  else
    (* Steps 3 and 4: If-None-Match, or else If-Modified-Since. *)
    let not_modified =
      match entity_tag_condition request "If-None-Match" with
      | `Any -> true
      | `Tags tags -> List.exists weak_match tags
      | `Malformed -> false
      | `Absent ->
        match http_date request "If-Modified-Since", last_modified with
        | Some date, Some _ -> not (modified_since date)
        | _ -> false
    in
    if not_modified then `Not_modified else `Proceed

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

let precondition_failed response =
  let%lwt () = Message.close (Message.client_stream response) in
  Message.response ~status:`Precondition_Failed Stream.empty Stream.null
  |> Lwt.return

let respond request response =
  if Message.status response <> `OK then
    Lwt.return response
  else
    match evaluate request response with
    | `Proceed -> Lwt.return response
    | `Not_modified -> not_modified response
    | `Precondition_failed -> precondition_failed response
