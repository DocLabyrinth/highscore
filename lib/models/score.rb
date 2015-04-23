require 'mongoid'
require_relative '../wrapper/redis'

module HighScore
  module Models
    class Score
      include Mongoid::Document
      include Mongoid::Timestamps::Created

      attr_reader :personal_ranks, :game_ranks

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
        [:game_id, :type].each do |key|
          raise KeyError.new("#{key} is required to generate leaderboard keys") unless options.fetch(key)
        end

        ref_time = options[:ref_time] || Time.now
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
          unless options[:player_id]
            raise KeyError.new("player_id is required to generate leaderboard keys")
          end
          {
            :daily => "#{game_keys[:daily]}:#{options[:player_id]}",
            :weekly => "#{game_keys[:weekly]}:#{options[:player_id]}",
            :monthly => "#{game_keys[:monthly]}:#{options[:player_id]}",
          }
        end
      end

      def self.redis_value(score)
        "#{score.id}-#{score.player_id}-#{score.created_at}"
      end

      def self.extract_redis_value(value)
        bits = value.split('-')
        {
          :id => bits[0],
          :player_id => bits[1],
          :created_at => bits[2],
        }
      end

      def update_leaderboards(type = 'personal')
        keys = Score.leaderboard_keys({
          :player_id => self.player_id,
          :game_id => self.game_id,
          :type => type,
          :ref_time => self.created_at,
        })
        redis = HighScore::Wrapper.redis

        # cap the personal leaderboards according to the
        # limit from the config to avoid them growing
        # huge for prolific players
        results = redis.multi do
          redis.zadd(keys[:daily], self.score, Score.redis_value(self))
          redis.zadd(keys[:weekly], self.score, Score.redis_value(self))
          redis.zadd(keys[:monthly], self.score, Score.redis_value(self))

          if type == 'personal'
            size_limit = Global.leaderboard.personal_limit + 1
            redis.zremrangebyrank(keys[:daily], 0, -size_limit)
            redis.zremrangebyrank(keys[:weekly], 0, -size_limit)
            redis.zremrangebyrank(keys[:monthly], 0, -size_limit)
          end
        end

        rank_results = redis.multi do
          redis.zrevrank(keys[:daily], Score.redis_value(self))
          redis.zrevrank(keys[:weekly], Score.redis_value(self))
          redis.zrevrank(keys[:monthly], Score.redis_value(self))
        end

        # redis counts from 0 but ranks
        # are from 1 upwards. Keep the
        # nil values to signify when the
        # player didn't place on their
        # personal leaderboard this time
        ranks = {
          :daily => rank_results[0].nil? ? nil : rank_results[0] + 1,
          :weekly => rank_results[1].nil? ? nil : rank_results[1] + 1,
          :monthly => rank_results[2].nil? ? nil : rank_results[2] + 1,
        }

        if type == "personal"
          @personal_ranks = ranks
        else
          @game_ranks = ranks
        end
      end
    end
  end
end
