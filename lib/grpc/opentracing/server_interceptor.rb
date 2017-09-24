module GRPC
  module OpenTracing
    class ServerInterceptor
      attr_reader :tracer, :decorators

      def initialize(tracer: ::OpenTracing.global_tracer, decorators: [RequestReplySpanDecorator])
        @tracer = tracer
        @decorators = decorators
      end

      def intercept(service)
        service_class = service.is_a?(Class) ? service : service.class
        service_class.rpc_descs.each_pair do |name, desc|
          route = "/#{service_class.service_name}/#{name}".to_sym
          method_name = GRPC::GenericService.underscore(name.to_s).to_sym
          method_name_without_instrumentation = "#{method_name}_without_instrumentation".to_sym
          interceptor = self

          service_class.class_eval do
            @tracer = interceptor.tracer
            @decorators = interceptor.decorators

            class << self
              attr_reader :tracer, :decorators
            end

            def tracer
              self.class.tracer
            end

            def decorators
              self.class.decorators
            end
          end

          if desc.request_response?
            service_class.class_eval do
              if method_defined?(method_name_without_instrumentation)
                alias_method method_name, method_name_without_instrumentation
                remove_method method_name_without_instrumentation
              end

              alias_method method_name_without_instrumentation, method_name

              define_method(method_name) do |req, active_call|
                begin
                  tags = {
                    'component' => 'gRPC',
                    'span.kind' => 'server',
                    'grpc.method_type' => 'request_response'
                  }
                  hpack_carrier = HPACKCarrier.new(active_call.metadata)
                  parent_span_context = tracer.extract(::OpenTracing::FORMAT_TEXT_MAP, hpack_carrier)
                  current_span = tracer.start_span(route.to_s, child_of: parent_span_context, tags: tags)

                  response = self.send(method_name_without_instrumentation, req, active_call)

                  response
                rescue Exception => e
                  if current_span
                    current_span.set_tag('error', true)
                    current_span.log(event: 'error', :'error.object' => e)
                  end
                  raise
                ensure
                  if decorators
                    decorators.each do |decorator|
                      decorator.call(current_span, route, req, response, e)
                    end
                  end
                  current_span.finish if current_span
                end
              end
            end
          end
        end

        service
      end
    end
  end
end
