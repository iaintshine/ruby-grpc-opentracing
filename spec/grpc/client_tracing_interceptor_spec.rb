require "spec_helper"

RSpec.describe GRPC::OpenTracing::ClientTracingInterceptor do
  let(:tracer) { Test::Tracer.new }

  describe "auto-instrumentation" do
    before do
      client = create_client(tracer: tracer)
      client.say_hello(Helloworld::HelloRequest.new(name: "Client tests"))
    end

    it "creates a new span" do
      expect(tracer).to have_spans
    end

    it "sets operation_name service_name/method_name" do
      expect(tracer).to have_span("helloworld.Greeter/SayHello")
    end

    it "sets standard OT tags" do
      [
        ['component', 'gRPC'],
        ['span.kind', 'client']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    it "sets gRPC specific OT tags" do
      [
        ["grpc.method_type", "request_response"],
        ["grpc.affinity", ""],
        ["grpc.authority", ""],
        ["grpc.call_options", ""],
        ["grpc.compressor", ""],
        ["grpc.deadline_millis", ""],
        ["grpc.headers", ""],
        ["grpc.response_headers", ""],
        ["grpc.status_code", ""]
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end
  end

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      client = create_client(tracer: tracer, active_span: -> { root_span })
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

  describe "span context injection" do
    before do
      client = create_client(tracer: tracer)
      client.say_hello(Helloworld::HelloRequest.new(name: "Client tests"))
    end

    it "propagates span context through headers" do
      grpc_client_span = tracer.finished_spans.last
      # TODO: requires some extension to tracing matchers
    end
  end

  def create_client(**fields)
    host = 'localhost:50051'
    creds = :this_channel_is_insecure
    headers = {
      'grpc.primary_user_agent' => 'grpc-opentracing-tests'
    }

    channel = GRPC::Core::Channel.new(host, headers, creds)
    tracing_interceptor = GRPC::OpenTracing::ClientTracingInterceptor.new(**fields)
    Helloworld::Greeter::Stub.new(host, creds, channel_override: tracing_interceptor.intercept(channel))
  end
end
