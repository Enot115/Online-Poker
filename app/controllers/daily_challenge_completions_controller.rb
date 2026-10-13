class DailyChallengeCompletionsController < ApplicationController
  before_action :require_login

  def create
    challenge = DailyChallenge.today

    if challenge.nil?
      redirect_to earn_chips_path, alert: "На сегодня задача ещё не опубликована."
    elsif challenge.solve!(user: current_user, answer: params[:answer])
      redirect_to earn_chips_path, notice: "Верно! На баланс начислено #{challenge.reward_chips} фишек."
    elsif challenge.challenge_completions.exists?(user: current_user)
      redirect_to earn_chips_path, alert: "Вы уже получили награду за сегодняшнюю задачу."
    else
      redirect_to earn_chips_path, alert: "Ответ неверный. Попробуйте ещё раз."
    end
  end
end