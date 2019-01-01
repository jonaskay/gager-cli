RSpec.describe WebMock do
  it "disables external requests" do
    expect { Net::HTTP.get("www.example.com", "/") }
      .to raise_error(WebMock::NetConnectNotAllowedError)
  end

  it "allows localhost requests" do
    expect { Net::HTTP.get("localhost:9887", "/") }
      .to raise_error(SocketError)
  end
end
