# frozen_string_literal: true
require "pathname"
require "csv"
require "net/http"
require "uri"
require "oauth"

DRY_RUN = !!(ENV["DRY_RUN"] =~ /yes|true/i)
LOG_FILE = "./daily_results.csv".freeze
CSV_OPTIONS = {
  col_sep: ";",
  headers: false,
  skip_blanks: false,
  encoding: "utf-8"
}
TWITTER_AUTH = {
  consumer_key:        ENV.fetch("TWITTER_CONSUMER_KEY"),
  consumer_secret:     ENV.fetch("TWITTER_CONSUMER_SECRET"),
  access_token:        ENV.fetch("TWITTER_ACCESS_TOKEN"),
  access_token_secret: ENV.fetch("TWITTER_TOKEN_SECRET")
}.freeze

class IspConfig
  def all_details_present?
    twitter_account && advertised_download_speed && advertised_download_speed > 0.0
  end

  def twitter_account
    ENV["ISP_TWITTER_ACC"]
  end

  def minimum_download_speed
    return Float::INFINITY unless all_details_present?
    advertised_download_speed - (advertised_download_speed * (slow_download_threshold_percentage / 100))
  end

  def advertised_download_speed
    Float(ENV["ISP_STATED_DL_SPEED"])
  rescue ArgumentError
    nil
  end

  def slow_download_threshold_percentage
    Float(ENV["ISP_SLOW_DL_THRESHOLD_PC"])
  rescue ArgumentError
    20.0
  end

  def to_s
    <<~STR
      <IspConfig twitter_account=#{twitter_account} minimum_download_speed=#{minimum_download_speed} advertised_download_speed=#{advertised_download_speed} slow_download_threshold_percentage=#{slow_download_threshold_percentage}>
    STR
  end
end


# I run this on a device that is unusual architecture and we cannot use the Twitter gem;
# hack with oauth lib
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

Tweet = Struct.new(:text) do
  MAX_TWEET_LEN = 280

  def post!
    client.post_update(to_s)
  end

  def valid?
    to_s.size < MAX_TWEET_LEN
  end

  def to_s
    "My avg broadband speeds over the past 24 hrs are #{text}. From SpeedTestBot"
  end

  private

  def client
    @_client ||= TwitterClient.new
  end
end

class BroadbandProviderTweet < Tweet
  def initialize(isp_details, text)
    @isp_details = isp_details
    super(text)
  end

  def to_s
    <<~TWEET
      My @#{@isp_details.twitter_account} average broadband speeds over the past 24 hrs are #{text}.
      I pay for a #{@isp_details.advertised_download_speed.round} Mbit/s download speed - something isn't right here.
      From SpeedTestBot
    TWEET
  end
end

ResultTriple = Struct.new(:ping, :download, :upload) do
  # if we have any values here then parse to a float, invalid types will end up
  # as 0.0 which is what we want; any result is therefore >= 0.0
  # This is probably not correct for the latency but not sure what else to do atm.
  def self.parse_row(row)
    new(
      *row.map(&:to_f)
    )
  end

  # Equivalent to `to_f`
  # def self.coerce_value(value)
  #   Float(value)
  # rescue ArgumentError
  #   0.0
  # end

  def to_s
    "<ResultTriple ping=#{ping} download=#{download} upload=#{upload}>"
  end
end

class SpeedTestResultsSet
  def self.from_csv(file)
    results_set = new
    CSV.foreach(file, CSV_OPTIONS) do |row|
      results_set.add_result row
    end
    results_set
  end

  def initialize
    @results = []
  end

  def add_result(result_row)
    @results << ResultTriple.parse_row(result_row) if row_has_all_parts?(result_row)
  end

  def valid?
    @results.size > 0
  end

  def to_display
    format(
      "download=%#.2f Mbit/s upload=%#.2f Mbit/s latency=%#.1f ms",
      download_average, upload_average, ping_average
    )
  end

  def to_s
    @results.map(&:to_s)
  end

  def ping_average
    calculate_mean_average(ping_results)
  end

  def download_average
    calculate_mean_average(download_results)
  end

  def upload_average
    calculate_mean_average(upload_results)
  end

  private

  # When the broadband is down, a row of `;;` is written so we treat this as
  # valid so no connection influences averages correctly.
  def row_has_all_parts?(row)
    row && row.size == 3
  end

  def ping_results
    @results.map(&:ping)
  end

  def download_results
    @results.map(&:download)
  end

  def upload_results
    @results.map(&:upload)
  end

  def calculate_mean_average(results_to_calculate)
    Float(
      results_to_calculate.inject(:+) / results_to_calculate.size
    ).round(2)
  end
end

def post(results_set)
  isp_details = IspConfig.new
  if isp_details.all_details_present? && results_set.download_average < isp_details.minimum_download_speed
    tweet = BroadbandProviderTweet.new(isp_details, results_set.to_display)
  else
    tweet = Tweet.new(results_set.to_display)
  end

  if DRY_RUN
    puts "DRY_RUN..."
    puts <<~OUT
      <tweet>
      #{tweet}
      </tweet>
    OUT
    puts "Created using #{tweet.class.name}"
    puts "ISP config: #{isp_details.to_s}"
  else
    if tweet.valid?
      tweet.post!
      puts "Posted Tweet!"
    else
      puts "tweet=#{tweet}"
      abort "Tweet is not valid!"
    end
  end
end

def main
  log_file = Pathname.new LOG_FILE
  unless log_file.exist?
    abort "Cant find file"
  end

  results_set = SpeedTestResultsSet.from_csv(log_file)
  if results_set.valid?
    post results_set
  else
    abort "Results #{results_set.to_s} not valid"
  end
rescue => error
  abort error.message
ensure
  log_file.delete unless DRY_RUN
end

if __FILE__ == $PROGRAM_NAME
  puts "Tweeting speedtest results..."
  main
end
