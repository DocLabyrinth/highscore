require 'models/score'

describe HighScore::Models::Score do
  it do
    is_expected.to validate_presence_of(:player_id)
    is_expected.to validate_presence_of(:game_id)
    is_expected.to validate_presence_of(:score)
    is_expected.to validate_numericality_of(:score)
  end

  describe "class methods" do
    describe "personal board key" do
      it "creates a daily key" do
        created_at = DateTime.new(2001,2,3,4,5,6)
        score = HighScore::Models::Score.personal_board_key('a_player', 'a_game', created_at, 'daily')
        expect( score ).to eq("scoreboard:daily:2001-2-3:a_game:a_player")
      end

      it "creates a weekly key" do
        created_at = DateTime.new(2001,2,3,4,5,6)
        score = HighScore::Models::Score.personal_board_key('a_player', 'a_game', created_at, 'weekly')
        expect( score ).to eq("scoreboard:weekly:2001-05:a_game:a_player")
      end
      
      it "creates a monthly key" do
        created_at = DateTime.new(2001,2,3,4,5,6)
        score = HighScore::Models::Score.personal_board_key('a_player', 'a_game', created_at, 'monthly')
        expect( score ).to eq("scoreboard:monthly:2001-2:a_game:a_player")
      end
    end

    describe "game board key" do
      it "creates a daily key" do
        created_at = DateTime.new(2001,2,3,4,5,6)
        score = HighScore::Models::Score.game_board_key('a_game', created_at, 'daily')
        expect( score ).to eq("scoreboard:daily:2001-2-3:a_game")
      end

      it "creates a weekly key" do
        created_at = DateTime.new(2001,2,3,4,5,6)
        score = HighScore::Models::Score.game_board_key('a_game', created_at, 'weekly')
        expect( score ).to eq("scoreboard:weekly:2001-05:a_game")
      end
      
      it "creates a monthly key" do
        created_at = DateTime.new(2001,2,3,4,5,6)
        score = HighScore::Models::Score.game_board_key('a_game', created_at, 'monthly')
        expect( score ).to eq("scoreboard:monthly:2001-2:a_game")
      end
    end
  end

  describe "after save" do
    describe "personal scoreboard" do
      it "inserts the score in redis and caps the number of recorded scores" do
        score = make_score

        created_at = Time.now
        RR.stub(score).created_at { created_at }

        daily_key = HighScore::Models::Score.personal_board_key(score.player_id, score.game_id, score.created_at, 'daily')
        weekly_key = HighScore::Models::Score.personal_board_key(score.player_id, score.game_id, score.created_at, 'weekly')
        monthly_key = HighScore::Models::Score.personal_board_key(score.player_id, score.game_id, score.created_at, 'monthly')

        redis = HighScore::Wrapper.redis

        RR.mock(redis).zadd(daily_key, score.score, score.player_id)
        RR.mock(redis).zremrangbyrank(daily_key, 0, -Global.leaderboard.personal_limit)
        RR.mock(redis).zadd(weekly_key, score.score, score.player_id)
        RR.mock(redis).zremrangbyrank(weekly_key, 0, -Global.leaderboard.personal_limit)
        RR.mock(redis).zadd(monthly_key, score.score, score.player_id)
        RR.mock(redis).zremrangbyrank(monthly_key, 0, -Global.leaderboard.personal_limit)
        
        RR.stub( HighScore::Wrapper ).redis.returns(redis)

        make_score.save
      end
    end

    it "updates the game's scoreboards" do
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
