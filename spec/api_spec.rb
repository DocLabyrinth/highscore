require 'api'
require 'rack/test'

describe HighScore::API do
  include Rack::Test::Methods

  def app
    HighScore::API
  end

  describe "POST /score" do
    describe "validation" do
      it "accepts a valid request" do
        request = make_request

        mock.proxy(HighScore::Models::Score).create!({
          :player_id => request[:player_id],
          :game_id => request[:game_id],
          :score => request[:score],
        })

        post "/score", request
        expect( last_response.status ).to eq(201)
      end

      it "rejects a request with multiple bad parameters" do
        post "/score", make_request({
          :player_id => ['a'],
          :game_id => ['b'],
          :score => ['c'],
        })
        body = JSON.parse(last_response.body)
        expect( last_response.status ).to eq(400)
        expect( body['player_id'] ).to eq(["is invalid"])
        expect( body['game_id'] ).to eq(["is invalid"])
        expect( body['score'] ).to eq(["is invalid"])
      end

      describe "player_id" do
        it "is required" do
          post "/score", make_request(:player_id => nil)
          body = JSON.parse(last_response.body)
          expect( last_response.status ).to eq(400)
          expect( body['player_id'] ).to eq(["can't be blank"])
        end

        it "must be a string" do
          post "/score", make_request(:player_id => {:not_a_string => true})
          body = JSON.parse(last_response.body)
          expect( last_response.status ).to eq(400)
          expect( body['player_id'] ).to eq(["is invalid"])
        end
      end

      describe "game_id" do
        it "is required" do
          post "/score", make_request(:game_id => nil)
          body = JSON.parse(last_response.body)
          expect( last_response.status ).to eq(400)
          expect( body['game_id'] ).to eq(["can't be blank"])
        end

        it "must be a string" do
          post "/score", make_request(:game_id => {:not_a_string => true})
          body = JSON.parse(last_response.body)
          expect( last_response.status ).to eq(400)
          expect( body['game_id'] ).to eq(["is invalid"])
        end
      end

      describe "score" do
        it "is required" do
          post "/score", make_request(:score => nil)
          body = JSON.parse(last_response.body)
          expect( last_response.status ).to eq(400)
          expect( body['score'] ).to eq(["can't be blank", "is not a number"])
        end

        it "must be an integer" do
          post "/score", make_request(:score => {:not_an_integer => true})
          body = JSON.parse(last_response.body)
          expect( last_response.status ).to eq(400)
          expect( body['score'] ).to eq(["is invalid"])
        end
      end
    end

    def make_request(opts = {})
      {
        :game_id => 'some_game',
        :player_id => 'some_player',
        :score => 5000
      }.merge(opts)
    end
  end
end
