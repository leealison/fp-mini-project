open Core
open Async

type nutrients =
  {
    calories: int;
    total_fat: int;
    saturated_fat: int;
    cholesterol: int;
    sodium: int;
    carbs: int;
    fiber: int;
    sugar: int;
    potassium: int;
  }

let api_key = "4c457b63f1cd43eabd488e4f2a9200aa"
let base_url = Uri.of_string "https://api.spoonacular.com/food/menuItems/search"

module Menu = struct
  let get_menu_from_json json =
    match Yojson.Safe.from_string json with
    | `Assoc kv_list -> (
        let find key =
          match List.Assoc.find ~equal:String.equal kv_list key with
          | None | Some (`String "") -> None
          | Some s -> Some (Yojson.Safe.to_string s)
        in
        match find "menuItems" with
        | Some x ->
          if String.length x <= 2 then failwith "Restaurant is not available."
          else Some x
        | None -> failwith "Couldn't find the menuItems field in the response." )
    | _ -> failwith "There is something wrong with the response."

  let fetch_menu (restaurant: string) =
    let url = Uri.add_query_params' base_url
        [("apiKey", api_key);
         ("query", restaurant);
         ("number", "1")] in
    Cohttp_async.Client.get url >>= fun (_, body) ->
    Cohttp_async.Body.to_string body >>| fun string ->
    (restaurant, get_menu_from_json string)

  let check_result (word, definition) =
  printf "%s\n%s\n\n%s\n\n" word
    (String.init (String.length word) ~f:(fun _ -> '-'))
    ( match definition with
      | None -> "No definition found"
      | Some def -> String.concat ~sep:"\n" (Wrapper.wrap (Wrapper.make 70) def)
    )

  let generate_and_print restaurant =
    fetch_menu restaurant >>| check_result
end

let () =
  Command.async ~summary:"Generate meals at restaurants."
    Command.Let_syntax.(
      let%map_open
        restaurant = anon ("restaurant" %: string) in
      fun () -> let module M = Menu in M.generate_and_print restaurant)
  |> Command.run

