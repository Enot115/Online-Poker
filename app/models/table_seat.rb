class TableSeat < ApplicationRecord
  class AlreadyCashedOutError < StandardError; end

  belongs_to :poker_table
  belongs_to :user

  scope :active, -> { where(left_at: nil) }

  validates :stack, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: {
    scope: :poker_table_id,
    conditions: -> { where(left_at: nil) }
  }

  def cash_out!
    with_lock do
      raise AlreadyCashedOutError, "Seat has already been cashed out" if left_at?

      amount = stack
      transaction do
        user.credit_chips!(amount) if amount.positive?
        update!(stack: 0, left_at: Time.current)
      end
      amount
    end
  end
end
