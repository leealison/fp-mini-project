open Core
open Async
open Yojson.Safe

type macros = {
  nutrient: string;
  numbers: (float * string * float)
}

type nutrition = {
  name: string;
  info: macros list
}

type meal = nutrition list

exception Macro_not_available of unit

let api_key = "34d836ce58a34b8389fef681402b9e4a"
let search_base_url =
  Uri.of_string "https://api.spoonacular.com/food/menuItems/search"
let info_base_url = "https://api.spoonacular.com/food/menuItems"
let num_of_menu_items_to_generate = "1"

let sanitize word =
  let word = String.drop_prefix word 1 in
  String.drop_suffix word 1

module type Randomness = sig
  val int : int -> int
end

module Randomness = struct
  let int bound =
    Random.int bound
end

module type Menu = sig
  val get_menu_from_json: string -> Yojson.Safe.t
  val check_response: string * string -> bool
  val get_id_list: string -> int list
  val fetch_menu: string -> int list Deferred.t
  val fetch_menu_item: int -> Yojson.Safe.t Deferred.t
end

module Menu (Random: Randomness) = struct
  let get_menu_from_json json =
    let json_menu = Util.to_assoc @@ from_string json in
    match List.Assoc.find ~equal:String.equal json_menu "menuItems" with
    | None -> failwith "Unexpected response, could not find menuItems field!"
    | Some x -> x

  let check_response (restaurant, menu) =
    let json = get_menu_from_json menu in
    let items_string = Yojson.Safe.to_string json in
    if String.length items_string <= 2 then false
    else
      let items =
        json |> Util.to_list |> Util.filter_assoc |> List.nth_exn in
      let first_object = items 0 in
      let restaurant_field =
        List.nth_exn first_object 2 |> snd |> to_string |> sanitize in
      if String.compare restaurant restaurant_field = 0 then true
      else true

  let get_id_list menu_items =
    let json = get_menu_from_json menu_items in
    let id_json_list = Util.filter_member "id" @@ Util.to_list json in
    List.map id_json_list ~f:Util.to_int

  let fetch_menu restaurant =
    let url = Uri.add_query_params' search_base_url
        [("apiKey", api_key);
         ("query", restaurant);
         ("number", num_of_menu_items_to_generate)] in
    Cohttp_async.Client.get url >>= fun (_, body) ->
    Cohttp_async.Body.to_string body >>| fun menu_string ->
    if check_response (restaurant, menu_string) then
      get_id_list menu_string
    else failwith "check_response returned false"

  let fetch_menu_item id =
    let base_url = info_base_url ^ "/" ^ (Int.to_string id)
                   |> Uri.of_string in
    let url = Uri.add_query_param' base_url ("apiKey", api_key) in
    Cohttp_async.Client.get url >>= fun (_, body) ->
    Cohttp_async.Body.to_string body >>| fun json_string ->
    from_string json_string
end

module type Meal = sig
  val make_new_macro: Yojson.Safe.t -> macros
  val add: meal -> Yojson.Safe.t -> meal
  val calorie_overflow: Yojson.Safe.t -> float -> float -> float
  val generate_meal: int list -> nutrition list -> float -> int
    -> int -> nutrition list Deferred.t
  val get_macro: macros list -> string -> float
  val print_meal: meal -> int -> int -> string list -> unit
end

