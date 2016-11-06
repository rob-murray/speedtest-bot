# frozen_string_literal: true
require "oauth"
require "json"
require "byebug"

TWITTER_AUTH = {
  consumer_key:        ENV.fetch("TWITTER_CONSUMER_KEY"),
  consumer_secret:     ENV.fetch("TWITTER_CONSUMER_SECRET"),
  access_token:        ENV.fetch("TWITTER_ACCESS_TOKEN"),
  access_token_secret: ENV.fetch("TWITTER_TOKEN_SECRET")
}.freeze

class TwitterClient
  def initialize(auth = TWITTER_AUTH)
    @auth = auth
  end

  def post_update(message)
    response = make_request OAuth::Helper.escape(message)
    case response
    when Net::HTTPSuccess then
      true
    # when Net::HTTPRedirection, Net::HTTPForbidden then
    #   puts response
    #   false
    else
      puts response
      false
    end
  end

  private

  def make_request(encoded_message)
    access_token.request(
      :post,
      "https://api.twitter.com/1.1/statuses/update.json?status=#{encoded_message}"
    )
  end

  def access_token
    @_access_token ||= begin
      consumer = OAuth::Consumer.new(
        TWITTER_AUTH[:consumer_key], TWITTER_AUTH[:consumer_secret],
        site: "https://api.twitter.com", scheme: :header
      )

      token_hash = {
        oauth_token: TWITTER_AUTH[:access_token],
        oauth_token_secret: TWITTER_AUTH[:access_token_secret]
      }
      OAuth::AccessToken.from_hash(consumer, token_hash)
    end
  end
end

t = TwitterClient.new.post_update "another test again"
puts t
