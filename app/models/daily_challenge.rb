class DailyChallenge < ApplicationRecord
  has_many :challenge_completions, dependent: :destroy
  has_many :completing_users, through: :challenge_completions, source: :user

  validates :title, :prompt, :answer, presence: true
  validates :active_on, presence: true, uniqueness: { scope: :hour }
  validates :hour, presence: true, numericality: { only_integer: true, in: 0..23 }
  validates :reward_chips, numericality: { only_integer: true, greater_than: 0 }

  def self.current_hour
    slot = Time.current.beginning_of_hour
    date = slot.to_date
    hour = slot.hour
    challenge = find_by(active_on: date, hour:)
    return challenge if challenge

    attributes = attributes_for_slot(slot)
    create_or_find_by!(active_on: date, hour:) do |record|
      record.assign_attributes(attributes)
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

  def self.attributes_for_slot(slot)
    variation = ((slot.to_date.jd * 24 + slot.hour) % 97) + 1

    case slot.hour % 4
    when 0
      exponent = 3 + 2 * (variation % 5)
      leading = 2 + (variation % 9)
      linear = 3 + (variation % 7)
      {
        title: "Интеграл с многочленом",
        prompt: "\\int_0^1\\left(#{leading * (exponent + 1)}x^{#{exponent}}+#{2 * linear}x\\right)\\,dx",
        answer: (leading + linear).to_s,
        reward_chips: 100
      }
    when 1
      x_exponent = 1 + (variation % 4)
      y_exponent = 1 + ((variation / 3) % 4)
      result = 2 + (variation % 19)
      coefficient = result * (x_exponent + 1) * (y_exponent + 1)
      {
        title: "Двойной интеграл",
        prompt: "\\int_0^1\\int_0^1 #{coefficient}x^{#{x_exponent}}y^{#{y_exponent}}\\,dy\\,dx",
        answer: result.to_s,
        reward_chips: 100
      }
    when 2
      exponent = 3 + 2 * (variation % 5)
      multiplier = 2 + (variation % 23)
      {
        title: "Интегрирование по частям",
        prompt: "\\int_0^1 #{multiplier}e^x\\left((x-1)^{#{exponent}}+#{exponent}(x-1)^{#{exponent - 1}}\\right)\\,dx",
        answer: multiplier.to_s,
        reward_chips: 100
      }
    else
      x_exponent = 1 + (variation % 3)
      y_exponent = 1 + ((variation / 3) % 3)
      result = 3 + (variation % 17)
      coefficient = result * (y_exponent + 1) * (x_exponent + y_exponent + 2)
      {
        title: "Интеграл по треугольной области",
        prompt: "\\int_0^1\\int_0^x #{coefficient}x^{#{x_exponent}}y^{#{y_exponent}}\\,dy\\,dx",
        answer: result.to_s,
        reward_chips: 100
      }
    end
  end
  private_class_method :attributes_for_slot
end
