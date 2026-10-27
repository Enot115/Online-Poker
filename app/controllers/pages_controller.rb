class PagesController < ApplicationController
  def table
    @table = PokerTable.find(params[:id])
    @seats = @table.table_seats.active.includes(:user).order(:created_at)
    @current_seat = @seats.find { |seat| seat.user_id == current_user&.id }
  end

  def earn
    @challenge = DailyChallenge.current_hour
    @challenge_completed = @challenge&.challenge_completions&.exists?(user: current_user) || false

    week_start = Date.current.beginning_of_week
    week_dates = 7.times.map { |offset| week_start + offset.days }
    completed_dates = if logged_in?
      current_user.challenge_completions
        .joins(:daily_challenge)
        .where(daily_challenges: { active_on: week_dates })
        .pluck("daily_challenges.active_on")
    else
      []
    end

    weekday_labels = %w[ВС ПН ВТ СР ЧТ ПТ СБ]
    @challenge_week = week_dates.map do |date|
      {
        date:,
        label: weekday_labels[date.wday],
        completed: completed_dates.include?(date),
        current: date == Date.current
      }
    end
  end

  def profile
    @table_visit_count = 0
    @challenge_completions = []
    @earned_chips = 0
    @activity = []
    @active_seat = nil

    return unless logged_in?

    table_seats = current_user.table_seats.includes(:poker_table).order(created_at: :desc)
    @table_visit_count = table_seats.count
    @challenge_completions = current_user.challenge_completions.includes(:daily_challenge).order(created_at: :desc).to_a
    @earned_chips = @challenge_completions.sum(&:reward_chips)
    @activity = (table_seats.to_a + @challenge_completions).sort_by(&:created_at).reverse.first(8)
    @active_seat = current_user.table_seats.active.includes(:poker_table).first
  end
end