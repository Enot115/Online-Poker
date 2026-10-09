require "test_helper"

class PokerTableTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Игрок", email: "player@example.com", password: "secure-pass-123")
    @table = PokerTable.create!(
      name: "Тёплый стол",
      small_blind: 10,
      big_blind: 20,
      buy_in: 200,
      max_players: 1
    )
    @user.credit_chips!(500)
  end

  test "joining debits the buy-in and creates a seat with the starting stack" do
    seat = @table.join!(@user)

    assert_equal 300, @user.reload.chip_balance
    assert_equal 200, seat.stack
    assert_equal [@user], @table.players
  end

  test "cannot join when the table is full" do
    @table.join!(@user)
    another_user = User.create!(name: "Другой", email: "another@example.com", password: "secure-pass-123")
    another_user.credit_chips!(500)

    assert_raises(PokerTable::TableFullError) { @table.join!(another_user) }
    assert_equal 500, another_user.reload.chip_balance
  end

  test "cashing out returns the stack once" do
    seat = @table.join!(@user)
    seat.update!(stack: 260)

    assert_equal 260, seat.cash_out!
    assert_equal 560, @user.reload.chip_balance
    assert_not_nil seat.reload.left_at
    assert_raises(TableSeat::AlreadyCashedOutError) { seat.cash_out! }
    assert_equal 560, @user.reload.chip_balance

    rejoined_seat = @table.join!(@user)
    assert_equal 200, rejoined_seat.stack
    assert_equal 360, @user.reload.chip_balance
  end
end
