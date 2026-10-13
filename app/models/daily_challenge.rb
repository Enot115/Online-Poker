class DailyChallenge < ApplicationRecord
  has_many :challenge_completions, dependent: :destroy
  has_many :completing_users, through: :challenge_completions, source: :user

  validates :title, :prompt, :answer, presence: true
  validates :active_on, presence: true, uniqueness: true
  validates :reward_chips, numericality: { only_integer: true, greater_than: 0 }

  def self.today
    date = Date.current
    challenge = find_by(active_on: date)
    return challenge if challenge

    previous = where("active_on <= ?", date).order(active_on: :desc).first
    return unless previous

    create_or_find_by!(active_on: date) do |challenge|
      challenge.title = previous.title
      challenge.prompt = previous.prompt
      challenge.answer = previous.answer
      challenge.reward_chips = previous.reward_chips
    end
  end

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
