# GreeterServer is simple server that implements the Helloworld Greeter server.
class GreeterServer < Helloworld::Greeter::Service
  # say_hello implements the SayHello rpc method.
  def say_hello(hello_req, _unused_call)
    Helloworld::HelloReply.new(message: "Hello #{hello_req.name}")
  end

  class Controller
    def initialize(host: '0.0.0.0:50051')
      @server = GRPC::RpcServer.new
      @server.add_http2_port(host, :this_port_is_insecure)
      @server.handle(GreeterServer)
    end

    def start
      @server_thread = Thread.new { @server.run_till_terminated }
    end

    def stop
      @server.stop
      @server_thread.join
    end
  end
end
