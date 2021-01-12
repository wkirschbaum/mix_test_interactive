defmodule MixTestInteractive.CommandProcessor do
  @moduledoc false

  alias MixTestInteractive.Config

  @spec call(String.t() | :eof, Config.t()) :: {:ok, Config.t()} | :unknown | :quit

  def call(:eof, _config), do: :quit

  def call(command_line, config) when is_binary(command_line) do
    case String.split(command_line) do
      [] -> process_command("", [], config)
      [command | args] -> process_command(command, args, config)
    end
  end

  def usage do
    """
    Usage
    › p <files> to run only the specified test files.
    › c to clear any file filters.
    › s to run only stale files.
    › a to run all files.
    › Enter to trigger a test run.
    › q to quit.
    """
  end

  defp process_command("a", _args, config) do
    {:ok, Config.clear_flags(config)}
  end

  defp process_command("c", _args, config) do
    {:ok, Config.clear_filters(config)}
  end

  defp process_command("p", files, config) do
    {:ok, Config.only_files(config, files)}
  end

  defp process_command("s", _args, config) do
    {:ok, Config.only_stale(config)}
  end

  defp process_command("q", _args, _config), do: :quit
  defp process_command("", _args, config), do: {:ok, config}
  defp process_command(_unknown_command, _args, _config), do: :unknown
end
