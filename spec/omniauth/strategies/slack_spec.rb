# rubocop:disable Metrics/BlockLength
# frozen_string_literal: true

require "helper"

describe OmniAuth::Strategies::Slack do
  def app
    lambda do |_env|
      [200, {}, ["Hello."]]
    end
  end

  let(:fresh_strategy) { Class.new(OmniAuth::Strategies::Slack) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe "Subclassing Behavior" do
    subject { fresh_strategy }

    it "performs the OmniAuth::Strategy included hook" do
      expect(OmniAuth.strategies).to include(OmniAuth::Strategies::Slack)
      expect(OmniAuth.strategies).to include(subject)
    end
  end

  describe "#client" do
    subject { fresh_strategy }

    it "is initialized with symbolized client_options" do
      instance = subject.new(app, client_options: { "authorize_url" => "https://example.com" })
      expect(instance.client.options[:authorize_url]).to eq("https://example.com")
    end

    it "sets ssl options as connection options" do
      instance = subject.new(app, client_options: { "ssl" => { "ca_path" => "foo" } })
      expect(instance.client.options[:connection_opts][:ssl]).to eq(ca_path: "foo")
    end
  end

  describe "#callback_phase" do
    subject(:instance) { fresh_strategy.new("abc", "def") }

    let(:params) do
      {
        "error_reason" => "user_denied",
        "error" => "access_denied",
        "state" => state
      }
    end
    let(:state) { "secret" }

    before do
      allow(instance).to receive(:request) do
        double("Request", params: params)
      end

      allow(instance).to receive(:session) do
        double("Session", delete: state)
      end
    end

    it "fails with the error received" do
      expect(instance).to receive(:fail!).with("user_denied", anything)

      instance.callback_phase
    end

    describe "CSRF errors" do
      it "fails with the error received if state is missing and CSRF verification is disabled" do
        params["state"] = nil
        instance.options.provider_ignores_state = true

        expect(instance).to receive(:fail!).with("user_denied", anything)

        instance.callback_phase
      end

      it "fails with a CSRF error if the state is missing" do
        params["state"] = nil

        expect(instance).to receive(:fail!).with(:csrf_detected, anything)
        instance.callback_phase
      end

      it "fails with a CSRF error if the state is invalid" do
        params["state"] = "invalid"

        expect(instance).to receive(:fail!).with(:csrf_detected, anything)
        instance.callback_phase
      end
    end
  end

  describe "#credentials" do
    let(:strategy) { fresh_strategy.new("abc", "def") }
    let(:access_token) { instance_double("OAuth2::AccessToken") }

    before do
      allow(strategy).to receive(:access_token).and_return(access_token)
      allow(access_token).to receive(:token).and_return("123")
      expires_at = double("expires_at", present?: false)
      expires_in = double("expires_in", present?: false)
      allow(access_token).to receive(:expires_at).and_return(expires_at)
      allow(access_token).to receive(:expires_in).and_return(expires_in)
    end

    it "returns a Hash" do
      expect(strategy.credentials).to be_a(Hash)
    end

    it "contains token" do
      expect(strategy.credentials["token"]).to eq("123")
    end

    it "contains expiry status" do
      expect(strategy.credentials["expires"]).to be_falsy
    end

    it "contains refresh token and expiry time when expiring" do
      expires_at = double((Time.now + 600).to_i, present?: true)
      allow(access_token).to receive(:expires_at).and_return(expires_at)
      allow(access_token).to receive(:refresh_token).and_return("321")
      expect(strategy.credentials["refresh_token"]).to eq("321")
      expect(strategy.credentials["expires_at"]).to eq(access_token.expires_at)
    end
  end

  describe "#uid" do
    let(:strategy) { fresh_strategy.new("abc", "def") }
    before do
      allow(strategy).to receive(:identity).and_return("user" => { "id" => "U123" }, "team" => { "id" => "T456" })
    end

    it "returns uid combined from user id and team id" do
      expect(strategy.uid).to eq("U123-T456")
    end
  end

  describe "#secure_compare" do
    subject { fresh_strategy }

    it "returns true when the two inputs are the same and false otherwise" do
      instance = subject.new("abc", "def")
      expect(instance.send(:secure_compare, "a", "a")).to be true
      expect(instance.send(:secure_compare, "b", "a")).to be false
    end
  end

  describe "#auth_hash" do
    let(:strategy) { fresh_strategy.new("abc", "def") }
    let(:name) { "slack" }
    let(:uid) { "U123-T456" }
    let(:info) { { name: "John Doe", email: "john@example.com" }.to_json }
    let(:credentials_data) do
      {
        "token" => "123",
        "expires" => true,
        "refresh_token" => "321",
        "expires_at" => (Time.now + 600).to_i
      }
    end
    let(:extra_data) { { some: "extra_data" }.to_json }

    before do
      allow(strategy).to receive(:name).and_return(name)
      allow(strategy).to receive(:uid).and_return(uid)
      allow(strategy).to receive(:info).and_return(info)
      allow(strategy).to receive(:credentials).and_return(credentials_data)
      allow(strategy).to receive(:extra).and_return(extra_data)
      allow(strategy).to receive(:skip_info?).and_return(false)
    end

    it "returns a valid AuthHash with provider, uid, info, credentials, and extra" do
      auth_hash = strategy.auth_hash

      expect(auth_hash.provider).to eq(name)
      expect(auth_hash.uid).to eq(uid)
      expect(auth_hash.info).to eq(info)
      expect(auth_hash.credentials).to eq(credentials_data)
      expect(auth_hash.extra).to eq(extra_data)
    end

    context "when skip_info? is true" do
      before do
        allow(strategy).to receive(:skip_info?).and_return(true)
      end

      it "returns a valid AuthHash without info" do
        auth_hash = strategy.auth_hash

        expect(auth_hash.provider).to eq(name)
        expect(auth_hash.uid).to eq(uid)
        expect(auth_hash.info).to be_nil
        expect(auth_hash.credentials).to eq(credentials_data)
        expect(auth_hash.extra).to eq(extra_data)
      end
    end

    context "when credentials_data is nil" do
      before do
        allow(strategy).to receive(:credentials).and_return(nil)
      end

      it "returns a valid AuthHash without credentials" do
        auth_hash = strategy.auth_hash

        expect(auth_hash.provider).to eq(name)
        expect(auth_hash.uid).to eq(uid)
        expect(auth_hash.info).to eq(info)
        expect(auth_hash.credentials).to be_nil
        expect(auth_hash.extra).to eq(extra_data)
      end
    end

    context "when extra_data is nil" do
      before do
        allow(strategy).to receive(:extra).and_return(nil)
      end

      it "returns a valid AuthHash without extra" do
        auth_hash = strategy.auth_hash

        expect(auth_hash.provider).to eq(name)
        expect(auth_hash.uid).to eq(uid)
        expect(auth_hash.info).to eq(info)
        expect(auth_hash.credentials).to eq(credentials_data)
        expect(auth_hash.extra).to be_nil
      end
    end
  end
end

# rubocop:enable Metrics/BlockLength
