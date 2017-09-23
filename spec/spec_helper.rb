require "bundler/setup"
require "test/tracer"
require "tracing/matchers"
require "grpc/opentracing"

require "support/helloworld"
require "support/greeter_client"
require "support/greeter_server"

server = create_server
server_thread = Thread.new { server.run_till_terminated }
at_exit { server.stop; server_thread.join }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
