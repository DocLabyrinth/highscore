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
        # update personal leaderboards
        daily_key = Score.personal_board_key(document.player_id, document.game_id, document.created_at, 'daily')
        weekly_key = Score.personal_board_key(document.player_id, document.game_id, document.created_at, 'weekly')
        monthly_key = Score.personal_board_key(document.player_id, document.game_id, document.created_at, 'monthly')

        redis = HighScore::Wrapper.redis
        results = redis.multi do
          redis.zadd(daily_key, document.score, document.player_id)
          redis.zremrangbyrank(daily_key, 0, -Global.leaderboard.personal_limit)
          redis.zadd(weekly_key, document.score, document.player_id)
          redis.zremrangbyrank(weekly_key, 0, -Global.leaderboard.personal_limit)
          redis.zadd(monthly_key, document.score, document.player_id)
          redis.zremrangbyrank(monthly_key, 0, -Global.leaderboard.personal_limit)
        end

        # update game leaderboards
      end

      def self.game_board_key(game_id, created_at, type = 'daily')
        type = 'daily' unless ['daily', 'weekly', 'monthly'].include?(type)

        if type == 'monthly'
          "scoreboard:#{type}:#{created_at.year}-#{created_at.month}:#{game_id}"
        elsif type == 'weekly'
          week_in_year = created_at.strftime('%W')
          "scoreboard:#{type}:#{created_at.year}-#{week_in_year}:#{game_id}"

        else
          "scoreboard:#{type}:#{created_at.year}-#{created_at.month}-#{created_at.day}:#{game_id}"
        end
      end 

      def self.personal_board_key(player_id, game_id, created_at, type = 'daily')
        "#{self.game_board_key(game_id, created_at, type)}:#{player_id}"
      end

    end
  end
end
