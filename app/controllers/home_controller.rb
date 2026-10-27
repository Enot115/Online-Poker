class HomeController < ApplicationController
  def show
    @tables = PokerTable.open.order(:id)
    @seat_counts = TableSeat.active.group(:poker_table_id).count
    @current_table_ids = logged_in? ? current_user.table_seats.active.pluck(:poker_table_id) : []
    @challenge = DailyChallenge.current_hour
    @challenge_completed = @challenge.present? && logged_in? &&
      @challenge.challenge_completions.exists?(user: current_user)
    @table_visit_count = logged_in? ? current_user.table_seats.count : 0
  end
end
