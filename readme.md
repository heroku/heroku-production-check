# Heroku App Production Check

[Devcenter Artcile](https://devcenter.heroku.com/articles/maximizing-availability)

### Setup

```bash
$ heroku plugins:install git@github.com:heroku/production-check.git
```

### Usage

```bash
$ heroku sudo production:check -a shushu
Checking Cedar... OK
Dyno Redundancy... OK
Production Database... OK
Follower Database... OK
SSL Endpoint... Failed
DNS Configuration... OK
Log Drains... OK
```
