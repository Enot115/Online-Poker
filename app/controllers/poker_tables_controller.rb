class PokerTablesController < ApplicationController
  before_action :require_login

  def join
    @table = PokerTable.find(params[:id])
    @table.join!(current_user)
    @table.start_hand_if_ready!
    redirect_to table_path(@table), notice: "Вы заняли место за столом."
  rescue PokerTable::TableFullError
    redirect_to table_path(@table), alert: "За столом больше нет свободных мест."
  rescue PokerTable::AlreadySeatedError
    redirect_to table_path(@table), notice: "Вы уже сидите за этим столом."
  rescue PokerTable::HandInProgressError
    redirect_to table_path(@table), alert: "Нельзя занять место во время раздачи."
  rescue User::InsufficientChipsError
    redirect_to table_path(@table), alert: "Не хватает фишек для входа за этот стол."
  end

  def action
    @table = PokerTable.find(params[:id])
    hand = @table.poker_hands.active.first || raise(ActiveRecord::RecordNotFound)
    hand.act!(user: current_user, action: params[:move], raise_to: params[:raise_to])
    redirect_to table_path(@table)
  rescue TexasHoldem::InvalidAction => error
    redirect_to table_path(@table), alert: error.message
  end

  def next_hand
    @table = PokerTable.find(params[:id])
    raise ActiveRecord::RecordNotFound if @table.poker_hands.active.exists?

    @table.start_hand_if_ready!
    redirect_to table_path(@table), notice: "Новая раздача началась."
  rescue PokerHand::NotEnoughPlayers
    redirect_to table_path(@table), alert: "Для новой раздачи нужны два игрока со стеком."
  end

  def leave
    @table = PokerTable.find(params[:id])
    seat = @table.table_seats.active.find_by(user: current_user)

    unless seat
      redirect_to table_path(@table), alert: "Вы не занимали место за этим столом."
      return
    end

    hand = @table.poker_hands.active.first
    if hand && hand.state.fetch("players").any? { |player| player["seat_id"] == seat.id }
      redirect_to table_path(@table), alert: "Сначала завершите текущую раздачу."
      return
    end

    returned_chips = seat.cash_out!
    redirect_to table_path(@table), notice: "Вы вышли из-за стола. Возвращено #{returned_chips} фишек."
  end
end