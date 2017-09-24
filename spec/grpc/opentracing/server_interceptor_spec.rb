require "spec_helper"

RSpec.describe GRPC::OpenTracing::ServerInterceptor do
  def tracer
    @tracer ||= Test::Tracer.new
  end

  describe "auto-instrumentation" do
    before :all do
      @server = start_server(tracer: tracer,
                             decorators: [
                               GRPC::OpenTracing::RequestReplySpanDecorator,
                               TestSpanDecorator
      ])
      say_hello(@server.host, "Server tests")
    end

    after :all do
      @server.stop if @server
    end

    it "creates a new span" do
      expect(tracer).to have_spans(1)
    end

    it "sets operation_name service_name/method_name" do
      expect(tracer).to have_span("/helloworld.Greeter/SayHello")
    end

    it "sets standard OT tags" do
      [
        ['component', 'gRPC'],
        ['span.kind', 'server']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    it "sets gRPC RequestReplySpanDecorator specific OT tags" do
      [
        ["grpc.method_type", "request_response"],
        ["grpc.request", '{"name":"Server tests"}'],
        ["grpc.reply", '{"message":"Hello Server tests"}']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    describe "decorators usage" do
      it "sets custom tag on client span" do
        expect(tracer).to have_span.with_tag("test_key", "/helloworld.Greeter/SayHello")
      end
    end
  end

  def start_server(**fields)
    tracing_interceptor = GRPC::OpenTracing::ServerInterceptor.new(**fields)
    server_controller = GreeterServer::Controller.new(service: tracing_interceptor.intercept(GreeterServer))
    server_controller.start
    server_controller
  end
end
