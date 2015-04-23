require 'grape'

module HighScore
  class API < Grape::API
    format :json

    rescue_from Mongoid::Errors::Validations do |e|
      rack_response(e.document.errors.messages.to_json, 400)
    end

    rescue_from Grape::Exceptions::ValidationErrors do |e|
      # make validation errors from Grape look the same as Mongoid
      response = e.as_json.inject({}) do |obj, error|
        obj[error[:params].first] = error[:messages]
        obj
      end
      rack_response(response.to_json, 400)
    end

    rescue_from :all, backtrace: true do |e|
      if Global.environment == :production
        message = { "error" => "Internal Error" }
        rack_response(message.to_json, 500 )
      else
        message = { "error" => "#{e.class} - #{e.message}" }
        rack_response(format_message(message, e.backtrace), 500 )
      end
    end

    resource :score do
      desc "Record a new high score"
      params do
        requires :player_id, type: String, desc: "ID of the player recording the score"
        requires :game_id, type: String, desc: "ID of the game the score was achieved in"
        requires :score, type: Integer, desc: "The score the player achieved"
      end

      post do
        score = Models::Score.create!({
          player_id: params[:player_id],
          game_id: params[:game_id],
          score: params[:score],
        })

        {
          :player_id => score.player_id,
          :game_id => score.game_id,
          :score => score.score,
          :created_at => score.created_at,
          :personal_ranks => score.personal_ranks || {},
          :game_ranks => score.game_ranks || {},
        }
      end
    end

    namespace :leaderboard do
      desc "Leaderboards of the current recorded scores"

      helpers do
        def format_table(redis_result)
          return [] unless redis_result

          redis_result.each_with_index.map do |item, index|
            score_bits = Models::Score.extract_redis_value(item.first)

            {
              :player_id => score_bits[:player_id],
              :score => item.last.to_i,
              :rank => index + 1,
            }
          end
        end
      end

      get ":period/:game_id" do
        unless ["daily", "weekly", "monthly"].include? params["period"]
          error!('Not Found (period)', 404)
        end

        table_keys = Models::Score.leaderboard_keys({
          :game_id => params[:game_id],
          :type => "game",
        })
        table_key = table_keys[ params["period"].to_sym ]

        redis = Wrapper.redis
        table = redis.zrevrange(table_key, 0, Global.leaderboard.game_limit - 1, :with_scores => true)

        format_table(table)
      end

      get ":period/:game_id/:player_id" do
        unless ["daily", "weekly", "monthly"].include? params["period"]
          error!('Not Found', 404)
        end

        table_keys = Models::Score.leaderboard_keys({
          :game_id => params[:game_id],
          :player_id => params[:player_id],
          :type => "personal",
        })
        table_key = table_keys[params["period"].to_sym]

        redis = Wrapper.redis
        table = redis.zrevrange(table_key, 0, Global.leaderboard.personal_limit - 1, :with_scores => true)

        format_table(table)
      end
    end
  end
end
