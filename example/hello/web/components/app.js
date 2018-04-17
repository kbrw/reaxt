var React = require('react')
var ReactDOM = require('react-dom')

module.exports = {
  reaxt_server_render (params,render){ // server side call, should call render(ReactComp)
    render(<div>Hello World!</div>)
  },
  reaxt_client_render (initialProps,render){ // initial client side call, should call render(ReactComp)
    render(<div>Hello World!</div>)
  }
}