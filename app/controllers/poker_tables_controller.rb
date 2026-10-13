class PokerTablesController < ApplicationController
  before_action :require_login

  def join
    @table = PokerTable.find(params[:id])
    @table.join!(current_user)
    redirect_to table_path(@table), notice: "Вы заняли место за столом."
  rescue PokerTable::TableFullError
    redirect_to table_path(@table), alert: "За столом больше нет свободных мест."
  rescue PokerTable::AlreadySeatedError
    redirect_to table_path(@table), notice: "Вы уже сидите за этим столом."
  rescue User::InsufficientChipsError
    redirect_to table_path(@table), alert: "Не хватает фишек для входа за этот стол."
  end

  def leave
    @table = PokerTable.find(params[:id])
    seat = @table.table_seats.active.find_by(user: current_user)

    unless seat
      redirect_to table_path(@table), alert: "Вы не занимали место за этим столом."
      return
    end

    returned_chips = seat.cash_out!
    redirect_to table_path(@table), notice: "Вы вышли из-за стола. Возвращено #{returned_chips} фишек."
  end
end