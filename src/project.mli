(* record type that stores nutrient info for a menu item *)
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

(* module that holds main functionality for menu items*)
module type Menu = sig
  (* a map, probably *)
  type t
  val empty: t
  (* restaurant -> t option *)
  (* GET request to get restaurant's entire menu, convert to t *)
  (* return None if restaurant doesn't exist in database *)
  val fetch_menu: string -> t option
  (* t -> food name -> nutrients -> t *)
  val add: t -> string -> nutrients -> t
  (* t -> food name -> nutrients *)
  val lookup: t -> string -> nutrients
end

(* command line argument -> sanitized command line argument *)
(* change command line argument so it is all lowercase, no underscores, etc. *)
(* then, I'm able to use it in requests *)
val sanitize: string -> string

(* Menu -> calorie limit -> list of menu items *)
(* randomly pick items that meet calorie limit*)
val generate_meal: (module Menu) -> int -> string list

(* Menu -> total daily value -> DV% *)
(* calculate daily value *)
val daily_value: (module Menu) -> int -> float

(* type of exercise -> calories to burn -> minutes to exercise *)
val calculate_exercise: string -> int -> int

(* print output as JSON string *)
val print_meal: string list -> (module Menu) -> unit