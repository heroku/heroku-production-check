# Heroku App Production Check

[Devcenter Artcile](https://devcenter.heroku.com/articles/maximizing-availability)

### Setup

```bash
$ heroku plugins:install git@github.com:heroku/heroku-production-check.git
```

### Usage

```bash
$ heroku production:check -a vault
=== Production check for vault
Cedar                         Passsed
Dyno Redundancy               Passsed
Production Database           Failed 	 remedy: http://bit.ly/PWsbrJ
Follower Database             Failed 	 remedy: http://bit.ly/MGsk39
SSL Endpoint                  Passsed
DNS Configuration             Passsed
Log Drains                    Passsed
```
