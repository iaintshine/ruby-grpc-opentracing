class TestSpanDecorator
  class << self
    def call(span, method, request, response, error)
      span.set_tag("test_key", method)
    end
  end
end
