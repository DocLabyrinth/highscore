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

      def self.leaderboard_keys(options = {})
        [:player_id, :game_id, :type].each do |key|
          raise KeyError.new("#{key} is required to generate leaderboard keys") unless options.fetch(key)
        end

        ref_time = options.fetch(:ref_time, Time.now)
        week_in_year = ref_time.strftime('%W')

        game_keys = {
          :daily => [
            "scoreboard:daily",
            [
              ref_time.year,
              ref_time.month,
              ref_time.day,
            ].join('-'),
            options[:game_id],
          ].join(':'),

          :weekly => [
            "scoreboard:weekly",
            [
              ref_time.year,
              week_in_year,
            ].join('-'),
            options[:game_id],
          ].join(':'),

          :monthly => [
            "scoreboard:monthly",
            [
              ref_time.year,
              ref_time.month,
            ].join('-'),
            options[:game_id],
          ].join(':'),
        }

        if options[:type] == "game"
          game_keys
        else
          {
            :daily => "#{game_keys[:daily]}:#{options[:player_id]}",
            :weekly => "#{game_keys[:weekly]}:#{options[:player_id]}",
            :monthly => "#{game_keys[:monthly]}:#{options[:player_id]}",
          }
        end
      end

      def update_leaderboards(type = 'personal')
        keys = Score.leaderboard_keys({
          :player_id => self.player_id,
          :game_id => self.game_id,
          :type => type,
          :ref_time => self.created_at,
        })
        redis = HighScore::Wrapper.redis

        if type == 'personal'
          # cap the personal leaderboards according to the
          # limit from the config to avoid them growing
          # huge for prolific players
          size_limit = Global.leaderboard.personal_limit
          results = redis.multi do
            redis.zadd(keys[:daily], self.score, self.created_at)
            redis.zremrangebyrank(keys[:daily], 0, -size_limit)
            redis.zadd(keys[:weekly], self.score, self.created_at)
            redis.zremrangebyrank(keys[:weekly], 0, -size_limit)
            redis.zadd(keys[:monthly], self.score, self.created_at)
            redis.zremrangebyrank(keys[:monthly], 0, -size_limit)
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
    end
  end
end
