# GreeterServer is simple server that implements the Helloworld Greeter server.
class GreeterServer < Helloworld::Greeter::Service
  # say_hello implements the SayHello rpc method.
  def say_hello(hello_req, _unused_call)
    Helloworld::HelloReply.new(message: "Hello #{hello_req.name}")
  end
end

# main starts an RpcServer that receives requests to GreeterServer at the sample
# server port.
def create_server(host: '0.0.0.0:50051')
  s = GRPC::RpcServer.new
  s.add_http2_port(host, :this_port_is_insecure)
  s.handle(GreeterServer)
  s
end
