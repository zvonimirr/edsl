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

    # Find the module by key
    module =
      with hashes when not is_nil(hashes) <- Map.get(modules, module_name) do
        Logger.info("Found module '#{module_name}'")
        # Go through each commit hash and load the functions until we find one
        # that works.
        {:ok, module} =
          Enum.reduce_while(hashes, {:ok, nil}, fn commit_hash, _acc ->
            Logger.info("Loading commit '#{commit_hash}'")
            System.cmd("git", ["checkout", commit_hash], stderr_to_stdout: true)

            # Load the "edsl.exs" file
            [{module, _bytecode}] = Code.compile_file("edsl.exs")

            System.cmd("git", ["checkout", branch], stderr_to_stdout: true)

            case function_exported?(module, :invoke, Kernel.length(args)) do
              true ->
                Logger.info(
                  "Found module '#{module_name}' with matching arity in commit '#{commit_hash}'"
                )

                {:halt, {:ok, module}}

              false ->
                {:cont, {:ok, nil}}
            end
          end)

        # If the module is nil, then we couldn't find a module that matches the
        # given arguments.
        if module == nil do
          Logger.error("Could not find module '#{module_name}' with the matching arity")
          nil
        else
          module
        end
      end

    # Change working directory back to original directory
    :ok = File.cd(cwd)

    # Invoke the function with the given arguments
    # if it exists.
    if not is_nil(module) do
      apply(module, :invoke, args)
    end

    {:reply, :ok, state}
  end
end
