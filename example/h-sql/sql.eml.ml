module type DB = Caqti_lwt.CONNECTION

let list_comments =
  let query =
    let open Caqti.Templater in
    static T.(unit -->* t2 int string)
    "SELECT id, text FROM comment" in
  fun (module Db : DB) ->
    let%lwt comments_or_error = Db.collect_list query () in
    Caqti_lwt.or_fail comments_or_error

let add_comment =
  let query =
    let open Caqti.Templater in
    static T.(string -->. unit)
    "INSERT INTO comment (text) VALUES ($1)" in
  fun text (module Db : DB) ->
    let%lwt unit_or_error = Db.exec query text in
    Caqti_lwt.or_fail unit_or_error

let create_tables (module Db : DB) =
  let open Caqti.Templater in

  let create_comment =
    static T.(unit -->. unit)
      "CREATE TABLE IF NOT EXISTS comment ( \
        id INTEGER PRIMARY KEY AUTOINCREMENT, \
        text TEXT NOT NULL)" in

  let create_session =
    static T.(unit -->. unit)
      "CREATE TABLE IF NOT EXISTS dream_session ( \
        id TEXT PRIMARY KEY, \
        label TEXT NOT NULL, \
        expires_at REAL NOT NULL, \
        payload TEXT NOT NULL)" in

  let%lwt comment_result = Db.exec create_comment () in
  let%lwt () = Caqti_lwt.or_fail comment_result in
  let%lwt session_result = Db.exec create_session () in
  let%lwt () = Caqti_lwt.or_fail session_result in
  Lwt.return (Ok ())

let render comments request =
  <html>
  <body>

%   comments |> List.iter (fun (_id, comment) ->
      <p><%s comment %></p>
%   );

    <form method="POST" action="/">
      <%s! Dream.csrf_tag request %>
      <input name="text" autofocus>
    </form>

  </body>
  </html>

let () =
  let db_uri = "sqlite3:db.sqlite" in

  Lwt_main.run begin
    let%lwt init_result =
      Caqti_lwt_unix.with_connection (Uri.of_string db_uri) create_tables in
    Caqti_lwt.or_fail init_result
  end;

  Dream.run
  @@ Dream.logger
  @@ Dream.sql_pool db_uri
  @@ Dream.sql_sessions
  @@ Dream.router [

    Dream.get "/" (fun request ->
      let%lwt comments = Dream.sql request list_comments in
      Dream.html (render comments request));

    Dream.post "/" (fun request ->
      match%lwt Dream.form request with
      | `Ok ["text", text] ->
        let%lwt () = Dream.sql request (add_comment text) in
        Dream.redirect request "/"
      | _ ->
        Dream.empty `Bad_Request);

  ]
