# EDSL
![EDSL](./edsl.gif)
EDSL (short for Elixir-based Domain-Specific-Language) is an homage to one of the funniest articles I've ever read: [The Inner JSON Effect](https://thedailywtf.com/articles/the-inner-json-effect).

To make it more chaotic, I've decided to use YAML instead.

## Requirements
- Elixir 1.15.7/OTP 26
- Git

## Usage
Due to the nature of Elixir, it's not possible to check functions on anything else other than arity since the match is done at runtime so keep that in mind when using EDSL.

The first function that matches the arguments arity will be used.

To configure EDSL use the `edsl.yaml` file in the root directory.
### Configuration
- base_dir - Points to the base directory where the code is located
- branch - The base branch that we should return to after checking a commit hash
- modules - Each key holds an array of commit hashes that contain the `invoke` function

To run EDSL make sure you have an existing directory with initialized Git.

Create an `edsl.exs` file and use this template:
```elixir
defmodule Hello do
  def invoke("spec") do
    IO.puts("Hello World!")
  end
end
```
When done with your work just commit the file changes and put the commit hash into `edsl.yaml`.

To run the EDSL runtime, just type `iex -S mix run` and call `Edsl.Runtime.invoke/2`.
The first parameter is the module name while the second parameter is a list of arguments that would be passed down to the function call.

To run the example from the template you would call the runtime like this:
```
iex> Edsl.Runtime.invoke("Hello", ["spec"])
```
