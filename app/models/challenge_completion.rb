class ChallengeCompletion < ApplicationRecord
  belongs_to :daily_challenge
  belongs_to :user

  validates :user_id, uniqueness: { scope: :daily_challenge_id }
  validates :reward_chips, numericality: { only_integer: true, greater_than: 0 }
end
