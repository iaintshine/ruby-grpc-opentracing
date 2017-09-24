module GRPC
  module OpenTracing
    class RequestReplySpanDecorator
      class << self
        def call(span, method, request, response, error)
          span.set_tag('grpc.request', request.to_json) if request
          span.set_tag('grpc.reply', response.to_json) if response
        end
      end
    end
  end
end
