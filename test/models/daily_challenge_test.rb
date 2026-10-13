require "test_helper"

class DailyChallengeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Игрок", email: "player@example.com", password: "secure-pass-123")
    @challenge = DailyChallenge.create!(
      title: "Разминка перед игрой",
      prompt: "8 × 7 + 14 = ?",
      answer: "70",
      reward_chips: 250,
      active_on: Date.current
    )
  end

  test "a correct answer awards the reward and records completion" do
    assert @challenge.solve!(user: @user, answer: " 70 ")

    assert_equal 250, @user.reload.chip_balance
    assert_equal 250, @challenge.challenge_completions.sole.reward_chips
  end

  test "an incorrect answer does not award chips or complete the challenge" do
    assert_not @challenge.solve!(user: @user, answer: "69")

    assert_equal 0, @user.reload.chip_balance
    assert_empty @challenge.challenge_completions
  end

  test "the same user cannot claim a challenge reward twice" do
    assert @challenge.solve!(user: @user, answer: "70")
    assert_not @challenge.solve!(user: @user, answer: "70")

    assert_equal 250, @user.reload.chip_balance
    assert_equal 1, @challenge.challenge_completions.count
  end

  test "creates today's challenge from the latest published challenge after a date change" do
    @challenge.update!(active_on: Date.yesterday)

    today = DailyChallenge.today

    assert_equal Date.current, today.active_on
    assert_equal @challenge.title, today.title
    assert_equal @challenge.prompt, today.prompt
    assert_equal @challenge.answer, today.answer
    assert_equal @challenge.reward_chips, today.reward_chips
  end
end
