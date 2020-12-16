let api_key = "4c457b63f1cd43eabd488e4f2a9200aa"
let base_url = Uri.of_string "https://api.spoonacular.com/food/menuItems/search"

let get_definition_from_json json =
  match Yojson.Safe.from_string json with
  | `Assoc kv_list -> (
      let find key =
        match List.Assoc.find ~equal:String.equal kv_list key with
        | None | Some (`String "") -> None
        | Some s -> Some (Yojson.Safe.to_string s)
      in
      match find "menuItems" with Some _ as x -> x | None -> failwith "error" )
  | _ -> None

let print_result (word, definition) =
  printf "%s\n%s\n\n%s\n\n" word
    (String.init (String.length word) ~f:(fun _ -> '-'))
    ( match definition with
      | None -> "No definition found"
      | Some def -> String.concat ~sep:"\n" (Wrapper.wrap (Wrapper.make 70) def)
    )

let fetch_menu (restaurant: string) =
  let url = Uri.add_query_params' base_url
      [("apiKey", api_key);
       ("query", restaurant);
       ("number", "1000")] in
  Cohttp_async.Client.get url >>= fun (_, body) ->
  Cohttp_async.Body.to_string body >>| fun string ->
  (restaurant, get_definition_from_json string)

let search_and_print words =
  Deferred.all_unit
    (List.map words ~f:(fun word -> fetch_menu word >>| print_result))

let () =
  Command.async ~summary:"blah blah"
    Command.Let_syntax.(
      let%map_open words = anon (sequence ("word" %: string)) in
      fun () -> search_and_print words)
  |> Command.run