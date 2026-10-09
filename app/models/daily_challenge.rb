class DailyChallenge < ApplicationRecord
  has_many :challenge_completions, dependent: :destroy
  has_many :completing_users, through: :challenge_completions, source: :user

  validates :title, :prompt, :answer, presence: true
  validates :active_on, presence: true, uniqueness: true
  validates :reward_chips, numericality: { only_integer: true, greater_than: 0 }

  def solve!(user:, answer:)
    with_lock do
      return false unless answer.to_s.strip == self.answer
      return false if challenge_completions.exists?(user:)

      transaction do
        challenge_completions.create!(user:, reward_chips:)
        user.credit_chips!(reward_chips)
      end
      true
    end
  end
end
