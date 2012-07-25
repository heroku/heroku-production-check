# Heroku App Production Check

A Heroku client plugin to check how well your app meets Heroku's [guidlines for maximizing app availability](https://devcenter.heroku.com/articles/maximizing-availability).

### Setup

```
$ heroku plugins:install https://github.com/heroku/heroku-production-check.git
```

### Usage

```
$ heroku production:check -a vault
=== Production check for vault
Cedar                         Passed
Dyno Redundancy               Passed
Production Database           Failed 	 remedy: http://bit.ly/PWsbrJ
Follower Database             Failed 	 remedy: http://bit.ly/MGsk39
SSL Endpoint                  Passed
DNS Configuration             Passed
Log Drains                    Passed
```
