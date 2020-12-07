# Overview
My project will use the Nutritionix API to retrieve nutrition data about menu items
from well-known restaurants. Using this data, I want to create randomly-generated meals
that meet a calorie limit chosen by the user. The user can also choose the restaurant.
The user can use optional command line arguments to list any macronutrient information
they want to see.
<br /> <br />
The [Nutritionix API](https://www.nutritionix.com/business/api) provides a huge database of
common foods and branded foods and their nutrition info. It also has endpoints for
exercise information.
<br /> <br />
If I have time, I hope to implement more features, such as how many minutes the user has to
do a certain exercise to burn the calories from their meal. These features are listed in the
section below, in order of implementation.

# Features
<ol>
<li>User can choose a restaurant and calorie limit, and the app will print a list of menu items
that add up to calorie limit (not completely strict, maybe within a -100/100 cal range)</li>
<li>User can optionally list the macronutrients they want to know about.</li>
<li>Show daily value % of macronutrients.</li>
<li>User can select an activity/exercise in addition to a restaurant and calorie limit, and the
app will print how many minutes the activity has to be performed to burn the given number of calories.
This will be based on a default value for height and weight because of limitations with the API.</li>
</ol>

# Libraries
Core (Map, List, Command, etc.)<br />
Cohttp <br />
Lwt or Async (Will try to use Async, it's just that I used Lwt in my testing of Cohttp since the Cohttp tutorial uses Lwt.) <br />
Cohttp-lwt-unix (If using Lwt.) <br />
Yojson

# Module type declarations
In .mli file.

# Mock
I'll probably use flags for the command line arguments, but I haven't figured out what those
would be yet. <br /> <br />
`dune exec -- ./project McDonald's 1500` <br />
`1. Big Mac (550 calories)` <br />
`2. Sausage Burrito (310 calories)` <br />
`3. Mocha Frappe (420 calories)` <br />
`4. Small World Famous Fries (220 calories)`<br />
`Total: 1500 calories` <br /> <br />

`dune exec -- ./project McDonald's 1500 saturated_fat sodium` <br />
`1. Big Mac (550 calories, 11g saturated fat, 1010mg sodium)` <br />
`2. Sausage Burrito (310 calories, 7g saturated fat, 800mg sodium)` <br />
`3. Mocha Frappe (420 calories, 11g saturated fat, 120mg sodium)` <br />
`4. Small World Famous Fries (220 calories, 1.5g saturated fat, 180mg sodium)`<br />
`Total:` <br />
`1500 calories` <br />
`30.5g saturated fat, 152.5 DV` <br />
`2110mg sodium, 87.92% DV` <br /> <br />

`dune exec -- ./project Restaurant_not_in_API 1500` <br />
`Restaurant is not available, please choose a different one.` <br /> <br />

`dune exec -- ./project McDonald's 1500 Macro_not_in_API` <br />
`Information for this macronutrient is not available. Please pick macronutrients from the following list:` <br />
`Saturated fat` <br />
`Cholesterol` <br />
`Sodium` <br />
`Carbohydrates` <br />
`Fiber` <br />
`Sugar` <br />
`Potassium` <br /> <br />

`dune exec -- ./project McDonald's 1500 cross_country_skiing` <br />
`1. Big Mac (550 calories)` <br />
`2. Sausage Burrito (310 calories)` <br />
`3. Mocha Frappe (420 calories)` <br />
`4. Small World Famous Fries (220 calories)`<br />
`Total: 1500 calories` <br />
`You would need to do "cross country skiing" for 165 minutes to burn 1500 calories.`<br /> <br />

`dune exec -- ./project McDonald's 1500 activity_not_in_API` <br />
`Activity is not available, please choose a different one.` <br /> <br />