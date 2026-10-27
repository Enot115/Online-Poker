[
  ["Тёплый стол", 10, 20, 200],
  ["После работы", 5, 10, 100],
  ["Тихая раздача", 25, 50, 500]
].each do |name, small_blind, big_blind, buy_in|
  PokerTable.find_or_create_by!(name:) do |table|
    table.small_blind = small_blind
    table.big_blind = big_blind
    table.buy_in = buy_in
    table.max_players = 6
  end
end

DailyChallenge.current_hour