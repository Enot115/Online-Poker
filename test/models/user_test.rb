require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Игрок", email: "player@example.com", password: "secure-pass-123")
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
end
