def say_hello(host, name = "world", metadata: {})
  stub = Helloworld::Greeter::Stub.new(host, :this_channel_is_insecure)
  stub.say_hello(Helloworld::HelloRequest.new(name: name), metadata: metadata)
end
