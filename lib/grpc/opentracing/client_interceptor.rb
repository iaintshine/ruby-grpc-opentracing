module GRPC
  module OpenTracing
    class ClientInterceptor
      attr_reader :tracer, :active_span, :decorators

      def initialize(tracer: ::OpenTracing.global_tracer, active_span: nil, decorators: [RequestReplyClientSpanDecorator.new])
        @tracer = tracer
        @active_span = active_span
        @decorators = decorators
      end

      def intercept(client)
        client.instance_variable_set(:@tracer, tracer)
        client.instance_variable_set(:@active_span, active_span)
        client.instance_variable_set(:@decorators, decorators)

        client.instance_eval do
          class << self
            alias_method :request_response_without_instrumentation, :request_response
          end

          def active_span
            @active_span.respond_to?(:call) ? @active_span.call : @active_span
          end

          def request_response(method, req, marshal, unmarshal, metadata: {}, **fields)
            tags = {
              'component' => 'gRPC',
              'span.kind' => 'client',
              'grpc.method_type' => 'request_response',
              'grpc.headers' => MultiJson.dump(metadata)
            }
            current_span = @tracer.start_span(method, child_of: active_span, tags: tags)

            hpack_carrier = HPACKCarrier.new(metadata)
            @tracer.inject(current_span.context, ::OpenTracing::FORMAT_RACK, hpack_carrier)

            response = request_response_without_instrumentation(method, req, marshal, unmarshal,
                                                                metadata: metadata, **fields)

            response
          rescue Exception => e
            if current_span
              current_span.set_tag('error', true)
              current_span.log(event: 'error', :'error.object' => e)
            end
            raise
          ensure
            if @decorators
              @decorators.each do |decorator|
                decorator.call(current_span, method, req, response, e)
              end
            end
            current_span.finish if current_span
          end
        end

        client
      end
    end
  end
end
