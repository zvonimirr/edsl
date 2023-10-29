defmodule Edsl.Runtime do
  @moduledoc """
  Runtime for the EDSL. It is responsible for loading the YAML file and
  loading the functions into the Elixir runtime.
  """

  require Logger
  use GenServer

  @impl true
  def init(%{"base_dir" => base_dir, "modules" => modules, "branch" => branch} = state)
      when is_binary(base_dir) and is_map(modules) and is_binary(branch) do
    {:ok, state}
  end

  def init(_) do
    Logger.error("Invalid EDSL configuration")
    {:stop, :invalid_state}
  end

  @doc """
  Loads the YAML file and loads the functions into the Elixir runtime.
  """
  def start_link(_opts) do
    Logger.info("Starting EDSL runtime")

    with {:ok, content} <- File.read("edsl.yaml"),
         {:ok, yaml} <- YAML.decode(content) do
      Logger.info("Loaded YAML file")
      Logger.debug("YAML file content: #{inspect(yaml)}")

      GenServer.start_link(__MODULE__, yaml, name: __MODULE__)
    end
  end

  # Client API

  @doc """
  Invoke the EDSL runtime to execute the given function.
  """
  def invoke(module_name, args) do
    GenServer.call(__MODULE__, {:invoke, module_name, args})
  end

  # Callbacks

  @impl true
  def handle_call(
        {:invoke, module_name, args},
        _from,
        %{"base_dir" => base_dir, "modules" => modules, "branch" => branch} = state
      ) do
    Logger.info("Preparing EDSL runtime in '#{base_dir}'")
    # Each module is a map key that contains a list of commit hashes.
    # To load the functions into the Elixir runtime, we need to go through
    # each module and each commit hash and load the functions.

    {:ok, cwd} = File.cwd()

    # Change working directory to base directory
    :ok = File.cd(base_dir)

    return_value =
      case find_invoke_fn_by_arity(Map.get(modules, module_name), length(args), branch) do
        {:ok, module} ->
          try do
            {:ok, apply(module, :invoke, args)}
          rescue
            _exception ->
              Logger.error(
                "Error while invoking function. Could not match function with given arguments"
              )
          end

        {:error, :no_module_found} ->
          Logger.error("Could not find module '#{module_name}'")

        {:error, :no_function_found} ->
          Logger.error("Could not find function with matching arity in module '#{module_name}'")
      end

    # Change working directory back to original directory
    :ok = File.cd(cwd)

    {:reply, return_value, state}
  end

  defp find_invoke_fn_by_arity(nil, _arity, _branch) do
    {:error, :no_module_found}
  end

  defp find_invoke_fn_by_arity(module, arity, branch) do
    Enum.reduce_while(module, {:error, :no_function_found}, fn commit_hash, acc ->
      # Checkout the current hash
      Logger.info("Loading commit '#{commit_hash}'")
      System.cmd("git", ["checkout", commit_hash], stderr_to_stdout: true)

      # Load the "edsl.exs" file
      [{module, _bytecode}] = Code.compile_file("edsl.exs")

      # Checkout back to the original branch
      System.cmd("git", ["checkout", branch], stderr_to_stdout: true)

      # Check if the function exists
      if function_exported?(module, :invoke, arity) do
        Logger.info("Found function with matching arity in commit '#{commit_hash}'")
        {:halt, {:ok, module}}
      else
        {:cont, acc}
      end
    end)
  end
end
