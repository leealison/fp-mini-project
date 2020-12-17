(*  Information for one macronutrient of a food.  *)
type macros = {
  nutrient: string; (* calories, fiber, protein, etc. *)
  numbers: (float * string * float) (* amount, unit, DV% *)
}

(*  All macronutrient information for a food.  *)
type nutrition = {
  name: string; (* food name *)
  info: macros list
}

type meal = nutrition list

(*  Swap this out if I've used the API past the free limit.  *)
val api_key: string
(*  URL for searching for a restaurant's menu.  *)
val search_base_url: Uri.t
(*  URL for searching for a specific item. Leaving info_base_url as a
    string because the id is part of the URL rather than being a param
    for some reason.  *)
val info_base_url: string

(*  Sometimes converting a Yojson `String type to a string keeps the
    quotation marks, so removing them here. Otherwise, we won't be
    able to match correctly.  *)
val sanitize: string -> string

(*  For randomly picking items from the menu using List.nth_exn.  *)
module type Randomness = sig
  (*  Given a maximum integer value, return a pseudorandom integer
      from 0 (inclusive) to this value (exclusive). *)
  val int: int -> int
end

(*  Holds functionality for retrieving, accessing, validating menus.  *)
module type Menu = sig
  (*  Extract the "menuItems" field from json string.  *)
  val get_menu_from_json: string -> Yojson.Safe.t

  (*  Take response body from fetch_menu and checks if it is a
      valid match for the given restaurant. There are two cases:
      1. There were no matches for the query and so the menuItems field
        is empty.
      2. There was some match for the query, but it is not from the
        correct restaurant. This could occur because part of the query
        could match with a menu item's name at some other restaurant.
        If this is the case, then it suffices to take the menu item in
        the list and look at its restaurantChain field.
      Returns true if restaurant is valid.  *)
  val check_response: string * string -> bool

  (*  Extract the "id" field from every menu item in the given json
      string. Ids are a unique number assigned to each food in the API.  *)
  val get_id_list: string -> int list

  (*  Make a GET request to retrieve the restaurant's entire menu.
      Returns an int list of each menu item's ID.  *)
  val fetch_menu: string -> int list Async_kernel.Deferred.t

  (*  Given an id number, retrieve the id's nutrition information.  *)
  val fetch_menu_item: int -> Yojson.Safe.t Async_kernel.Deferred.t
end

module type Meal = sig
  type t = meal

  (*  Create a new macro, given a json of a menu item's nutrition info.  *)
  val make_new_macro: Yojson.Safe.t -> macros

  (*  Add a new menu item to the given meal.  *)
  val add: t -> Yojson.Safe.t -> t

  (*  Check if adding the given menu item to the meal would make it exceed
      the calorie limit (+100, for some leeway). Return -1 if the item has
      too any calories. Otherwise, return the item's calories.  *)
  val calorie_overflow: Yojson.Safe.t -> float -> float -> float

  (*  Randomly pick an id from the id list and add it to the meal if
      adding it still maintains the calorie limit. In order to get
      as close to the limit as possible, if calorie_overflow indicates
      that the current menu item would make the meal exceed the limit,
      we skip the item and try another one. If an appropriate menu
      item can't be found in 10 tries, we just return the meal. *)
  val generate_meal: int list -> nutrition list -> float ->
    int -> int -> nutrition list Async_kernel.Deferred.t

  (*  Get the given macro amount from the macro list.  *)
  val get_macro: macros list -> string -> float

  (*  Print meal and macronutrient summary.  *)
  val print_meal: t -> int -> int -> unit
end

(*  Make meal then print it.  *)
val make_and_print: string -> float -> unit Async_kernel.Deferred.t