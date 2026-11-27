(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let html_escape s =
  let buffer = Buffer.create (String.length s * 2) in
  s |> String.iter begin function
    | '&' -> Buffer.add_string buffer "&amp;"
    | '<' -> Buffer.add_string buffer "&lt;"
    | '>' -> Buffer.add_string buffer "&gt;"
    | '"' -> Buffer.add_string buffer "&quot;"
    | '\'' -> Buffer.add_string buffer "&#x27;"
    | c -> Buffer.add_char buffer c
    end;
  Buffer.contents buffer



let to_base64url string =
  Base64.encode_string ~pad:false ~alphabet:Base64.uri_safe_alphabet string

(* Only canonical input is accepted (RFC 4648 sections 3.3 and 3.5): no
   impossible lengths such as "Z", zero pad bits, so "Zh" is rejected while
   "Zg" decodes to "f", and either no padding or exactly the right padding
   ("Zg==", but not "Zg=" or "Zg==="). Checking that the result re-encodes to
   the input, with or without padding, covers all three. *)
let from_base64url string =
  match Base64.decode ~pad:false ~alphabet:Base64.uri_safe_alphabet string with
  | Error _ -> None
  | Ok result ->
    let padded =
      Base64.encode_string ~pad:true ~alphabet:Base64.uri_safe_alphabet result
    in
    if to_base64url result = string || padded = string then Some result
    else None



(* Each pair is split at its first '=', so a value may contain '='
   ("keebler=E=mc2"). A piece with no '=' is dropped. The pairs are returned in
   header order, so [Dream.cookie] returns the first of duplicate names.

   Open question (test/expect/pure/formats/cookie/imported.ml): values wrapped
   in DQUOTEs keep their quotes; Go, Werkzeug and CPython strip them, and RFC
   6265 allows the quoted form of cookie-value. Do clients send quoted values
   in practice? Dream's own encrypted cookies are unaffected either way. *)
let from_cookie s =
  s
  |> String.split_on_char ';'
  |> List.filter_map (fun pair ->
    match String.index_opt pair '=' with
    | None -> None
    | Some i ->
      let name = String.sub pair 0 i in
      let value = String.sub pair (i + 1) (String.length pair - i - 1) in
      Some (String.trim name, String.trim value))
(* Note: found ocaml-cookie and http-cookie libraries, but they appear to have
   equivalent code for parsing Cookie: headers, so there is no point in using
   them yet, especially as they have stringent OCaml version constraints for
   other parts of their code. *)
(* Note: this parser doesn't actually appear to comply with the RFC strictly. It
   accepts more characters than the spec allows. It doesn't treate DQUOTE
   specially. This might not be important, however, if user agents treat cookies
   as opaque, because then only Dream has to deal with its own cookies. *)

(* HTTP-date in IMF-fixdate form, e.g. [Sun, 06 Nov 1994 08:49:37 GMT]. This is
   the format of [Expires] in [Set-Cookie:] (RFC 6265 §4.1.1) and of HTTP header
   dates such as [Last-Modified:] (RFC 9110 §5.6.7). Returns [None] if [seconds]
   is not representable as a date. *)
let to_http_date seconds =
  match Ptime.of_float_s seconds with
  | None -> None
  | Some time ->
    let weekday =
      match Ptime.weekday time with
      | `Sun -> "Sun" | `Mon -> "Mon" | `Tue -> "Tue" | `Wed -> "Wed"
      | `Thu -> "Thu" | `Fri -> "Fri" | `Sat -> "Sat"
    in
    let ((y, m, d), ((hh, mm, ss), _tz_offset_s)) = Ptime.to_date_time time in
    let month =
      match m with
      | 1 -> "Jan" | 2 -> "Feb" | 3 -> "Mar" | 4 -> "Apr" | 5 -> "May"
      | 6 -> "Jun" | 7 -> "Jul" | 8 -> "Aug" | 9 -> "Sep" | 10 -> "Oct"
      | 11 -> "Nov" | 12 -> "Dec"
      | _ -> assert false
    in
    (* [Ptime.to_date_time] docs give range 0..60 for [ss], accounting for
       leap seconds. However, RFC 6265 §5.1.1 states:

       5.  Abort these steps and fail to parse the cookie-date if:

         *  the second-value is greater than 59.

         (Note that leap seconds cannot be represented in this syntax.)

       See https://tools.ietf.org/html/rfc6265#section-5.1.1.

       Even though [Ptime.to_date_time] time does not return leap seconds, in
       case I misunderstood the gmtime API, of system differences, or future
       refactoring, make sure no leap seconds creep into the output. *)
    let seconds =
      if ss < 60 then ss else 59 [@coverage off]
    in
    (* IMF-fixdate has a four-digit year, and RFC 6265 date parsers read a
       two-digit year such as "49" as 2049. *)
    Some (Printf.sprintf "%s, %02i %s %04i %02i:%02i:%02i GMT"
      weekday d month y hh mm seconds)



(* The three HTTP-date formats (RFC 9110 section 5.6.7): IMF-fixdate
   ("Sun, 06 Nov 1994 08:49:37 GMT"), the obsolete RFC 850 format
   ("Sunday, 06-Nov-94 08:49:37 GMT") and asctime ("Sun Nov  6 08:49:37 1994").
   Returns the time in seconds since the epoch. Names are case-sensitive, as in
   the grammar, and the day name is not checked against the date. A two-digit
   RFC 850 year from 69 is read as 19xx, and below 69 as 20xx, as Go does. *)
let from_http_date string =
  let month = function
    | "Jan" -> Some 1 | "Feb" -> Some 2 | "Mar" -> Some 3 | "Apr" -> Some 4
    | "May" -> Some 5 | "Jun" -> Some 6 | "Jul" -> Some 7 | "Aug" -> Some 8
    | "Sep" -> Some 9 | "Oct" -> Some 10 | "Nov" -> Some 11 | "Dec" -> Some 12
    | _ -> None
  in
  let make year month_name day hours minutes seconds =
    match month month_name with
    | None -> None
    | Some month ->
      if hours > 23 || minutes > 59 || seconds > 60 then
        None
      else
        Ptime.of_date_time
          ((year, month, day), ((hours, minutes, seconds), 0))
        |> Option.map Ptime.to_float_s
  in
  let attempt format =
    try format () with Scanf.Scan_failure _ | Failure _ | End_of_file -> None
  in
  let imf_fixdate () =
    Scanf.sscanf string "%3s, %2u %3s %4u %2u:%2u:%2u GMT%!"
      (fun _ day month year hours minutes seconds ->
        make year month day hours minutes seconds)
  in
  let rfc850 () =
    Scanf.sscanf string "%[A-Za-z], %2u-%3s-%2u %2u:%2u:%2u GMT%!"
      (fun _ day month year hours minutes seconds ->
        let year = if year >= 69 then 1900 + year else 2000 + year in
        make year month day hours minutes seconds)
  in
  let asctime () =
    Scanf.sscanf string "%3s %3s %2u %2u:%2u:%2u %4u%!"
      (fun _ month day hours minutes seconds year ->
        make year month day hours minutes seconds)
  in
  match attempt imf_fixdate with
  | Some _ as time -> time
  | None ->
    match attempt rfc850 with
    | Some _ as time -> time
    | None -> attempt asctime



(* Divergence (test/expect/pure/formats/cookie/imported.ml, Go
   writeSetCookiesTests and TestCookieSanitize*, jshttp/cookie invalid name,
   value, domain and path lists): names, values, Domain and Path are emitted
   verbatim, including ';' and spaces, so "Domain=example.com; Path=/" or
   "Path=/; Path=/sensitive-data" inject attributes. Encrypted cookies are
   base64url and unaffected; names, Domain, Path and values passed to
   [Dream.set_cookie ~encrypt:false] are not.

   Decision needed: raise Invalid_argument (jshttp), sanitize (Go removes
   invalid bytes and quotes values containing spaces or commas), or drop the
   attribute or cookie (Go, for invalid domains and names). Part of this was
   reported privately as a security issue; the decision waits for that
   report. *)
(* 1601-01-01T00:00:00Z. *)
let first_cookie_date = -11644473600.

(* User agents cap Max-Age at 400 days (RFC 6265bis section 5.6.2). *)
let max_cookie_age = 34560000.

let to_set_cookie
    ?expires ?max_age ?domain ?path ?secure ?http_only ?same_site name value =

  (* The cookie-date grammar of RFC 6265 starts at 1601, so earlier dates are
     omitted, as Go does. *)
  let expires =
    match expires with
    | Some seconds when seconds < first_cookie_date -> ""
    | _ ->
      match Option.bind expires to_http_date with
      | None -> ""
      | Some date -> "; Expires=" ^ date
  in

  let max_age =
    match max_age with
    | None -> ""
    | Some seconds when Float.is_nan seconds -> ""
    | Some seconds ->
      (* [Float.max] also turns -0. into 0., which would print as "-0". *)
      let seconds = Float.min max_cookie_age (Float.max 0. (floor seconds)) in
      Printf.sprintf "; Max-Age=%.0f" seconds
  in

  let domain =
    match domain with
    | None -> ""
    | Some domain -> Printf.sprintf "; Domain=%s" domain
  in

  let path =
    match path with
    | None -> ""
    | Some path -> Printf.sprintf "; Path=%s" path
  in

  let secure =
    match secure with
    | Some true -> "; Secure"
    | _ -> ""
  in

  let http_only =
    match http_only with
    | Some true -> "; HttpOnly"
    | _ -> ""
  in

  let same_site =
    match same_site with
    | None -> ""
    | Some `Strict -> "; SameSite=Strict"
    | Some `Lax -> "; SameSite=Lax"
    | Some `None -> "; SameSite=None"
  in

  Printf.sprintf "%s=%s%s%s%s%s%s%s%s"
    name value expires max_age domain path secure http_only same_site



let iri_safe_octets =
  String.init 128 (fun i -> Char.chr (i + 128))

let iri_generic =
  `Custom (`Generic, iri_safe_octets, "")

let to_percent_encoded ?(international = true) string =
  let component =
    if international then iri_generic
    else `Generic
  in
  Uri.pct_encode ~component string

let from_percent_encoded string =
  Uri.pct_decode string



let to_form_urlencoded dictionary =
  dictionary
  |> List.map (fun (name, value) -> name, [value])
  |> Uri.encoded_of_query

(* Decision needed (test/expect/pure/formats/form_urlencoded/imported.ml):
   "&" decodes to two ("", "") pairs, and "a=b&c=d&" gains a trailing one.
   WHATWG (web-platform-tests), CPython and Node all skip empty pieces. This
   reaches [Dream.form] and [Dream.all_queries]. [Uri.query_of_encoded] also
   splits values on ',', hence the rejoin below. Skipping empty pieces is the
   better behaviour, but changes the fields existing apps receive for such
   input. *)
let from_form_urlencoded string =
  if string = "" then
    []
  else
    (* [Uri.query_of_encoded] replaces '+' in place, which changes its argument
       on OCaml >= 5.5 when the string has no '&' and no '=' (mirage/ocaml-uri
       issue #185), so give it a copy. *)
    Bytes.to_string (Bytes.of_string string)
    |> Uri.query_of_encoded
    |> List.map (fun (name, values) -> name, String.concat "," values)



let split_origin_form string =
  (* [string] is an origin-form target (RFC 9112 §3.2.1): an absolute path,
     optionally followed by a query, and with no authority. Drop the fragment
     (everything from the first '#'), then split the path and query at the first
     '?'. The path is decoded per segment, reproducing [Uri.path] without running
     the whole target through [Uri.of_string], which misreads a leading "//" as
     introducing a host (issue #248) and so drops path components. Decoding per
     pre-split segment also preserves a standalone "%2F" segment, which
     [Uri.path] would otherwise collapse to a bare '/'. *)
  let string =
    match String.index_opt string '#' with
    | Some i -> String.sub string 0 i
    | None -> string
  in
  let path, query =
    match String.index_opt string '?' with
    | Some i ->
      String.sub string 0 i,
      String.sub string (i + 1) (String.length string - i - 1)
    | None -> string, ""
  in
  (* Decision needed (test/expect/server/router_imported.ml,
     test/expect/pure/formats/target/imported.ml): decoding turns "%2e%2e" into
     "..", and [from_path] below drops empty segments. So "/a/../c" binds a
     route parameter to "..", "/static/%2e%2e/etc/passwd" reaches a "**"
     handler as "/../etc/passwd", and "/x//z" matches "/x/z" with no redirect.
     [Dream.static] rejects such paths itself; other "**" handlers do not.
     Options: redirect to the cleaned path (Go), answer 400 (Plug, send,
     actix), or leave it to handlers and document it. Interacts with
     [Dream.trailing_slash]. *)
  let path =
    String.split_on_char '/' path
    |> List.map (fun segment ->
      Uri.pct_encode ~component:`Path (Uri.pct_decode segment))
    |> String.concat "/"
  in
  path, query

