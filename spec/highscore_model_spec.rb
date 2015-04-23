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

  describe "#redis_value" do
    it "generates a value for the redis sorted set" do
      score = make_score
      expect( HighScore::Models::Score.redis_value(score) ).to eq("#{score.id}-#{score.player_id}-#{score.created_at}")
    end

    it "extracts values from the redis value" do
      score = make_score
      redis_value = HighScore::Models::Score.redis_value(score)
      expect( HighScore::Models::Score.extract_redis_value(redis_value) ).to eq({
        :id => score.id.to_s,
        :player_id => score.player_id,
        :created_at => score.created_at,
      })
    end
  end

  describe "#update_leaderboards" do
    describe "personal leaderboards" do
      it "inserts the score in redis and caps the number of recorded scores" do
        created_at = Time.now
        score = make_score(:created_at => created_at)

        keys = HighScore::Models::Score.leaderboard_keys({
          :player_id => score.player_id,
          :game_id => score.game_id,
          :type => 'personal',
          :ref_time => score.created_at,
        })

        redis = HighScore::Wrapper.redis
        stub( HighScore::Wrapper ).redis.returns(redis)

        size_limit = Global.leaderboard.personal_limit + 1

        # adding the keys
        mock.proxy(redis).zadd(keys[:daily], score.score, HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zremrangebyrank(keys[:daily], 0, -size_limit)
        mock.proxy(redis).zadd(keys[:weekly], score.score, HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zremrangebyrank(keys[:weekly], 0, -size_limit)
        mock.proxy(redis).zadd(keys[:monthly], score.score, HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zremrangebyrank(keys[:monthly], 0, -size_limit)

        # retrieving the resulting ranks
        mock.proxy(redis).zrevrank(keys[:daily], HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zrevrank(keys[:weekly], HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zrevrank(keys[:monthly], HighScore::Models::Score.redis_value(score))

        score.update_leaderboards('personal')

        expect( score.personal_ranks[:daily] ).to eq(1)
        expect( score.personal_ranks[:weekly] ).to eq(1)
        expect( score.personal_ranks[:monthly] ).to eq(1)
      end
    end

    describe "game leaderboards" do
      it "inserts the score in redis" do
        created_at = Time.now
        score = make_score(:created_at => created_at)

        keys = HighScore::Models::Score.leaderboard_keys({
          :player_id => score.player_id,
          :game_id => score.game_id,
          :type => 'game',
          :ref_time => score.created_at,
        })

        redis = HighScore::Wrapper.redis
        stub( HighScore::Wrapper ).redis.returns(redis)

        # adding the keys
        mock.proxy(redis).zadd(keys[:daily], score.score, HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zadd(keys[:weekly], score.score, HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zadd(keys[:monthly], score.score, HighScore::Models::Score.redis_value(score))

        # retrieving the resulting ranks
        mock.proxy(redis).zrevrank(keys[:monthly], HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zrevrank(keys[:weekly], HighScore::Models::Score.redis_value(score))
        mock.proxy(redis).zrevrank(keys[:daily], HighScore::Models::Score.redis_value(score))

        score.update_leaderboards('game')

        expect( score.game_ranks[:daily] ).to eq(1)
        expect( score.game_ranks[:weekly] ).to eq(1)
        expect( score.game_ranks[:monthly] ).to eq(1)
      end
    end
  end

  describe "Score.leaderboard_keys" do
    describe "generates leaderboard keys for the current player" do
      it "generates daily, weekly and monthly keys" do
        score = make_score
        score.created_at = DateTime.new(2001,2,3,4,5,6)
        keys = HighScore::Models::Score.leaderboard_keys({
          :player_id => score.player_id,
          :game_id => score.game_id,
          :type => 'personal',
          :ref_time => score.created_at,
        })

        expect( keys[:daily] ).to eq("scoreboard:daily:2001-2-3:some_game:some_player")
        expect( keys[:weekly] ).to eq("scoreboard:weekly:2001-05:some_game:some_player")
        expect( keys[:monthly] ).to eq("scoreboard:monthly:2001-2:some_game:some_player")
      end

      it "generates keys for the current time if :ref_time is not given" do
        score = make_score
        score.created_at = DateTime.new(2001,2,3,4,5,6)

        stub(Time).now { score.created_at }

        keys = HighScore::Models::Score.leaderboard_keys({
          :player_id => score.player_id,
          :game_id => score.game_id,
          :type => 'personal',
        })

        expect( keys[:daily] ).to eq("scoreboard:daily:2001-2-3:some_game:some_player")
        expect( keys[:weekly] ).to eq("scoreboard:weekly:2001-05:some_game:some_player")
        expect( keys[:monthly] ).to eq("scoreboard:monthly:2001-2:some_game:some_player")
      end

      it "fails if the game_id is not present" do
        score = make_score(:game_id => nil)
        expect do
          HighScore::Models::Score.leaderboard_keys({
            :player_id => score.player_id,
            :game_id => score.game_id,
            :type => 'personal',
            :ref_time => score.created_at,
          })
        end.to raise_error(KeyError, "game_id is required to generate leaderboard keys")
      end

      it "fails if the player_id is not present" do
        score = make_score(:player_id => nil)
        expect do
          HighScore::Models::Score.leaderboard_keys({
            :player_id => score.player_id,
            :game_id => score.game_id,
            :type => 'personal',
            :ref_time => score.created_at,
          })
        end.to raise_error(KeyError, "player_id is required to generate leaderboard keys")
      end
    end

    describe "generates leaderboard keys for the current game" do
      it "generates daily, weekly and monthly keys" do
        score = make_score
        score.created_at = DateTime.new(2001,2,3,4,5,6)
        keys = HighScore::Models::Score.leaderboard_keys({
          :player_id => score.player_id,
          :game_id => score.game_id,
          :type => 'game',
          :ref_time => score.created_at,
        })

        expect( keys[:daily] ).to eq("scoreboard:daily:2001-2-3:some_game")
        expect( keys[:weekly] ).to eq("scoreboard:weekly:2001-05:some_game")
        expect( keys[:monthly] ).to eq("scoreboard:monthly:2001-2:some_game")
      end

      it "generates keys for the current time if :ref_time is not given" do
        score = make_score
        score.created_at = DateTime.new(2001,2,3,4,5,6)

        stub(Time).now { score.created_at }

        keys = HighScore::Models::Score.leaderboard_keys({
          :player_id => score.player_id,
          :game_id => score.game_id,
          :type => 'game',
          :ref_time => score.created_at,
        })

        expect( keys[:daily] ).to eq("scoreboard:daily:2001-2-3:some_game")
        expect( keys[:weekly] ).to eq("scoreboard:weekly:2001-05:some_game")
        expect( keys[:monthly] ).to eq("scoreboard:monthly:2001-2:some_game")
      end

      it "fails if the game_id is not present" do
        score = make_score(:game_id => nil)
        expect do
          HighScore::Models::Score.leaderboard_keys({
            :player_id => score.player_id,
            :game_id => score.game_id,
            :type => 'game',
            :ref_time => score.created_at,
          })
        end.to raise_error(KeyError, "game_id is required to generate leaderboard keys")
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
