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
    Logger.info("EDSL runtime initialized")
    {:ok, state}
  end

  def init(_) do
    Logger.error("Invalid EDSL configuration")
    {:stop, :invalid_state}
  end

  @doc """
  Loads the YAML file and loads the functions into the Elixir runtime.
  """
  def start_link(opts) do
    Logger.info("Starting EDSL runtime")
    Code.put_compiler_option(:ignore_module_conflict, true)

    with config_path when is_binary(config_path) <- Keyword.get(opts, :config_path, "edsl.yaml"),
         {:ok, content} <- File.read(config_path),
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
    Logger.info("Invoking '#{module_name}'")

    with {:ok, cwd} <- File.cwd(),
         :ok <- File.cd(base_dir),
         return_value <-
           invoke_fn(
             find_invoke_fn_by_arity(Map.get(modules, module_name), length(args), branch),
             module_name,
             args
           ),
         :ok <- File.cd(cwd) do
      {:reply, return_value, state}
    else
      _error ->
        Logger.error(
          "Could not search for functions. Check if the base directory or branch is correct"
        )

        {:stop, :function_invocation_failed, state}
    end
  end

  defp invoke_fn({:ok, module}, _module_name, args) do
    try do
      {:ok, apply(module, :invoke, args)}
    rescue
      _exception ->
        Logger.error(
          "Error while invoking function. Could not match function with given arguments"
        )

        {:error, :function_invocation_failed}
    end
  end

  defp invoke_fn({:error, :no_module_found}, module_name, _args) do
    Logger.error("Could not find module '#{module_name}'")
    {:error, :no_module_found}
  end

  defp invoke_fn({:error, :no_function_found}, module_name, _args) do
    Logger.error("Could not find function with matching arity in module '#{module_name}'")
    {:error, :no_function_found}
  end

  defp find_invoke_fn_by_arity(nil, _arity, _branch) do
    {:error, :no_module_found}
  end

  defp find_invoke_fn_by_arity(module, arity, branch) do
    Enum.reduce_while(module, {:error, :no_function_found}, fn commit_hash, acc ->
      try do
        # Checkout the current hash
        Logger.info("Loading commit '#{commit_hash}'")
        {_output, 0} = System.cmd("git", ["checkout", commit_hash], stderr_to_stdout: true)

        # Load the "edsl.exs" file
        [{module, _bytecode}] = Code.compile_file("edsl.exs")

        # Checkout back to the original branch
        {_output, 0} = System.cmd("git", ["checkout", branch], stderr_to_stdout: true)

        # Check if the function exists
        if function_exported?(module, :invoke, arity) do
          Logger.info("Found function with matching arity in commit '#{commit_hash}'")
          {:halt, {:ok, module}}
        else
          {:cont, acc}
        end
      rescue
        _exception ->
          Logger.error("Error loading the commit '#{commit_hash}'")
          {:cont, acc}
      end
    end)
  end
end
