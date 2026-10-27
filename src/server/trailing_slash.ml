(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream. *)



module Formats = Dream_pure.Formats
module Message = Dream_pure.Message
module Status = Dream_pure.Status



(* The router treats [/foo] and [/foo/] as distinct paths (see [Router] and
   [Formats.from_path]): [/foo] becomes [["foo"]] and [/foo/] becomes
   [["foo"; ""]]. That RFC-literal behavior is the framework default. This
   middleware lets an application pick a softer, uniform policy for the part of
   the site it is applied to. *)
type trailing_slash =
  | Strict           (* Leave [/foo] and [/foo/] distinct. *)
  | Drop             (* Rewrite [/foo/] to [/foo] internally, serve [200]. *)
  | Append           (* Rewrite [/foo] to [/foo/] internally, serve [200]. *)
  | Redirect_drop    (* Redirect [/foo/] to [/foo]. *)
  | Redirect_append  (* Redirect [/foo] to [/foo/]. *)

(* The root path is [[""]] (and the asterisk-form / empty target is [[]]).
   Neither has a "trailing" slash that can be dropped, and the root must never
   be rewritten to the empty path, so both are left untouched by every policy. *)
let is_root = function
  | [] | [""] -> true
  | _ -> false

let has_trailing_slash path =
  match List.rev path with
  | "" :: _ -> true
  | _ -> false

(* Build a redirect to the canonical form, preserving the query string. The
   location is root-relative and, like any [Dream.redirect] location, has the
   site prefix prepended by [with_site_prefix] on the way out, so this
   middleware must be placed inside [with_site_prefix]. *)
let redirect_to_canonical ?status request canonical_path =
  let status =
    match status with
    | Some status -> (status :> Status.redirection)
    | None -> `Moved_Permanently
  in
  let _path, query = Formats.split_target (Message.target request) in
  let location =
    let path = Formats.to_path canonical_path in
    if query = "" then path else path ^ "?" ^ query
  in
  Helpers.redirect ~status request location

let trailing_slash ?status policy next_handler request =
  let path = Router.path request in
  if is_root path then
    next_handler request
  else
    let trailing = has_trailing_slash path in
    match policy with
    | Strict ->
      next_handler request
    | Drop when trailing ->
      Router.set_path request (Formats.drop_trailing_slash path);
      next_handler request
    | Append when not trailing ->
      Router.set_path request (path @ [""]);
      next_handler request
    | Redirect_drop when trailing ->
      redirect_to_canonical ?status request (Formats.drop_trailing_slash path)
    | Redirect_append when not trailing ->
      redirect_to_canonical ?status request (path @ [""])
    | Drop | Append | Redirect_drop | Redirect_append ->
      (* Already in the canonical form for this policy. *)
      next_handler request
