defmodule Reaxt.Error do
  @moduledoc """
  Exception for reaxt
  """

  defexception [:message,:js_render,:js_stack]

  @doc false
  def exception({:handler_error,error,stack}) do
    %__MODULE__{message: "JS Exception : #{error}", js_stack: (stack && parse_stack(stack))}
  end
  def exception({:render_error,error,stack,js_render}) do
    %__MODULE__{message: "JS Exception : #{error}", js_render: js_render, js_stack: (stack && parse_stack(stack))}
  end

  ###
  ### Priv
  ###
  defp parse_stack(stack) do
    Regex.scan(~r/at (.*) \((.*):([0-9]*):[0-9]*\)/,stack)
    |> Enum.map(fn [_,function,url,line]->
      if String.contains?(url,"/priv") and !(function in ["Port.next_term","Socket.read_term"]) do
        {line,_} = Integer.parse(line)
        [_,after_priv] = String.split(url,"/priv/",parts: 2)
        {JS,:"#{function}",0,file: '#{WebPack.Util.web_priv}/#{after_priv}', line: line}
      end
    end)
    |> Enum.filter(&!is_nil(&1))
  end
end

