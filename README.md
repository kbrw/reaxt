Reaxt
=====

Use your *react* components into your elixir application.

webpack->
  - sweetjs (sparkle,lambda-chop)

## Architecture ##

**React application**

- Erlang port running nodejs VM
  - N port in a pool for template rendering
  - 1 port for handling code reloading, running a webpack-webserver when Mix.env=dev

- one function render(props) returning the HTML with 
  - webpack assets loading
  - react html rendered in a <div id="content"> with props initial state
  - react initial state loading `react.render(mainComponent(JSON.stringify(props).remove('<!--script')))`
  - if Mix.env=dev, then add the <script src="http://localhost:8090/webpack-dev-server.js"></script>
- render(props,function) will call props = function(props)

- code management webserver:
  - hot reloading event
  - compilation call

At application start :
- generate webpack output

## Configuration ##

webpack configuration
