open Core
open Async
open Yojson.Safe

type macros = {
  nutrient: string; (* calories, fiber, protein, etc. *)
  numbers: (float * string * float) (* amount, unit, DV% *)
}

type nutrition = {
  name: string; (* food name *)
  info: macros list
}

type meal = nutrition list

let api_key = "ab38d331e24945d581fe7f0cb68a1e84"
let search_base_url =
  Uri.of_string "https://api.spoonacular.com/food/menuItems/search"
(*  Leaving info_base_url as a string because the id is part of the URL
    rather than being a param for some reason  *)
let info_base_url = "https://api.spoonacular.com/food/menuItems"

(*  Sometimes converting a Yojson `String type to a string keeps the
    quotation marks, so removing them here. Otherwise, we won't be
    able to match correctly  *)
let sanitize (word: string) =
  let word = String.drop_prefix word 1 in
  String.drop_suffix word 1

module type Randomness = sig
  (*  Given a maximum integer value, return a pseudorandom integer
      from 0 (inclusive) to this value (exclusive). *)
  val int : int -> int
end

module Randomness = struct
  let int (bound: int): int =
    Random.int bound
end

module Menu (Random: Randomness) = struct
  (*  Extract the "menuItems" field from json string.  *)
  let get_menu_from_json json =
    let json_menu = Util.to_assoc @@ from_string json in
    match List.Assoc.find ~equal:String.equal json_menu "menuItems" with
    | None -> failwith "Unexpected response, could not find menuItems field!"
    | Some x -> x

  (*  Takes response body from fetch_menu and checks if it is a
      valid match for the given restaurant. There are two cases:
      1. There were no matches for the query and so the menuItems field
        is empty.
      2. There was some match for the query, but it is not from the
        correct restaurant. This could occur because part of the query
        could match with a menu item's name at some other restaurant.
        If this is the case, then it suffices to take the menu item in
        the list and look at its restaurantChain field.  *)
  let check_response (restaurant, menu) =
    let json = get_menu_from_json menu in
    let items_string = Yojson.Safe.to_string json in
    if String.length items_string <= 2
    then failwith "Restaurant is not available!"
    else
      let items =
        json |> Util.to_list |> Util.filter_assoc |> List.nth_exn in
      let first_object = items 0 in
      let restaurant_field =
        List.nth_exn first_object 2 |> Core.snd |> to_string |> sanitize in (* here *)
      if String.compare restaurant restaurant_field = 0 then true
      else false

  (*  Extract the "id" field from every menu item in the json string.
      Ids are a unique number assigned to each food in the API. *)
  let get_id_list menu_items =
    let json = get_menu_from_json menu_items in
    let id_json_list = Util.filter_member "id" @@ Util.to_list json in
    List.map id_json_list ~f:Util.to_int

  (*  Make a GET request to retrieve the restaurant's entire menu.
      Returns an int list of each menu item's ID.  *)
  let fetch_menu restaurant =
    let url = Uri.add_query_params' search_base_url
        [("apiKey", api_key);
         ("query", restaurant);
         ("number", "10")] in
    Cohttp_async.Client.get url >>= fun (_, body) ->
    Cohttp_async.Body.to_string body >>| fun menu_string ->
    if check_response (restaurant, menu_string) then
      get_id_list menu_string
    else failwith "check_response returned false"

  (*  Given an id number, retrieve the id's nutrition information.  *)
  let fetch_menu_item id =
    let base_url = info_base_url ^ "/" ^ (Int.to_string id)
                   |> Uri.of_string in
    let url = Uri.add_query_param' base_url ("apiKey", api_key) in
    Cohttp_async.Client.get url >>= fun (_, body) ->
    Cohttp_async.Body.to_string body >>| fun json_string ->
    from_string json_string

  (*let generate_and_print restaurant =
    fetch_menu restaurant*)
end

module Meal = struct
  type t = meal
  module Menu = Menu (Randomness)

  (*  Creates a new macro type, given a json of a menu item's nutrition
      info.  *)
  let make_new_macro item =
    {
      nutrient = Util.member "title" item |> Util.to_string; (*here *)
      numbers = (
        Util.member "amount" item |> Util.to_float,
        Util.member "unit" item |> Util.to_string,
        Util.member "percentOfDailyNeeds" item |> Util.to_float
      )
    }

  (*  Adds a new menu item to the given meal type.  *)
  let add meal menu_item =
    let nutrition_info = menu_item
                         |> Util.member "nutrition"
                         |> Util.member "nutrients"
                         |> Util.to_list in
    let macros = List.fold nutrition_info ~init:[] ~f:(fun macro_accum x ->
        make_new_macro x :: macro_accum) in
    let new_meal_item = {
      name = Util.member "title" menu_item |> Util.to_string; (*here *)
      info = macros
    } in new_meal_item :: meal

  (*  Check if adding the given menu item to the meal would make it exceed
      the calorie limit.  *)
  let calorie_overflow menu_item current_calories limit =
    let item_calories = menu_item
                        |> Util.member "nutrition"
                        |> Util.member "calories"
                        |> Util.to_float in
    let sum = current_calories +. item_calories in
    if Float.compare sum (limit +. 100.) > 0
    then -1. else item_calories
  (* -1 means that item is too many calories to add to meal *)

  (*  Randomly pick an id from the id list and add it to the meal while still
      under the calorie limit.  *)
  let rec generate_meal ids meal (limit: float) (calorie_sum: float) length =
    let id = List.nth_exn ids @@ Random.int length in
    let%bind menu_item= Menu.fetch_menu_item id in
    let item_calories = calorie_overflow menu_item calorie_sum limit in
    if Float.(=) item_calories (-1.)
    then return meal
    else
      let new_meal = add meal menu_item in
      let new_calorie_sum = calorie_sum +. item_calories in
      if Float.(>) new_calorie_sum (limit -. 100.)
      then return(new_meal)
      else generate_meal ids new_meal limit new_calorie_sum length

  let rec get_macro (macros: macros list) macro =
    match macros with
    | [] -> failwith "replace this later"
    | { nutrient = x; numbers = y } :: tail ->
      if String.compare macro x = 0 then Core.fst3 y
      else get_macro tail macro

  let rec print_meal (meal: t) number =
    match meal with
    | [] -> ()
    | { name = x; info = y } :: tail ->
      printf "%d. %s " number x;
      printf "(%d calories)\n" (get_macro y "Calories" |> Float.to_int);
      print_meal tail @@ number + 1;;

  (* let print_totals*)
end

let print_ids ids =
  List.iter ids ~f:(fun x -> printf "%d\n" x)

let make_and_print restaurant calories =
  let module Menu = Menu (Randomness) in
  let module Meal = Meal in
  let%bind ids = Menu.fetch_menu restaurant in
  let%bind meal = Meal.generate_meal ids [] calories 0. (List.length ids) in
  return @@ Meal.print_meal meal 1

let () =
  Command.async ~summary:"Generate meals at restaurants."
    Command.Let_syntax.(
      let%map_open
        restaurant = anon ("restaurant" %: string)
      and calories = anon ("calories" %: int) in
      fun () ->
        let calories = Int.to_float calories in
        make_and_print restaurant calories)
  |> Command.run

