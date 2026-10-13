class PagesController < ApplicationController
  def table
    @table = PokerTable.find(params[:id])
    @seats = @table.table_seats.active.includes(:user).order(:created_at)
    @current_seat = @seats.find { |seat| seat.user_id == current_user&.id }
  end

  def earn
    @challenge = DailyChallenge.today
    @challenge_completed = @challenge&.challenge_completions&.exists?(user: current_user) || false
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