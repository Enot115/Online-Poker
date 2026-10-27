require "test_helper"

class CoreGameplayTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Игрок", email: "player@example.com", password: "secure-pass-123")
    @challenge = DailyChallenge.create!(
      title: "Интеграл дня",
      prompt: '\left(\frac{3}{4}+\frac{5}{6}\right)\div\frac{19}{12}+\sqrt{81}\times2^2',
      answer: "37",
      reward_chips: 100,
      active_on: Date.current,
      hour: Time.current.hour
    )
  end

  test "a signed-in player solves the daily challenge once" do
    sign_in(@user)
    get earn_chips_path
    assert_select "form[action='#{solve_daily_challenge_path}']"
    assert_select "script[src*='mathjax@3.2.2/es5/tex-chtml.js']"
    assert_includes response.body, '\[\left(\frac{3}{4}'

    post solve_daily_challenge_path, params: { answer: " 37 ", challenge_id: @challenge.id }
    assert_redirected_to earn_chips_path
    follow_redirect!
    assert_select ".flash-notice", /начислено #{@challenge.reward_chips} фишек/
    assert_select ".balance-large", /#{@challenge.reward_chips}/
    assert_select ".challenge-completed"
    assert_select ".week-days .day-done.day-current", count: 1

    post solve_daily_challenge_path, params: { answer: @challenge.answer, challenge_id: @challenge.id }
    follow_redirect!
    assert_select ".flash-alert", "Вы уже получили награду за задачу этого часа."
    assert_equal @challenge.reward_chips, @user.reload.chip_balance
  end

  test "an incorrect answer does not grant chips" do
    sign_in(@user)

    post solve_daily_challenge_path, params: { answer: (@challenge.answer.to_i + 1).to_s, challenge_id: @challenge.id }

    assert_redirected_to earn_chips_path
    follow_redirect!
    assert_select ".flash-alert", "Ответ неверный. Попробуйте ещё раз."
    assert_equal 0, @user.reload.chip_balance
  end

  test "a guest must sign in before claiming a reward" do
    post solve_daily_challenge_path, params: { answer: @challenge.answer, challenge_id: @challenge.id }

    assert_redirected_to login_path
    assert_equal 0, @user.reload.chip_balance
  end

  test "weekly challenge series reflects completed challenge dates" do
    previous_challenge = DailyChallenge.create!(
      title: "Вчерашняя задача",
      prompt: "10 × 10 = ?",
      answer: "100",
      reward_chips: 250,
      active_on: Date.yesterday,
      hour: Time.current.hour
    )
    previous_challenge.solve!(user: @user, answer: "100")
    sign_in(@user)

    get earn_chips_path

    assert_response :success
    assert_select ".week-days > div", count: 7
    assert_select ".week-days > div.day-done", count: 1
    assert_select ".week-days > div.day-current", count: 1
    assert_select ".week-days > div.day-done.day-current", count: 0
  end

  test "a player can earn a new reward in the following hour" do
    sign_in(@user)
    post solve_daily_challenge_path, params: { answer: @challenge.answer, challenge_id: @challenge.id }
    first_balance = @user.reload.chip_balance

    travel_to(Time.current.beginning_of_hour + 1.hour) do
      next_challenge = DailyChallenge.current_hour
      assert_not_equal @challenge.id, next_challenge.id

      post solve_daily_challenge_path, params: { answer: next_challenge.answer, challenge_id: next_challenge.id }
      assert_redirected_to earn_chips_path
      assert_equal first_balance + next_challenge.reward_chips, @user.reload.chip_balance
      assert_equal 2, @user.challenge_completions.count
    end
  end

  test "a player can earn chips, join a table, and cash out" do
    sign_in(@user)
    post solve_daily_challenge_path, params: { answer: @challenge.answer, challenge_id: @challenge.id }
    table = PokerTable.create!(name: "Тёплый стол", small_blind: 10, big_blind: 20, buy_in: 100)

    assert_difference("TableSeat.count", 1) do
      post join_table_path(table)
    end
    assert_redirected_to table_path(table)
    follow_redirect!
    assert_select ".seat-you", /Игрок/
    assert_select ".table-page-stats", /100/
    assert_select ".header-balance strong", "0"
    assert_equal 0, @user.reload.chip_balance

    seat = @user.table_seats.active.sole
    delete leave_table_path(table)
    assert_redirected_to table_path(table)
    follow_redirect!
    assert_select ".flash-notice", /Возвращено 100 фишек/
    assert_equal 100, @user.reload.chip_balance
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