# SpeedTest Bot

Automatic SpeedTest bot that tweets daily broadband speed stats.

A collection of code that might work.

Speed data via [speedtest.net](http://speedtest.net) using [speedtest-cli](https://github.com/sivel/speedtest-cli)

> This is a quick hack. Use at own risk!

### Requirements

* [speedtest-cli](https://github.com/sivel/speedtest-cli)
* Ruby ~> 2.3
* Twitter API keys
* IFTT account with Google docs & Maker

### Getting started

```bash
$ bundle install
```

### Running

#### SpeedTest

Run SpeedTest every hour or so. This writes to a GoogleSpreadsheet and a local file `daily_results.csv`.

```bash
$ sh speedtest_bot.sh
```

The CSV row data is in the format; `41.892;55.97;2.82` - `ping;download;upload`

#### SpeedTest Tweeter

Run this every day - This will look at the `daily_results.csv` and calculate averages for each value and send a tweet with the data.

```
$ export $(cat .env | xargs)
$ ruby speedtest_bot_tweeter.rb # to send tweet
$ DRY_RUN=yes ruby speedtest_bot_tweeter.rb # for a dry run
```

The `.env` file should contain Twitter API keys and IFTT_MAKER_KEY.

