require "test_helper"

class CoreGameplayTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Игрок", email: "player@example.com", password: "secure-pass-123")
    DailyChallenge.create!(
      title: "Разминка перед игрой",
      prompt: "8 × 7 + 14 = ?",
      answer: "70",
      reward_chips: 250,
      active_on: Date.current
    )
  end

  test "a signed-in player solves the daily challenge once" do
    sign_in(@user)
    get earn_chips_path
    assert_select "form[action='#{solve_daily_challenge_path}']"

    post solve_daily_challenge_path, params: { answer: " 70 " }
    assert_redirected_to earn_chips_path
    follow_redirect!
    assert_select ".flash-notice", /начислено 250 фишек/
    assert_select ".balance-large", /250/
    assert_select ".challenge-completed"

    post solve_daily_challenge_path, params: { answer: "70" }
    follow_redirect!
    assert_select ".flash-alert", "Вы уже получили награду за сегодняшнюю задачу."
    assert_equal 250, @user.reload.chip_balance
  end

  test "an incorrect answer does not grant chips" do
    sign_in(@user)

    post solve_daily_challenge_path, params: { answer: "69" }

    assert_redirected_to earn_chips_path
    follow_redirect!
    assert_select ".flash-alert", "Ответ неверный. Попробуйте ещё раз."
    assert_equal 0, @user.reload.chip_balance
  end

  test "a guest must sign in before claiming a reward" do
    post solve_daily_challenge_path, params: { answer: "70" }

    assert_redirected_to login_path
    assert_equal 0, @user.reload.chip_balance
  end

  test "a player can earn chips, join a table, and cash out" do
    sign_in(@user)
    post solve_daily_challenge_path, params: { answer: "70" }
    table = PokerTable.create!(name: "Тёплый стол", small_blind: 10, big_blind: 20, buy_in: 200)

    assert_difference("TableSeat.count", 1) do
      post join_table_path(table)
    end
    assert_redirected_to table_path(table)
    follow_redirect!
    assert_select ".seat-you", /Игрок/
    assert_select ".table-page-stats", /200/
    assert_select ".header-balance strong", "50"
    assert_equal 50, @user.reload.chip_balance

    seat = @user.table_seats.active.sole
    delete leave_table_path(table)
    assert_redirected_to table_path(table)
    follow_redirect!
    assert_select ".flash-notice", /Возвращено 200 фишек/
    assert_equal 250, @user.reload.chip_balance
    assert_not_nil seat.reload.left_at

    get profile_path
    assert_response :success
    assert_select ".profile-stat-grid", /1/
  end

  test "joining a table with too few chips keeps the balance unchanged" do
    sign_in(@user)
    table = PokerTable.create!(name: "Дорогой стол", small_blind: 25, big_blind: 50, buy_in: 500)

    assert_no_difference("TableSeat.count") do
      post join_table_path(table)
    end
    assert_redirected_to table_path(table)
    follow_redirect!
    assert_select ".flash-alert", "Не хватает фишек для входа за этот стол."
    assert_equal 0, @user.reload.chip_balance
  end

  test "a full table rejects another player without charging them" do
    table = PokerTable.create!(name: "Закрытый стол", small_blind: 10, big_blind: 20, buy_in: 200, max_players: 1)
    other_user = User.create!(name: "Другой", email: "other@example.com", password: "secure-pass-123")
    other_user.credit_chips!(200)
    table.join!(other_user)
    @user.credit_chips!(200)
    sign_in(@user)

    assert_no_difference("TableSeat.count") do
      post join_table_path(table)
    end
    assert_redirected_to table_path(table)
    follow_redirect!
    assert_select ".flash-alert", "За столом больше нет свободных мест."
    assert_equal 200, @user.reload.chip_balance
  end

  private

  def sign_in(user)
    post login_path, params: { email: user.email, password: "secure-pass-123" }
  end
end