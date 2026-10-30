(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



module Formats = Dream_pure.Formats
module Message = Dream_pure.Message
module Stream = Dream_pure.Stream



let rec match_site_prefix prefix path =
  match prefix, path with
  | prefix_crumb::prefix, path_crumb::path ->
    if path_crumb = prefix_crumb then
      match_site_prefix prefix path
    else
      None
  | [], path ->
    Some path
  | _ ->
    None



(* TODO The path and prefix representations and accessors need a cleanup. *)
let with_site_prefix prefix =
  let prefix =
    prefix
    |> Formats.from_path
    |> Formats.drop_trailing_slash
  in
  let prefix_path = Formats.to_path prefix in
  let prefix_location_header response =
    match Message.header response "Location" with
    | Some location
      when prefix <> [] (* prefix "/" is treated as no prefix *)
        && String.starts_with ~prefix:"/" location (* absolute path *)
        && not (String.starts_with ~prefix:"//" location) -> (* not scheme-relative path *)
      Message.set_header response "Location" (prefix_path ^ location)
    | _ -> ()
  in
  fun next_handler request ->
    match match_site_prefix prefix (Router.path request) with
    | None ->
      Message.response ~status:`Bad_Gateway Stream.empty Stream.null
      |> Lwt.return
    | Some path ->
      (* Stripping a non-empty prefix from a request for the site root leaves
         [[]] for [/app] but [[""]] for [/app/]. Normalize the former to the
         root path so that both forms route to ["/"] for consistency with the
         default behavior.
         https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2.3-4.2 *)
      let path =
        match prefix, path with
        | _::_, [] -> [""]
        | _ -> path
      in
      (* TODO This doesn't need to be recomputed on each request - can cache the
         result in the app. *)
      Router.set_site_prefix request prefix;
      Router.set_path request path;
      next_handler request
      |> Lwt.map (fun response ->
        prefix_location_header response;
        response)
