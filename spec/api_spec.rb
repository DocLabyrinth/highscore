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

        expect { post "/score", request }.to change{ HighScore::Models::Score.count }.by(1)
        expect( last_response.status ).to eq(201)

        body = JSON.parse(last_response.body)
        expect_date = JSON.parse(HighScore::Models::Score.first.to_json)["created_at"]

          expect( body["player_id"] ).to eq(request[:player_id])
          expect( body["game_id"] ).to eq(request[:game_id])
          expect( body["score"] ).to eq(request[:score])
          expect( body["created_at"] ).to eq(expect_date)
          expect( body["personal_ranks"] ).to eq({
            "daily" => 1,
            "weekly" => 1,
            "monthly" => 1,
          })
          expect( body["game_ranks"] ).to eq({
            "daily" => 1,
            "weekly" => 1,
            "monthly" => 1,
          })

          expect( body.slice("player_id", "game_id", "score", "created_at", "personal_ranks", "game_ranks") ).to eq(body)
      end

      describe "returns the player's overall rank for each period" do
        describe "game ranks" do
          it "returns the rank when the player is on the leaderboard" do
            1.upto(3) do |count|
              HighScore::Models::Score.create!({
                :player_id => "player_#{count}",
                :game_id => "some_game",
                :score => 10 + count,
              })
            end

            post "/score", make_request({
              :player_id => "some_player",
              :game_id => "some_game",
              :score => 10
            })
            body = JSON.parse(last_response.body)
            ranks = body['game_ranks']
            expect( ranks['daily'] ).to eq(4)
            expect( ranks['weekly'] ).to eq(4)
            expect( ranks['monthly'] ).to eq(4)
          end

          it "returns the rank when the player is outside the leaderboard" do
            1.upto(Global.leaderboard.game_limit) do |count|
              HighScore::Models::Score.create!({
                :player_id => "player_#{count}",
                :game_id => "some_game",
                :score => 10 + count,
              })
            end

            post "/score", make_request({
              :player_id => "some_player",
              :game_id => "some_game",
              :score => 10
            })
            body = JSON.parse(last_response.body)
            ranks = body['game_ranks']
            expect( ranks['daily'] ).to eq(Global.leaderboard.game_limit + 1)
            expect( ranks['weekly'] ).to eq(Global.leaderboard.game_limit + 1)
            expect( ranks['monthly'] ).to eq(Global.leaderboard.game_limit + 1)
          end
        end

        describe "personal ranks" do
          it "returns the rank when the player is on the leaderboard" do
            1.upto(3) do |count|
              HighScore::Models::Score.timeless.create!({
                :player_id => "some_player",
                :game_id => "some_game",
                :score => 10 + count,
                :created_at => Time.now - (count+30).seconds
              })
            end

            post "/score", make_request({
              :player_id => "some_player",
              :game_id => "some_game",
              :score => 10
            })

            body = JSON.parse(last_response.body)
            ranks = body['personal_ranks']
            expect( ranks['daily'] ).to eq(4)
            expect( ranks['weekly'] ).to eq(4)
            expect( ranks['monthly'] ).to eq(4)
          end

          it "returns nil when the player is outside the leaderboard" do
            1.upto(Global.leaderboard.personal_limit) do |count|
              HighScore::Models::Score.timeless.create!({
                :player_id => "some_player",
                :game_id => "some_game",
                :score => 10 + count,
                :created_at => Time.now - (count+30).seconds
              })
            end

            post "/score", make_request({
              :player_id => "some_player",
              :game_id => "some_game",
              :score => 10
            })

            body = JSON.parse(last_response.body)
            ranks = body['personal_ranks']
            expect( ranks['daily'] ).to be_nil
            expect( ranks['weekly'] ).to be_nil
            expect( ranks['monthly'] ).to be_nil
            body = JSON.parse(last_response.body)
          end
        end
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

    describe "uncaught exceptions" do
      it "returns a response with a backtrace in development mode" do
        stub(HighScore::Models::Score).create! { raise RuntimeError.new('no') }
        stub(Global).environment { :development }
        post "/score", make_request
        body = JSON.parse(last_response.body)
        expect( last_response.status ).to eq(500)
        expect( body['error'] ).to eq("RuntimeError - no")
        expect( body['backtrace'].length ).to be > 1
      end

      it "returns nothing except the status in production mode" do
        stub(HighScore::Models::Score).create! { raise RuntimeError.new('no') }
        stub(Global).environment { :production }
        post "/score", make_request
        body = JSON.parse(last_response.body)
        expect( last_response.status ).to eq(500)
        expect( body['error'] ).to eq("Internal Error")
        expect( body['backtrace'] ).to be_nil
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

  describe "GET /table" do
    describe "GET /table/:period/:game_id" do
    end
  end
end
