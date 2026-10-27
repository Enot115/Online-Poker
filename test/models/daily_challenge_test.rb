require "test_helper"

class DailyChallengeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Игрок", email: "player@example.com", password: "secure-pass-123")
    @hour_slot = Time.current.beginning_of_hour
    @challenge = DailyChallenge.create!(
      title: "Разминка перед игрой",
      prompt: "8 × 7 + 14 = ?",
      answer: "70",
      reward_chips: 100,
      active_on: @hour_slot.to_date,
      hour: @hour_slot.hour
    )
  end

  test "a correct answer awards the reward and records completion" do
    assert @challenge.solve!(user: @user, answer: " 70 ")

    assert_equal 100, @user.reload.chip_balance
    assert_equal 100, @challenge.challenge_completions.sole.reward_chips
  end

  test "an incorrect answer does not award chips or complete the challenge" do
    assert_not @challenge.solve!(user: @user, answer: "69")

    assert_equal 0, @user.reload.chip_balance
    assert_empty @challenge.challenge_completions
  end

  test "the same user cannot claim a challenge reward twice" do
    assert @challenge.solve!(user: @user, answer: "70")
    assert_not @challenge.solve!(user: @user, answer: "70")

    assert_equal 100, @user.reload.chip_balance
    assert_equal 1, @challenge.challenge_completions.count
  end

  test "creates a stable integral challenge for each hour" do
    @challenge.destroy!

    current_challenge = DailyChallenge.current_hour
    assert_equal @hour_slot.to_date, current_challenge.active_on
    assert_equal @hour_slot.hour, current_challenge.hour
    assert_match(/\\int/, current_challenge.prompt)
    assert_equal current_challenge, DailyChallenge.current_hour

    next_hour = @hour_slot + 1.hour
    travel_to(next_hour) do
      next_challenge = DailyChallenge.current_hour

      assert_equal next_hour.to_date, next_challenge.active_on
      assert_equal next_hour.hour, next_challenge.hour
      assert_not_equal current_challenge.id, next_challenge.id
      assert_match(/\\int/, next_challenge.prompt)
    end
  end

  test "hourly generator cycles through four integral challenge types" do
    @challenge.destroy!
    expected_titles = [
      "Интеграл с многочленом",
      "Двойной интеграл",
      "Интегрирование по частям",
      "Интеграл по треугольной области"
    ]

    4.times do |offset|
      slot = @hour_slot + offset.hours
      travel_to(slot) do
        challenge = DailyChallenge.current_hour

        assert_equal expected_titles[slot.hour % 4], challenge.title
        assert_match(/\\int/, challenge.prompt)
        assert_equal 100, challenge.reward_chips
        assert challenge.solve!(user: @user, answer: challenge.answer)
      end
    end

    assert_equal 400, @user.reload.chip_balance
  end
end
