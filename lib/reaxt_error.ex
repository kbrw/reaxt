defmodule ReaxtError do
  defexception [:message,:args,:js_render,:js_stack]

  def exception({:handler_error,module,submodule,args,error,stack}) do
    params = %{
      module: module,
      submodule: submodule,
      args: args
    }
    %ReaxtError{message: "JS Handler Exception for #{inspect params}: #{error}", args: params, js_stack: (stack && parse_stack(stack))}
  end

  def exception({:render_error,params,error,stack,js_render}) do
    %ReaxtError{message: "JS Render Exception : #{error}", args: params, js_render: js_render, js_stack: (stack && parse_stack(stack))}
  end
  def exception(rest) do
    %ReaxtError{message: "JS Render Exception : #{inspect(rest)}", args: "", js_render: "", js_stack: ""}
  end

  defp parse_stack(stack) do
    Regex.scan(~r/at (.*) \((.*):([0-9]*):[0-9]*\)/, stack)
    |> Enum.filter(fn [_, function, url, _line] ->
      String.contains?(url, "/priv") and not (function in ["Port.next_term","Socket.read_term"])
    end)
    |> Enum.map(fn [_, function, url, line] ->
      {line, _} = Integer.parse(line)
      [_, after_priv] = String.split(url,"/priv/", parts: 2)
      {JS, :"#{function}", 0, file: '#{Reaxt.Utils.web_priv}/#{after_priv}', line: line}
    end)
  end
end
