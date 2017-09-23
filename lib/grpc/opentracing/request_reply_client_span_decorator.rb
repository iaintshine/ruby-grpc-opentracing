module GRPC
  module OpenTracing
    class RequestReplyClientSpanDecorator < ClientSpanDecorator
      def call(span, method, request, response, error)
        span.set_tag('grpc.request', request.to_json) if request
        span.set_tag('grpc.reply', response.to_json) if response
      end
    end
  end
end
