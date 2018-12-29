# SpeedTest Bot

Automatic SpeedTest bot that collects and tweets daily broadband speed stats. I run this on a Raspberry Pi to collect data on how my broadband is performing.

⚠️ A collection of code that might work. YMMV - you may have to edit some stuff if you want to do something different.

Speed data via [speedtest.net](http://speedtest.net) using [speedtest-cli](https://github.com/sivel/speedtest-cli)

1. Collect broadband download, upload & ping data
2. Send to Google Spreadsheet
3. Tweet daily averages - optionally tag your ISP if you want to notify them when your dl speed averages below the advertised speed you pay for

### Requirements

* [speedtest-cli](https://github.com/sivel/speedtest-cli)
* Ruby ~> 2.5
* Twitter API keys
* IFTT account with Google docs & Maker - see [https://ifttt.com/applets/33618112d-log-speedtest-results-to-spreadsheet](https://ifttt.com/applets/33618112d-log-speedtest-results-to-spreadsheet)

### Getting started

```bash
$ bundle install
```

### Running

#### SpeedTest

Run SpeedTest every hour or so. This writes to a Google Spreadsheet and a local file `daily_results.csv` - the IFTT account with Google docs & Maker should be set up and the `.env` file should contain IFTT_MAKER_KEY.

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

The `.env` file should contain Twitter API keys.

#### Tag ISP

If you include some details about your ISP then when the daily average download speed drops below some threshold then the tweet will tag them.

| Var name | Desc | Example |
|---|---|---|
| `ISP_TWITTER_ACC` | The Twitter account for your ISP | `virginmedia`  |
| `ISP_STATED_DL_SPEED` | The advertised download speed you pay for | `50` would be 50 Mbit/s |
| `ISP_SLOW_DL_THRESHOLD_PC` | The percentage value below the advertised download speed that will trigger the Tweet to be tagged with your ISP account | `20` for 20% - this is the default |

#### Automating

There are 2 things that need to run on some schedule, this schedule can be up to the user. Below are examples with cron.

1. *SpeedTest* job to collect data; eg run this every hour
  `0 * * * * cd /home/speedtest-bot && export $(cat .env | xargs) && ./speedtest_bot.sh`

2. *SpeedTest Tweeter* job to tweet results; eg run this every day at 9am
  `0 9 * * * cd /home/speedtest-bot && export $(cat .env | xargs) && ruby ./speedtest_bot_tweeter.rb`
