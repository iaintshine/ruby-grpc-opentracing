require "spec_helper"

RSpec.describe "client-server trace context propagation" do
  def tracer
    @tracer ||= Test::Tracer.new
  end

  def root_span
    @root_span ||= tracer.start_span("root")
  end

  before :all do
    @server = start_server(tracer: tracer)
    client = create_client(@server.host, tracer: tracer, active_span: -> { root_span })
    client.say_hello(Helloworld::HelloRequest.new(name: "Cliet-Server tests"))
    root_span.finish
  end

  after :all do
    @server.stop
  end

  it "creates spans for each part of the chain" do
    expect(tracer).to have_spans(3)
  end

  it "all spans contains the same trace_id" do
    expect(tracer).to have_traces(1)
  end

  it "propagates parent child relationship properly" do
    server_span = tracer.finished_spans[0]
    client_span = tracer.finished_spans[1]
    expect(client_span).to be_child_of(root_span)
    expect(server_span).to be_child_of(client_span)
  end

  def start_server(**fields)
    tracing_interceptor = GRPC::OpenTracing::ServerInterceptor.new(**fields)
    server_controller = GreeterServer::Controller.new(service: tracing_interceptor.intercept(GreeterServer))
    server_controller.start
    server_controller
  end

  def create_client(host, **fields)
    creds = :this_channel_is_insecure

    tracing_interceptor = GRPC::OpenTracing::ClientInterceptor.new(**fields)
    client = Helloworld::Greeter::Stub.new(host, creds)
    tracing_interceptor.intercept(client)
  end
end
