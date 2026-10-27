class PokerTable < ApplicationRecord
  class TableFullError < StandardError; end
  class AlreadySeatedError < StandardError; end
  class HandInProgressError < StandardError; end

  has_many :table_seats, dependent: :destroy
  has_many :players, through: :table_seats, source: :user
  has_many :poker_hands, dependent: :destroy

  scope :open, -> { where(active: true) }

  validates :name, presence: true
  validates :small_blind, :big_blind, :buy_in, :max_players,
    numericality: { only_integer: true, greater_than: 0 }
  validate :big_blind_is_at_least_small_blind
  validate :buy_in_covers_big_blind

  def join!(user)
    with_lock do
      raise ActiveRecord::RecordNotFound, "Table is not active" unless active?
      raise HandInProgressError, "A hand is already in progress" if poker_hands.active.exists?
      raise AlreadySeatedError, "Player is already seated at this table" if table_seats.active.exists?(user:)
      raise TableFullError, "Table is full" if table_seats.active.count >= max_players

      transaction do
        user.debit_chips!(buy_in)
        table_seats.create!(user:, stack: buy_in)
      end
    end
  end

  def start_hand_if_ready!
    PokerHand.start_for!(self)
  end

  private

  def big_blind_is_at_least_small_blind
    return unless small_blind && big_blind && big_blind < small_blind

    errors.add(:big_blind, "must be greater than or equal to the small blind")
  end

  def buy_in_covers_big_blind
    return unless buy_in && big_blind && buy_in < big_blind

    errors.add(:buy_in, "must be at least the big blind")
  end
end
