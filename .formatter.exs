locals_without_parens = [
  plug: 1,
  plug: 2
]

[
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens
]
