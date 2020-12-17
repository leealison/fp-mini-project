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

(*  When info about a given macro is not available, because
    the kinds of macros in the responses are not consistent.  *)
exception Macro_not_available of unit
(*  When a restaurant's menu is not available.  *)
exception Restaurant_not_available of string
(*  I can make a limited number of requests under a free
    plan with Spoonacular. This is a Yojson type because of the
    Yojson return type of the function it's raised in. *)
exception API_limit_reached of Yojson.Safe.t

(*  Swap this out if I've used the API past the free limit.  *)
val api_key: string
(*  URL for searching for a restaurant's menu.  *)
val search_base_url: Uri.t
(*  URL for searching for a specific item. Leaving info_base_url as a
    string because the id is part of the URL rather than being a param
    for some reason.  *)
val info_base_url: string

(*  Remove quotation marks around restaurant string from command line  *)
val remove_quotation_marks: string -> string

(*  Extract the output of get_menu_from_json from the result type.  *)
  val check_json: ('a, 'b) result -> 'a

(*  For randomly picking items from the menu using List.nth_exn.  *)
module type Randomness = sig
  (*  Given a maximum integer value, return a pseudorandom integer
      from 0 (inclusive) to this value (exclusive). *)
  val int: int -> int
end

(*  Holds functionality for retrieving, accessing, validating menus.  *)
module type Menu = sig
  (*  Extract the "menuItems" field from json string.
      @raises API_limit_reached if we get an unexpected response, which
      just means that the API limit was reached  *)
  val get_menu_from_json: string -> (Yojson.Safe.t, Yojson.Safe.t) result

  (*  Take response body from fetch_menu and checks if it is a
      valid match for the given restaurant. There are two cases:
      1. There were no matches for the query and so the menuItems field
        is empty.
      2. There was some match for the query, but it is not from the
        correct restaurant. This could occur because part of the query
        could match with a menu item's name at some other restaurant.
        If this is the case, then it suffices to take the menu item in
        the list and look at its restaurantChain field.
      Simply returns menu json string if restaurant is valid.
      @raises Restaurant_not_available when the restaurant is invalid.
      @raises Failure, caused by raising API_limit_reached since I had to
      convert from Yojson type to string type.  *)
  val check_response: string * string -> string

  (*  Extract the "id" field from every menu item in the given json
      string. Ids are a unique number assigned to each food in the API.
      If API_limit_reached is caught, return Result.Error.  *)
  val get_id_list: string -> (int list, 'a list) result

  (*  Make a GET request to retrieve the restaurant's entire menu.
      Returns the menu json as a string on success. Returns an error
      message string on failure.  *)
  val fetch_menu: string -> string Async_kernel.Deferred.t

  (*  Given an id number, retrieve the id's nutrition information.  *)
  val fetch_menu_item: int -> Yojson.Safe.t Async_kernel.Deferred.t
end

module type Meal = sig
  (*  Create a new macro, given a json of a menu item's nutrition info.  *)
  val make_new_macro: Yojson.Safe.t -> macros

  (*  Add a new menu item to the given meal.  *)
  val add: meal -> Yojson.Safe.t -> meal

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

  (*  Get a specific macro's info from the macro list. Returns a tuple
      of the info.  *)
  val get_macro_info: macros list -> string -> float * string * float
end

(*  Print summary information. Sums up the meals macros.  *)
val print_totals: meal -> string list -> unit

(*  Print meal and macronutrient summary.  *)
val print_meal: meal -> int -> string list -> unit

(*  Make meal then print it.  *)
val make_and_print: string -> float -> string list -> unit Async_kernel.Deferred.t