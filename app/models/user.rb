class User < ApplicationRecord
  has_secure_password

  class InsufficientChipsError < StandardError; end

  has_many :table_seats, dependent: :destroy
  has_many :poker_tables, through: :table_seats
  has_many :challenge_completions, dependent: :destroy
  has_many :completed_challenges, through: :challenge_completions, source: :daily_challenge

  before_validation :normalize_email
  after_update_commit :broadcast_leaderboard

  validates :name, presence: true, length: { maximum: 60 }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :chip_balance, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def credit_chips!(amount)
    validate_chip_amount!(amount)

    with_lock do
      update!(chip_balance: chip_balance + amount)
    end
    chip_balance
  end

  def debit_chips!(amount)
    validate_chip_amount!(amount)

    with_lock do
      raise InsufficientChipsError, "Not enough chips" if chip_balance < amount

      update!(chip_balance: chip_balance - amount)
    end
    chip_balance
  end

  private

  def validate_chip_amount!(amount)
    raise ArgumentError, "Chip amount must be a positive integer" unless amount.is_a?(Integer) && amount.positive?
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def broadcast_leaderboard
    return unless previous_changes.key?("chip_balance")

    Turbo::StreamsChannel.broadcast_replace_to(
      "leaderboard",
      target: "leaderboard",
      partial: "leaderboards/leaderboard",
      locals: { users: User.order(chip_balance: :desc, id: :asc).limit(10) }
    )
  end
end
