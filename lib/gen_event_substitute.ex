defmodule GenEventSubstitute do
  @moduledoc """
  Substitute module untill what's really needed is fully understood in order to do without `:gen_event`
  """

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour :gen_event

      @doc false
      def init(args) do
        {:ok, args}
      end

      @doc false
      def handle_event(_event, state) do
        {:ok, state}
      end

      @doc false
      def handle_call(msg, state) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []} -> self()
            {_, name} -> name
          end

        # We do this to trick Dialyzer to not complain about non-local returns.
        case :erlang.phash2(1, 1) do
          0 ->
            raise "attempted to call GenEventSubtitute #{inspect(proc)} but no handle_call/2 clause was provided"

          1 ->
            {:remove_handler, {:bad_call, msg}}
        end
      end

      @doc false
      def handle_info(_msg, state) do
        {:ok, state}
      end

      @doc false
      def terminate(_reason, _state) do
        :ok
      end

      @doc false
      def code_change(_old, state, _extra) do
        {:ok, state}
      end

      defoverridable init: 1,
                     handle_event: 2,
                     handle_call: 2,
                     handle_info: 2,
                     terminate: 2,
                     code_change: 3
    end
  end

  def start_link([name: name]) do
    :gen_event.start_link({:local, name})
  end

  def add_handler(manager, handler, args) do
    :gen_event.add_handler(manager, handler, args)
  end

  def notify(manager, event) do
    :gen_event.notify(manager, event)
  end

  def call(manager, handler, request, timeout \\ 5_000) do
    :gen_event.call(manager, request, timeout)
  end

  def add_mon_handler(manager, handler, args) do
    :gen_event.add_sup_handler(manager, handler, args)
  end
end
