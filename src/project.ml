open Core
open Async
open Yojson.Safe

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
  let fetch_menu (restaurant: string) =
    let url = Uri.add_query_params' base_url
        [("apiKey", api_key);
         ("query", restaurant);
         ("number", "1")] in
    Cohttp_async.Client.get url >>= fun (_, body) ->
    Cohttp_async.Body.to_string body >>| fun menu ->
    (restaurant, menu)

  (*  Takes response body from fetch_menu and checks if it is a valid
      valid match for the given restaurant. There are two cases:
      1. There were no matches for the query and so the menuItems field
        is empty
      2. There was some match for the query, but it is not from the
        correct restaurant. This could occur because part of the query
        could match with a menu item's name at some other restaurant.
        If this is the case, then it suffices to take the menu item in
        the list and look at its restaurantChain field.  *)
  let check_result (restaurant, menu) =
    let json_menu = Util.to_assoc @@ from_string menu in
    match List.Assoc.find ~equal:String.equal json_menu "menuItems" with
    | None -> failwith "Unexpected response, could not find menuItems field!"
    | Some x ->
      let items = Yojson.Safe.to_string x in
      if String.length items <= 2 then failwith "Restaurant is not available!"
      else
      let json = from_string items in
      let items = json |> Util.to_list |> Util.filter_assoc |> List.nth_exn in
      let first_object = items 0 in
      let restaurant_field = List.nth_exn first_object 2 |> Core.snd |> to_string in
      if String.equal restaurant restaurant_field then printf "woo" else printf "noo"

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

