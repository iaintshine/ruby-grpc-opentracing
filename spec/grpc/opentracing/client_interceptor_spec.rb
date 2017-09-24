require "spec_helper"

RSpec.describe GRPC::OpenTracing::ClientInterceptor do
  let(:tracer) { Test::Tracer.new }

  before :all do
    @server_controller = GreeterServer::Controller.new
    @server_controller.start
  end

  after :all do
    @server_controller.stop
  end

  describe "auto-instrumentation" do
    before do
      client = create_client(@server_controller.host, tracer: tracer)
      client.say_hello(Helloworld::HelloRequest.new(name: "Client tests"))
    end

    it "creates a new span" do
      expect(tracer).to have_spans
    end

    it "sets operation_name service_name/method_name" do
      expect(tracer).to have_span("/helloworld.Greeter/SayHello")
    end

    it "sets standard OT tags" do
      [
        ['component', 'gRPC'],
        ['span.kind', 'client']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    it "sets gRPC RequestReplySpanDecorator specific OT tags" do
      [
        ["grpc.method_type", "request_response"],
        ["grpc.headers", '{}'],
        ["grpc.request", '{"name":"Client tests"}'],
        ["grpc.reply", '{"message":"Hello Client tests"}']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end
  end

  describe "decorators usage" do
    before do
      client = create_client(@server_controller.host, tracer: tracer, decorators: [TestSpanDecorator])
      client.say_hello(Helloworld::HelloRequest.new(name: "Client tests"))
    end

    it "sets custom tag on client span" do
      expect(tracer).to have_span.with_tag("test_key", "/helloworld.Greeter/SayHello")
    end
  end

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      client = create_client(@server_controller.host, tracer: tracer, active_span: -> { root_span })
      client.say_hello(Helloworld::HelloRequest.new(name: "Client tests"))
    end

    it "creates the new span with active span trace_id" do
      expect(tracer).to have_traces(1)
      expect(tracer).to have_spans(2)
    end

    it "creates the new span with active span as a parent" do
      expect(tracer).to have_span.with_parent(root_span)
    end
  end

  def create_client(host, **fields)
    creds = :this_channel_is_insecure

    tracing_interceptor = GRPC::OpenTracing::ClientInterceptor.new(**fields)
    client = Helloworld::Greeter::Stub.new(host, creds)
    tracing_interceptor.intercept(client)
  end
end
