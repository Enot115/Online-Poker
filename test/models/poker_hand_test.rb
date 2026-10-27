require "test_helper"

class PokerHandTest < ActiveSupport::TestCase
  setup do
    @players = 2.times.map do |index|
      user = User.create!(
        name: "Игрок #{index + 1}",
        email: "poker-player-#{index}-#{SecureRandom.hex(3)}@example.com",
        password: "secure-pass-123"
      )
      user.credit_chips!(200)
      user
    end
    @table = PokerTable.create!(name: "Heads-up", small_blind: 10, big_blind: 20, buy_in: 200)
    @players.each { |player| @table.join!(player) }
    @hand = PokerHand.start_for!(@table)
  end

  test "plays all streets and pays the showdown winner" do
    20.times do
      state = @hand.reload.state
      break if state["finished"]

      player = state.fetch("players").find { |entry| entry["user_id"] == state["current_player_id"] }
      action = state["current_bet"] > player["street_bet"] ? "call" : "check"
      @hand.act!(user: User.find(player["user_id"]), action:)
    end

    state = @hand.reload.state
    assert state["finished"]
    assert_equal 5, state["board"].size
    assert_equal 0, state["pot"]
    assert_equal 1, state["winner_ids"].size
    assert_equal 400, @table.table_seats.sum(:stack)
    assert_equal @table.buy_in + @table.big_blind,
      @table.table_seats.find_by!(user_id: state["winner_ids"].first).stack
    assert_not_nil @hand.reload.finished_at
  end

  test "fold ends the hand and awards the pot to the remaining player" do
    state = @hand.state
    current_player_id = state.fetch("current_player_id")
    winner = @players.find { |player| player.id != current_player_id }

    @hand.act!(user: User.find(current_player_id), action: "fold")

    assert @hand.reload.state["finished"]
    assert_equal [winner.id], @hand.state["winner_ids"]
    assert_not @hand.state["showdown"]
    assert_equal @table.buy_in + @table.small_blind,
      @table.table_seats.find_by!(user: winner).stack
  end

  test "rejects an action from a player who is not up" do
    current_player_id = @hand.state.fetch("current_player_id")
    other_player = @players.find { |player| player.id != current_player_id }
    original_state = @hand.state

    assert_raises(TexasHoldem::InvalidAction) do
      @hand.act!(user: other_player, action: "check")
    end

    assert_equal original_state, @hand.reload.state
  end

  test "raise updates the amount to call and enforces the minimum" do
    current_player_id = @hand.state.fetch("current_player_id")
    current_player = @players.find { |player| player.id == current_player_id }
    original_state = @hand.state

    assert_raises(TexasHoldem::InvalidAction) do
      @hand.act!(user: current_player, action: "raise", raise_to: 30)
    end
    assert_equal original_state, @hand.reload.state

    @hand.act!(user: current_player, action: "raise", raise_to: 40)

    state = @hand.reload.state
    assert_equal 40, state["current_bet"]
    assert_equal @players.last.id, state["current_player_id"]
    assert_equal 60, state["pot"]
  end
end