module Meal = struct
  module Menu = Menu (Randomness)

  let make_new_macro item =
    {
      nutrient = Util.member "title" item |> Util.to_string; (*here *)
      numbers = (
        Util.member "amount" item |> Util.to_float,
        Util.member "unit" item |> Util.to_string,
        Util.member "percentOfDailyNeeds" item |> Util.to_float
      )
    }

  let add meal menu_item =
    let nutrition_info = menu_item
                         |> Util.member "nutrition"
                         |> Util.member "nutrients"
                         |> Util.to_list in
    let macros = List.fold nutrition_info ~init:[] ~f:(fun macro_accum x ->
        make_new_macro x :: macro_accum) in
    let new_meal_item = {
      name = Util.member "title" menu_item |> Util.to_string;
      info = macros
    } in new_meal_item :: meal

  let calorie_overflow menu_item current_calories limit =
    let item_calories = menu_item
                        |> Util.member "nutrition"
                        |> Util.member "calories"
                        |> Util.to_float in
    let sum = current_calories +. item_calories in
    if Float.compare sum (limit +. 100.) > 0
    then -1. else item_calories

  let rec generate_meal ids meal limit calorie_sum length counter =
    if counter = 10 then return meal
    else
      let id = List.nth_exn ids @@ Random.int length in
      let%bind menu_item= Menu.fetch_menu_item id in
      let item_calories = calorie_overflow menu_item calorie_sum limit in
      if Float.(=) item_calories (-1.)
      then generate_meal ids meal limit calorie_sum length (counter + 1)
      else
        let new_meal = add meal menu_item in
        let new_calorie_sum = calorie_sum +. item_calories in
        if Float.(>) new_calorie_sum limit
        then return(new_meal)
        else generate_meal ids new_meal limit new_calorie_sum length 1

  let rec get_macro_info macros macro =
    match macros with
    | [] -> raise (Macro_not_available ())
    | { nutrient = x; numbers = y } :: tail ->
      if String.compare macro x = 0 then (fst3 y, snd3 y, trd3 y)
      else get_macro_info tail macro

  (*let rec print_macros macro =
    match macro with
    | []-> printf ""
    | {nutrient = x; numbers= _} :: tail -> printf "%s\n" x;
      print_macros tail printf "Total:\n%d calories\n" total_cals *)
end

let print_totals (meal: meal) macros_to_print =
  let module Meal = Meal in
  let rec get_stats_for_one_macro meal macro_to_get prev =
    match meal with
    | [] -> prev
    | {name = _; info = x} :: tail ->
      let info = Meal.get_macro_info x macro_to_get in
      if Float.(>=) (fst3 info) 0. then
        get_stats_for_one_macro tail macro_to_get
          ((fst3 info) +. (fst3 prev), (snd3 info), (trd3 info) +. (trd3 prev))
      else raise (Macro_not_available ()) in
  printf "Total:\n";
  List.iter macros_to_print ~f:(fun x ->
      try (
        let total = get_stats_for_one_macro meal x (0., "", 0.) in
        printf "%.5g%s %s, %.2g%% DV\n"
          (fst3 total) (snd3 total) (String.lowercase x)
          (trd3 total)
      ) with Macro_not_available () -> printf "";
    )

let print_meal meal number macros_to_print =
  let rec aux meal number macros_to_print =
    match meal with
    | [] -> ()
    | { name = x; info = y } :: tail ->
      let module Meal = Meal in
      printf "%d. %s\n" number x;
      List.iter macros_to_print ~f:(fun x ->
          try (
            let macro_info = Meal.get_macro_info y x in
            printf "    %.4g%s %s\n"
              (fst3 macro_info) (snd3 macro_info) (String.lowercase x)
          ) with Macro_not_available () -> printf ""
        );
      printf "\n";
      aux tail (number + 1) macros_to_print in
  aux meal number macros_to_print;
  print_totals meal macros_to_print

let make_and_print restaurant calories macros =
  let module Menu = Menu (Randomness) in
  let module Meal = Meal in
  let%bind ids = Menu.fetch_menu restaurant in
  let%bind meal = Meal.generate_meal ids [] calories 0. (List.length ids) 1 in
  printf "\n";
  (* If calorie limit was too low: *)
  if List.length meal = 0 then return @@ printf "No meals found for this calorie limit.\n"
  else return @@ print_meal meal 1 macros

let () =
  Command.async ~summary:"Generate meals at restaurants."
    Command.Let_syntax.(
      let%map_open
        restaurant = anon ("restaurant" %: string)
      and calories = anon ("calories" %: int)
      and macros = anon (sequence ("word" %: string)) in
      fun () ->
        let calories = Int.to_float calories in
        let macros = "Calories" :: macros in
        make_and_print restaurant calories macros)
  |> Command.run

