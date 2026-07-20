require "test_helper"

module InsuranceProviders
  class OmintProviderTest < ActiveSupport::TestCase
    FakeResponse = Struct.new(:status, :body) do
      def success?
        status == 200
      end
    end

    setup do
      @provider = providers(:omint)
      @client = OmintProvider.new(@provider)
      @quote = quotes(:producer_quote)
      @quote.origin = "Argentina"
      @quote.destination = "Francia"

      def @client.fetch_new_token!
        "fake-token"
      end
    end

    test "normaliza cada producto devuelto en un hash independiente" do
      stub_http_client(FakeResponse.new(200, {
        "id" => "quote-123",
        "products" => [
          { "denomination" => "OA 30", "grossPrice" => 15125.0 },
          { "denomination" => "OA 70", "grossPrice" => 22000.5 }
        ]
      }))

      results = @client.quote(@quote)

      assert_equal 2, results.size
      assert_equal "OA 30", results[0][:plan_name]
      assert_equal 1512500, results[0][:price_cents]
      assert_equal "quote-123", results[0][:external_quote_id]
      assert_equal "OA 70", results[1][:plan_name]
      assert_equal 2200050, results[1][:price_cents]
    end

    test "reintenta una vez con un token nuevo ante un 401" do
      responses = [
        FakeResponse.new(401, {}),
        FakeResponse.new(200, { "id" => "quote-456", "products" => [ { "denomination" => "OA 50", "grossPrice" => 9000.0 } ] })
      ]
      calls = []
      fake_http = Object.new
      fake_http.define_singleton_method(:post) do |*_args, &blk|
        req = Struct.new(:headers).new({})
        blk.call(req)
        calls << req.headers["Authorization"]
        responses.shift
      end
      def @client.http_client
        @fake_http
      end
      @client.instance_variable_set(:@fake_http, fake_http)

      tokens = [ "expired-token", "fresh-token" ]
      @client.define_singleton_method(:fetch_new_token!) { tokens.shift }

      results = @client.quote(@quote)

      assert_equal 1, results.size
      assert_equal [ "Bearer expired-token", "Bearer fresh-token" ], calls
    end

    test "rechaza origen distinto de Argentina" do
      @quote.origin = "Brasil"

      error = assert_raises(BaseProvider::ProviderError) { @client.quote(@quote) }
      assert_match(/Argentina/, error.message)
    end

    test "mapea países a las zonas de destino de Omint" do
      {
        "Francia" => "EMO",
        "Uruguay" => "URU",
        "Brasil" => "ASU",
        "Estados Unidos" => "NAC",
        "México" => "MAC",
        "Australia" => "OCE",
        "Japón" => "AAA",
        "Sudáfrica" => "AAA",
        "Argentina" => "ARG"
      }.each do |name, code|
        assert_equal code, @client.send(:resolve_destination_code, name), "esperaba #{code} para #{name}"
      end

      assert_equal "EMO", @client.send(:resolve_destination_code, "Europa")
    end

    test "rechaza destino sin mapeo conocido" do
      error = assert_raises(BaseProvider::ProviderError) { @client.send(:resolve_destination_code, "Narnia") }
      assert_match(/sin mapeo/, error.message)
    end

    private

    def stub_http_client(response)
      fake_http = Object.new
      fake_http.define_singleton_method(:post) do |*_args, &blk|
        blk.call(Struct.new(:headers).new({}))
        response
      end
      @client.define_singleton_method(:http_client) { fake_http }
    end
  end
end
