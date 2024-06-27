# frozen_string_literal: true

# OAuth2::Client is derived from the OAuth2 gem: https://gitlab.com/oauth-xx/oauth2
module OAuth2
  class SlackClient < Client
    private

    def build_access_token(response, access_token_opts, access_token_class)
      parsed_response = response.parsed
      parsed_response = parsed_response["authed_user"] unless parsed_response.key?("token_type")
      access_token_class.from_hash(
        self,
        parsed_response.merge(access_token_opts)
      ).tap do |access_token|
        access_token.response = response if access_token.respond_to?(:response=)
      end
    end
  end
end
