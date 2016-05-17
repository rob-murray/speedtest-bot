#!/usr/bin/python

import os
import os.path
import csv
import sys

import twitter

twitter_consumer_key = os.getenv("TWITTER_CONSUMER_KEY", None)
twitter_consumer_secret = os.getenv("TWITTER_CONSUMER_SECRET", None)
twitter_access_token = os.getenv("TWITTER_ACCESS_TOKEN", None)
twitter_access_token_secret = os.getenv("TWITTER_TOKEN_SECRET", None)
broadband_service_provider_twitter_name = os.getenv("BBAND_SERVICE_TWITTER_NAME", "")
IS_DEBUG = os.getenv("DEBUG", None) == "yes"
LOG_FILE = "./daily_results.csv"

def tweet_from_results(results):
  return "My @virginmedia avg broadband speeds over the past 24 hrs are {}. From SpeedTestBot".format(results.to_display())

class SpeedTestBotResults(object):
  @staticmethod
  def from_csv(source_file):
    results = SpeedTestBotResults()
    f = open(source_file, 'rb')
    try:
      reader = csv.reader(f, delimiter=';')
      for row in reader:
        results.add_row(row)
    finally:
      f.close()

    return results

  def __init__(self):
    self.results = []

  def add_row(self, row_data):
    '''
    Parse results row from csv

    Format: latency, download speed, upload speed
    '''
    if row_data is not None:
      result = tuple(map(self._parse_value, row_data))
      if self._valid_result(result):
        self.results.append(result)

  def average_download_speed(self):
    download_results = []
    for result in self.results:
      download_results.append(result[1])
    return self._mean(download_results)

  def average_upload_speed(self):
    upload_results = []
    for result in self.results:
      upload_results.append(result[2])
    return self._mean(upload_results)

  def average_latency(self):
    latency_results = []
    for result in self.results:
      latency_results.append(result[0])
    return self._mean(latency_results)

  def number_of_results(self):
    return len(self.results)

  def is_valid(self):
    return self.number_of_results() > 0

  def _valid_result(self, result):
    # Allow zero values but ignore non-numeric error values
    return all(i != None and i != float('nan') for i in result)

  def _parse_value(self, value):
    try:
      return float(value)
    except ValueError:
      # If the result cant be parsed into a float then use zero as the data has shown
      #   that the internet connection is down or unable to dl/upload. We dont want
      #   to bias the results by excluding error states.
      return 0.0

  def to_display(self):
    return ("download={:.2f} Mbit/s "
          "upload={:.2f} Mbit/s "
          "latency={:.1f} ms".format(self.average_download_speed(), self.average_upload_speed(), self.average_latency()))

  def _mean(self, list):
    if len(list) > 0:
      return float(sum(list))/len(list)
    else:
      return 0


def main(argv):
  if not os.path.isfile(LOG_FILE):
    print("Cannot find file %s" % LOG_FILE)
    sys.exit()

  try:
    API = twitter.Api(consumer_key=twitter_consumer_key,
                      consumer_secret=twitter_consumer_secret,
                      access_token_key=twitter_access_token,
                      access_token_secret=twitter_access_token_secret)
    speedbot_results = SpeedTestBotResults.from_csv(LOG_FILE)

    if speedbot_results.is_valid():
      print("Tweeting results !")
      if not IS_DEBUG:
        status = API.PostUpdate(tweet_from_results(speedbot_results))
        print "'%s' just posted: '%s'" % (status.user.name, status.text)
      else:
        print("Tweet message (not posted):")
        print(tweet_from_results(speedbot_results))

  finally:
    if not IS_DEBUG:
      print("Removing file")
      os.remove(LOG_FILE)

if __name__ == "__main__":
   main(sys.argv[1:])
