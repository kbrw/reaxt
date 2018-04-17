[
  reaxt: [
    otp_app: :hello,
    hot: Mix.env == :dev,
    pool_size: if(Mix.env == :dev, do: 1, else: 10),
  ]
]
