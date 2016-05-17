# SpeedTest Bot

Automatic SpeedTest bot that tweets daily broadband speed stats.

A collection of code that might work.

Speed data via [speedtest.net](http://speedtest.net) using [speedtest-cli](https://github.com/sivel/speedtest-cli)

> This is a quick hack. Use at own risk!

### Getting started

With virtualenv setup

```bash
$ pip install -r requirements.txt
```

### Running

#### SpeedTest

Run SpeedTest every hour or so. This writes to a GoogleSpreadsheet and a local file `daily_results.csv`.

```bash
$ sh speedtest_bot.sh
```

#### SpeedTest Tweeter

Run this every day - This will look at the `daily_results.csv` and calculate averages for each value and send a tweet with the data.

The CSV row data is in the format; `41.892;55.97;2.82` - `ping;download;upload`

```
$ export $(cat .env | xargs)
$ python speedtest_bot_tweeter.py # to send tweet
$ DEBUG=yes python speedtest_bot_tweeter.py # to simulate
```

The `.env` file should contain Twitter API keys.

