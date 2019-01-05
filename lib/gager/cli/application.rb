require "gager/core"
require "terminal-table"

module Gager
  module Cli
    class Application
      def initialize(user_id, client_id, client_secret, token_store_file: nil)
        @authorizer = Gager::Core::Authorizer.new(user_id, client_id, client_secret, token_store_file: token_store_file)
      end

      def report(templates)
        authorize if @authorizer.authorization.nil?

        client = Gager::Core::Client.new(@authorizer.authorization)
        report_requests = templates.map { |t| t.fetch(:request) }
        response = client.get_reports(report_requests)

        response.reports.each_with_index do |result, i|
          name = templates[i][:name]
          puts generate_table(result, title: name)
        end
      end

      def authorize
        url = @authorizer.authorization_url
        puts "Open #{url} in your browser and enter the resulting code:"
        begin
          @authorizer.authorization_code = $stdin.gets
          puts "Authorization successful"
        rescue Signet::AuthorizationError => e
          $stderr.puts "Authorization failed"
        end
      end

      private

      def generate_table(result, title: nil)
        headings = [
          result.column_header.dimensions.join("; "),
          *result.column_header.metric_header.metric_header_entries.map(&:name)
        ]

        rows = [
          *result.data.rows.map.with_index do |row, j|
            ["#{j + 1}. #{row.dimensions.join("; ")}", *row.metrics.map { |o| {value: o.values.first, alignment: :right} }]
          end,
          :separator,
          ["Total", *result.data.totals[0].values.map { |v| {value: v, alignment: :right} }]
        ]

        Terminal::Table.new(title: title, headings: headings, rows: rows)
      end
    end
  end
end
