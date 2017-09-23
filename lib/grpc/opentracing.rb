require "grpc"
require "opentracing"
require "multi_json"
require "method-tracer"

require "grpc/opentracing/version"
require "grpc/opentracing/hpack_carrier"
require "grpc/opentracing/client_span_decorator"
require "grpc/opentracing/request_reply_client_span_decorator"
require "grpc/opentracing/client_interceptor"

module GRPC
  module OpenTracing
  end
end
