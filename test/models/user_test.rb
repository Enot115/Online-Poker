require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  self.use_transactional_tests = false

  setup do
    @user = User.create!(name: "Игрок", email: "player@example.com", password: "secure-pass-123")
  end

  teardown do
    @user.destroy! if @user&.persisted?
  end

  test "crediting chips increases the balance" do
    assert_equal 250, @user.credit_chips!(250)
  end

  test "debiting chips deducts the balance" do
    @user.credit_chips!(300)

    assert_equal 180, @user.debit_chips!(120)
  end

  test "rejects nonpositive amounts and debits beyond the balance" do
    assert_raises(ArgumentError) { @user.credit_chips!(0) }
    assert_raises(ArgumentError) { @user.debit_chips!(-1) }
    assert_raises(User::InsufficientChipsError) { @user.debit_chips!(1) }
    assert_equal 0, @user.reload.chip_balance
  end

  test "broadcasts the leaderboard after committed chip balance changes" do
    messages = capture_broadcasts("leaderboard") do
      @user.credit_chips!(250)
      @user.debit_chips!(100)
    end

    assert_equal 2, messages.size
    assert_match(/<turbo-stream action="replace" target="leaderboard"/, messages.first)
    assert_match(/250/, messages.first)
    assert_match(/150/, messages.last)
  end
end
