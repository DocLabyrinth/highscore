# Prototype of a high-score and leaderboard system.

This code is a prototype of an API which uses Redis's [sorted sets](http://www.redis.io/commands#sorted_set) to provide a fast way of maintaining daily, weekly and monthly leaderboards for any game which needs to register a players' highest scores.

A [docker-compose](http://docs.docker.com/compose/) config file is provided for quick local testing.

## Setup

```
pip install docker-compose
gem install bundler rspec
bundle install
```

## Testing

```
docker-compose up
rspec
```

## Running the API locally

```
rackup
```
