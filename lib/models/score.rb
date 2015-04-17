require 'mongoid'
require_relative '../wrapper/redis'

module HighScore
  module Models
    class Score
      include Mongoid::Document
      include Mongoid::Timestamps::Created

      field :player_id, type: String
      field :game_id, type: String
      field :score, type: Integer

      validates :player_id, presence: true
      validates :game_id, presence: true
      validates :score, presence: true

      validates_numericality_of :score, greater_than_or_equal_to: 0

      after_save do |document|
        self.update_leaderboards('personal')
        self.update_leaderboards('game')
      end

      def update_leaderboards(type = 'personal')
        keys = self.leaderboard_keys(type)
        redis = HighScore::Wrapper.redis

        if type == 'personal'
          # cap the personal leaderboards according to the
          # limit from the config to avoid them growing
          # huge for prolific players
          size_limit = Global.leaderboard.personal_limit
          results = redis.multi do
            redis.zadd(keys[:daily], self.score, self.created_at)
            redis.zremrangbyrank(keys[:daily], 0, -size_limit)
            redis.zadd(keys[:weekly], self.score, self.created_at)
            redis.zremrangbyrank(keys[:weekly], 0, -size_limit)
            redis.zadd(keys[:monthly], self.score, self.created_at)
            redis.zremrangbyrank(keys[:monthly], 0, -size_limit)
          end
        else
          # sorted sets still track unique values, so combine
          # player_id and created_at to ensure one player can
          # hold multiple slots on the leaderboard
          add_value = "#{self.player_id}-#{self.created_at}"

          results = redis.multi do
            redis.zadd(keys[:daily], self.score, add_value)
            redis.zadd(keys[:weekly], self.score, add_value)
            redis.zadd(keys[:monthly], self.score, add_value)
          end
        end
      end

      def leaderboard_keys(type = 'personal')
        ['player_id', 'game_id', 'created_at'].each do |key|
          raise KeyError.new("#{key} is required to generate leaderboard keys") unless self.send(key)
        end
        week_in_year = self.created_at.strftime('%W')

        if type == "game"
          {
            :daily => [
              "scoreboard:daily",
              [
                created_at.year,
                created_at.month,
                created_at.day,
              ].join('-'),
              self.game_id,
            ].join(':'),

            :weekly => [
              "scoreboard:weekly",
              [
                created_at.year,
                week_in_year,
              ].join('-'),
              self.game_id,
            ].join(':'),

            :monthly => [
              "scoreboard:monthly",
              [
                created_at.year,
                created_at.month,
              ].join('-'),
              self.game_id,
            ].join(':'),
          }
        else
          game_keys = self.leaderboard_keys('game')
          {
            :daily => "#{game_keys[:daily]}:#{self.player_id}",
            :weekly => "#{game_keys[:weekly]}:#{self.player_id}",
            :monthly => "#{game_keys[:monthly]}:#{self.player_id}",
          }
        end
      end
    end
  end
end
