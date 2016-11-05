# frozen_string_literal: true
require "pathname"
require "csv"
require "twitter"

DRY_RUN = !!(ENV["DRY_RUN"] =~ /yes|true/i)
LOG_FILE = "./daily_results.csv".freeze
def csv_options
  {
    col_sep: ";",
    headers: false,
    skip_blanks: false,
    encoding: "utf-8"
  }
end

Tweet = Struct.new(:text) do
  MAX_TWEET_LEN = 140

  def post!
    client.update(to_s)
  end

  def valid?
    to_s.size < MAX_TWEET_LEN
  end

  def to_s
    "My avg broadband speeds over the past 24 hrs are #{text}. From SpeedTestBot"
  end

  private

  def client
    @_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV.fetch("TWITTER_CONSUMER_KEY")
      config.consumer_secret     = ENV.fetch("TWITTER_CONSUMER_SECRET")
      config.access_token        = ENV.fetch("TWITTER_ACCESS_TOKEN")
      config.access_token_secret = ENV.fetch("TWITTER_TOKEN_SECRET")
    end
  end
end

class BroadbandProviderTweet < Tweet
  def to_s
    "My @virginmedia avg broadband speeds over the past 24 hrs are #{text}. From SpeedTestBot"
  end
end

TWEET_KLASS = Tweet

ResultTriple = Struct.new(:ping, :download, :upload) do
  # if we have any values here then parse to a float, invalid types will end up
  # as 0.0 which is what we want; any result is therefore >= 0.0
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
    CSV.foreach(file, csv_options) do |row|
      results_set.add_result row
    end
    results_set
  end

  def initialize
    @results = []
  end

  def add_result(result_row)
    if row_has_all_parts?(result_row)
      @results << ResultTriple.parse_row(result_row)
    end
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

  private

  # Ensure values are not nil and 3
  def row_has_all_parts?(row)
    row && Array(row).compact.size == 3
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

  def ping_average
    calculate_mean_average(ping_results)
  end

  def download_average
    calculate_mean_average(download_results)
  end

  def upload_average
    calculate_mean_average(upload_results)
  end

  def calculate_mean_average(results_to_calculate)
    Float(
      results_to_calculate.inject(:+) / results_to_calculate.size
    ).round(2)
  end
end

def post(results_set)
  tweet = TWEET_KLASS.new(results_set.to_display)

  if DRY_RUN
    puts tweet
  else
    if tweet.valid?
      tweet.post!
      puts "Posted Tweet!"
    else
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
  abort error
ensure
  log_file.delete unless DRY_RUN
end

if __FILE__ == $PROGRAM_NAME
  puts "Tweeting speedtest results..."
  main
end
