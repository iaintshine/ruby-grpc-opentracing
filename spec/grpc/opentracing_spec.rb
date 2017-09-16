require "spec_helper"

RSpec.describe GRPC::OpenTracing do
  it "has a version number" do
    expect(GRPC::OpenTracing::VERSION).not_to be nil
  end
end
