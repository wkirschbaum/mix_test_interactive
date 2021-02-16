defmodule MixTestInteractive.InteractiveMode do
  @moduledoc """
  Main loop for interactive mode.

  Repeatedly reads commands from the user, processes them, optionally runs
  the tests, and then prints out summary/usage information.
  """

  use GenServer

  alias MixTestInteractive.{CommandProcessor, Config, Runner}

  @type option :: {:config, Config.t()}

  @doc """
  Start the interactive mode server.
  """
  @spec start_link([option]) :: GenServer.on_start()
  def start_link(options) do
    state = Keyword.fetch!(options, :config)
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @doc """
  Initialize from command-line arguments.
  """
  @spec initialize([String.t()]) :: :ok
  def initialize(cli_args) do
    GenServer.call(__MODULE__, {:initialize, cli_args})
  end

  @doc """
  Process a command from the user.
  """
  @spec process_command(String.t()) :: :ok | :quit
  def process_command(command) do
    GenServer.call(__MODULE__, {:command, command})
  end

  @doc """
  Run the tests.
  """
  @spec run_tests() :: :ok
  def run_tests do
    GenServer.call(__MODULE__, :run_tests, :infinity)
  end

  @doc """
  Return the current configuration.
  """
  @spec config() :: Config.t()
  def config do
    GenServer.call(__MODULE__, :config, :infinity)
  end

  @impl GenServer
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:initialize, cli_args}, _from, _state) do
    config = Config.new(cli_args)
    {:reply, :ok, config, {:continue, :run_tests}}
  end

  @impl GenServer
  def handle_call({:command, command}, _from, state) do
    case CommandProcessor.call(command, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state, {:continue, :run_tests}}

      {:no_run, new_state} ->
        show_usage_prompt(new_state)
        {:reply, :ok, new_state}

      :help ->
        show_help(state)
        {:reply, :ok, state}

      :unknown ->
        {:reply, :ok, state}

      :quit ->
        System.stop()
    end
  end

  @impl GenServer
  def handle_call(:run_tests, _from, state) do
    run_tests(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:config, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_continue(:run_tests, state) do
    run_tests(state)
    {:noreply, state}
  end

  @doc """
  Start the interactive mode loop.
  """
  @spec start() :: no_return()
  def start() do
    loop()
  end

  defp loop do
    command = IO.gets("")

    with :ok <- process_command(command) do
      loop()
    else
      :quit -> :ok
    end
  end

  defp run_tests(config) do
    :ok = do_run_tests(config)
    show_summary(config)
    show_usage_prompt(config)
  end

  defp do_run_tests(config) do
    with :ok <- Runner.run(config) do
      :ok
    else
      {:error, :no_matching_files} ->
        [:red, "No matching tests found"]
        |> IO.ANSI.format()
        |> IO.puts()

        :ok

      error ->
        error
    end
  end

  defp show_summary(config) do
    IO.puts("")

    config
    |> Config.summary()
    |> IO.puts()
  end

  defp show_usage_prompt(config) do
    IO.puts("")

    if config.watching? do
      IO.puts("Watching for file changes...")
    else
      IO.puts("Ignoring file changes")
    end

    IO.puts("")

    [:bright, "Usage: ?", :normal, " to show more"]
    |> IO.ANSI.format()
    |> IO.puts()
  end

  defp show_help(config) do
    IO.puts("")

    config
    |> CommandProcessor.usage()
    |> IO.puts()
  end
end
