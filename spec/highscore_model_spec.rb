require 'models/score'

describe HighScore::Models::Score do
  it do
    is_expected.to validate_presence_of(:player_id)
    is_expected.to validate_presence_of(:game_id)
    is_expected.to validate_presence_of(:score)
    is_expected.to validate_numericality_of(:score)
  end

  describe "after_create hook" do
    it "inserts the score in the personal and game leaderboards" do
      score = make_score
      mock(score).update_leaderboards('personal')
      mock(score).update_leaderboards('game')
      score.save
    end
  end

  describe "#update_leaderboards" do
    describe "personal leaderboards" do
      it "inserts the score in redis using the time as a value and caps the number of recorded scores" do
        created_at = Time.now
        score = make_score(:created_at => created_at)

        keys = score.leaderboard_keys('personal')

        redis = HighScore::Wrapper.redis
        stub( HighScore::Wrapper ).redis.returns(redis)

        size_limit = Global.leaderboard.personal_limit
        mock(redis).zadd(keys[:daily], score.score, score.created_at)
        mock(redis).zremrangbyrank(keys[:daily], 0, -size_limit)
        mock(redis).zadd(keys[:weekly], score.score, score.created_at)
        mock(redis).zremrangbyrank(keys[:weekly], 0, -size_limit)
        mock(redis).zadd(keys[:monthly], score.score, score.created_at)
        mock(redis).zremrangbyrank(keys[:monthly], 0, -size_limit)

        score.update_leaderboards('personal')
      end
    end

    describe "game leaderboards" do
      it "inserts the score in redis using the combined player/time as a value so one player can hold multiple ranks" do
        created_at = Time.now
        score = make_score(:created_at => created_at)

        keys = score.leaderboard_keys('game')

        redis = HighScore::Wrapper.redis
        stub( HighScore::Wrapper ).redis.returns(redis)

        add_value = "#{score.player_id}-#{score.created_at}"

        mock(redis).zadd(keys[:daily], score.score, add_value)
        mock(redis).zadd(keys[:weekly], score.score, add_value)
        mock(redis).zadd(keys[:monthly], score.score, add_value)

        score.update_leaderboards('game')
      end
    end
  end

  describe "#leaderboard_keys" do
    describe "generates leaderboard keys for the current player" do
      it "generates daily, weekly and monthly keys" do
        score = make_score
        score.created_at = DateTime.new(2001,2,3,4,5,6)
        keys = score.leaderboard_keys('personal')

        expect( keys[:daily] ).to eq("scoreboard:daily:2001-2-3:some_game:some_player")
        expect( keys[:weekly] ).to eq("scoreboard:weekly:2001-05:some_game:some_player")
        expect( keys[:monthly] ).to eq("scoreboard:monthly:2001-2:some_game:some_player")
      end

      it "fails if the game_id is not present" do
        score = make_score(:game_id => nil)
        expect do
          score.leaderboard_keys('personal')
        end.to raise_error(KeyError, "game_id is required to generate leaderboard keys")
      end

      it "fails if the player_id is not present" do
        score = make_score(:player_id => nil)
        expect do
          score.leaderboard_keys('personal')
        end.to raise_error(KeyError, "player_id is required to generate leaderboard keys")
      end

      it "fails if there is no created_at time recorded" do
        score = make_score
        expect do
          score.leaderboard_keys('personal')
        end.to raise_error(KeyError, "created_at is required to generate leaderboard keys")
      end
    end

    describe "generates leaderboard keys for the current game" do
      it "generates daily, weekly and monthly keys" do
        score = make_score
        score.created_at = DateTime.new(2001,2,3,4,5,6)
        keys = score.leaderboard_keys('game')

        expect( keys[:daily] ).to eq("scoreboard:daily:2001-2-3:some_game")
        expect( keys[:weekly] ).to eq("scoreboard:weekly:2001-05:some_game")
        expect( keys[:monthly] ).to eq("scoreboard:monthly:2001-2:some_game")
      end

      it "fails if the game_id is not present" do
        score = make_score(:game_id => nil)
        expect do
          score.leaderboard_keys('game')
        end.to raise_error(KeyError, "game_id is required to generate leaderboard keys")
      end

      it "fails if the player_id is not present" do
        score = make_score(:player_id => nil)
        expect do
          score.leaderboard_keys('game')
        end.to raise_error(KeyError, "player_id is required to generate leaderboard keys")
      end

      it "fails if there is no created_at time recorded" do
        score = make_score
        expect do
          score.leaderboard_keys('game')
        end.to raise_error(KeyError, "created_at is required to generate leaderboard keys")
      end
    end
  end

  def make_score(opts = {})
    opts = {
      :player_id => 'some_player',
      :game_id => 'some_game',
      :score => 5000,
    }.merge(opts)

    HighScore::Models::Score.new(opts)
  end
end
