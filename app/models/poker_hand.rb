class PokerHand < ApplicationRecord
  class HandInProgressError < StandardError; end

  belongs_to :poker_table

  scope :active, -> { where(finished_at: nil) }
  after_create_commit :broadcast_hand
  after_update_commit :broadcast_hand, if: :saved_change_to_state?

  def self.start_for!(table)
    table.with_lock do
      active_hand = table.poker_hands.active.first
      return active_hand if active_hand

      seats = table.table_seats.active.includes(:user).order(:created_at).to_a
      return unless seats.count { |seat| seat.stack.positive? } >= 2

      previous_state = table.poker_hands.order(id: :desc).first&.state
      state = TexasHoldem.new(table:, seats:, previous_state:).start
      create!(poker_table: table, state:)
    end
  end

  def act!(user:, action:, raise_to: nil)
    with_lock do
      raise HandInProgressError, "Hand is already finished" if finished_at?

      new_state = TexasHoldem.new(table: poker_table, seats: []).act(
        state:,
        user_id: user.id,
        action:,
        raise_to:
      )

      transaction do
        update!(state: new_state, finished_at: (Time.current if new_state["finished"]))
        new_state["players"].each do |player|
          TableSeat.find(player.fetch("seat_id")).update!(stack: player.fetch("stack"))
        end
      end
    end
    state
  end

  def broadcast_hand
    seats = poker_table.table_seats.active.includes(:user).to_a
    seats.each do |seat|
      Turbo::StreamsChannel.broadcast_replace_to(
        "poker_table_#{poker_table_id}_user_#{seat.user_id}",
        target: "game-view",
        partial: "pages/game_view",
        locals: { table: poker_table, seats:, hand: self, current_user: seat.user }
      )
    end
  end
end