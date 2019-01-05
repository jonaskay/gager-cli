RSpec.describe Gager::Cli::Application do
  let(:application) { described_class.new("MyUserId", "MyClientId", "MyClientSecret") }

  describe "#report" do
    before {
      stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
        .with(
          body: {
            "reportRequests" => [
              {
                "dateRanges" => [{ "endDate" => "2015-06-30", "startDate" => "2015-06-15" }],
                "dimensions" => [{"name" => "ga:browser"}],
                "filtersExpression" => nil,
                "metrics" => [{ "expression" => "ga:sessions" }],
                "viewId" => "123"
              }
            ]
          }.to_json
        )
        .to_return(
          status: 200,
          body: {
            "reports" => [
              {
                "columnHeader" => {
                  "dimensions" => ["ga:browser"],
                  "metricHeader" => {
                    "metricHeaderEntries" => [{ "name" => "ga:sessions", "type" => "INTEGER" }]
                  }
                },
                "data" => {
                  "rows" => [
                    {
                      "dimensions" => ["Firefox"],
                      "metrics" => [{ "values" => ["2161"] }]
                    },
                    {
                      "dimensions" => ["Internet Explorer"],
                      "metrics" => [{ "values" => ["1705"] }]
                    }
                  ],
                  "totals" => [
                    {
                      "values" => ["3866"]
                    }
                  ]
                }
              }
            ]
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
    }
    before { allow(authorizer).to receive(:authorization).and_return(authorization) }
    before { allow(application).to receive(:authorize).and_return(nil) }

    let(:authorizer) { application.instance_variable_get(:@authorizer) }
    let(:authorization) { "MyAuthorization" }
    let(:name) { "MyReport" }
    let(:request) {
      {
        "view_id" => "123",
        "date_ranges" => [["2015-06-15", "2015-06-30"]],
        "dimensions" => ["ga:browser"],
        "metrics" => ["ga:sessions"],
        "filters_expression" => nil
      }
    }

    subject { application.report([{name: name, request: request}]) }

    it "outputs the report" do
      expect { subject }.to output(a_string_ending_with(<<~TEXT
        +----------------------+-------------+
        |              MyReport              |
        +----------------------+-------------+
        | ga:browser           | ga:sessions |
        +----------------------+-------------+
        | 1. Firefox           |        2161 |
        | 2. Internet Explorer |        1705 |
        +----------------------+-------------+
        | Total                |        3866 |
        +----------------------+-------------+
      TEXT
      )).to_stdout
    end

    context "when @authorizer.authorization is not nil" do
      it "doesn't call #authorize" do
        expect(application).not_to receive(:authorize)

        subject
      end
    end

    context "when @authorizer.authorization is nil" do
      let(:authorization) { nil }

      it "calls #authorize" do
        expect(application).to receive(:authorize)

        subject
      end
    end
  end

  describe "#authorize" do
    let(:code) { "MyCode" }

    before { allow($stdin).to receive(:gets).and_return(code) }

    before {
      stub_request(:post, "https://oauth2.googleapis.com/token").with(
        body: {
          "client_id" => "MyClientId",
          "client_secret" => "MyClientSecret",
          "code" => "MyCode",
          "grant_type" => "authorization_code",
          "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
        }
      ).to_return(
        status: 200,
        body: '{"access_token": "12345"}',
        headers: {
          "Content-Type" => "application/json; charset=utf-8"
        }
      )
    }

    before {
      stub_request(:post, "https://oauth2.googleapis.com/token").with(
        body: {
          "client_id" => "MyClientId",
          "client_secret" => "MyClientSecret",
          "code" => "invalid",
          "grant_type" => "authorization_code",
          "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob"
        }
      ).to_return(
        status: 400,
        body: "",
        headers: {}
      )
    }

    subject { application.authorize }

    it "outputs the authorization URL" do
      expect { subject }.to output(
        a_string_starting_with("Open https://accounts.google.com/o/oauth2/auth")
      ).to_stdout
    end

    context "when code is valid" do
      it "outputs a success message" do
        expect { subject }.to output(
          a_string_ending_with("Authorization successful\n")
        ).to_stdout
      end
    end

    context "when code is invalid" do
      let(:code) { "invalid" }

      it "outputs an error message" do
        expect { subject }.to output("Authorization failed\n").to_stderr
      end
    end
  end
end
