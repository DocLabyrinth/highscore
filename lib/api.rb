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
        HighScore::Models::Score.create!({
          player_id: params[:player_id],
          game_id: params[:game_id],
          score: params[:score],
        })
      end
    end
  end
end