(* "host:port": no '/', and digits after the last ':'. The host may be an IPv6
   literal in brackets, which contains ':' itself. *)
let is_authority_form string =
  not (String.contains string '/') &&
  match String.rindex_opt string ':' with
  | None -> false
  | Some i ->
    let port = String.sub string (i + 1) (String.length string - i - 1) in
    let is_digit c = c >= '0' && c <= '9' in
    (* Not String.for_all, which needs OCaml 4.13; dream-pure supports 4.08. *)
    port <> "" && Seq.fold_left (fun ok c -> ok && is_digit c) true
      (String.to_seq port)

let split_target string =
  (* Only origin-form targets (the common case) begin with '/', and they are the
     only form affected by the leading-"//" bug (issue #248), so handle them
     directly. Absolute-form (proxied requests, e.g. "http://host/path"),
     authority-form, and asterisk-form legitimately carry an authority or are not
     a path at all; defer those to [Uri.of_string], which parses the authority
     correctly. *)
  if String.length string > 0 && string.[0] = '/' then
    split_origin_form string
  else
    (* The authority-form (RFC 9112 section 3.2.3), used only with CONNECT, is
       "host:port" and has no path. [Uri.of_string] would read "host" as a
       scheme and "port" as the path. *)
    if is_authority_form string then
      "", ""
    else
      let uri = Uri.of_string string in
      let query =
        match Uri.verbatim_query uri with
        | Some query -> query
        | None -> ""
      in
      (* An absolute-form target with an empty path, such as "http://h", has
         the path "/" (RFC 9112 section 3.2.2). *)
      let path =
        match Uri.path uri, Uri.host uri with
        | "", Some _ -> "/"
        | path, _ -> path
      in
      path, query

let from_path =
  (* Not tail-recursive. *)
  let rec filter_components = function
    | [] -> []
    | [""] as components -> components
    | ""::components -> filter_components components
    | component::components -> component::(filter_components components)
  in

  fun string ->
    let components =
      if string = "" then
        []
      else
        String.split_on_char '/' string
        |> filter_components
        |> List.map Uri.pct_decode
    in

    components

(* Not tail-recursive. Only called on the site prefix and route fragments during
   app setup. *)
let rec drop_trailing_slash = function
  | [] -> []
  | [""] -> []
  | component::components ->
    component::(drop_trailing_slash components)

let to_path ?(relative = false) ?(international = true) components =
  let rec filter_empty_components = function
    | ""::(_::_ as path) -> filter_empty_components path
    | component::path -> component::(filter_empty_components path)
    | [] -> []
  in
  let components = filter_empty_components components in

  let components =
    match relative, components with
    | false, [] -> [""; ""]
    | false, _ -> ""::components
    | true, _ -> components
  in

  components
  |> List.map (to_percent_encoded ~international)
  |> String.concat "/"



let text_html =
  "text/html; charset=utf-8"

let application_json =
  "application/json"
