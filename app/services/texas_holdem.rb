class TexasHoldem
  class InvalidAction < StandardError; end
  class NotEnoughPlayers < StandardError; end

  RANKS = %w[2 3 4 5 6 7 8 9 T J Q K A].freeze
  SUITS = %w[C D H S].freeze
  SUIT_NAMES = { "C" => "Clubs", "D" => "Diamonds", "H" => "Hearts", "S" => "Spades" }.freeze

  def initialize(table:, seats:, previous_state: nil)
    @table = table
    @seats = seats
    @previous_state = previous_state
  end

  def start
    seats = @seats.select { |seat| seat.stack.positive? }
    raise NotEnoughPlayers, "At least two funded players are required" if seats.size < 2

    players = seats.map do |seat|
      {
        "user_id" => seat.user_id,
        "seat_id" => seat.id,
        "name" => seat.user.name,
        "stack" => seat.stack,
        "hole_cards" => [],
        "street_bet" => 0,
        "total_bet" => 0,
        "folded" => false,
        "all_in" => false
      }
    end
    dealer = next_dealer(players)
    state = {
      "players" => players,
      "board" => [],
      "deck" => (RANKS.product(SUITS).map { |rank, suit| "#{rank}#{suit}" }).shuffle,
      "street" => "preflop",
      "pot" => 0,
      "current_bet" => 0,
      "minimum_raise" => @table.big_blind,
      "dealer_user_id" => dealer["user_id"],
      "small_blind" => @table.small_blind,
      "big_blind" => @table.big_blind,
      "pending_player_ids" => [],
      "current_player_id" => nil,
      "winner_ids" => [],
      "winner_hands" => [],
      "last_action" => "Раздача началась",
      "finished" => false
    }

    2.times { players.each { |player| player["hole_cards"] << state["deck"].shift } }
    small_blind_player = blind_player(players, dealer, 1)
    big_blind_player = blind_player(players, dealer, 2)
    commit(state, small_blind_player, @table.small_blind)
    commit(state, big_blind_player, @table.big_blind)
    state["current_bet"] = players.map { |player| player["street_bet"] }.max
    state["last_action"] = "Блайнды #{state['small_blind']} / #{state['big_blind']}"
    state["pending_player_ids"] = order_after(players, big_blind_player["user_id"])
      .reject { |player| player["all_in"] }
      .map { |player| player["user_id"] }
    continue_hand(state)
  end

  def act(state:, user_id:, action:, raise_to: nil)
    state = JSON.parse(JSON.generate(state))
    player = state["players"].find { |entry| entry["user_id"] == user_id }
    raise InvalidAction, "You are not seated in this hand" unless player && !player["folded"]
    raise InvalidAction, "It is not your turn" unless state["current_player_id"] == user_id

    case action.to_s
    when "fold"
      player["folded"] = true
      state["last_action"] = "#{player['name']} сбросил карты"
      state["pending_player_ids"].shift
    when "check"
      raise InvalidAction, "You must call or fold" if call_amount(state, player).positive?

      state["last_action"] = "#{player['name']} чек"
      state["pending_player_ids"].shift
    when "call"
      amount = [call_amount(state, player), player["stack"]].min
      raise InvalidAction, "There is nothing to call" unless amount.positive?

      commit(state, player, amount)
      state["last_action"] = "#{player['name']} уравнял #{amount}"
      state["pending_player_ids"].shift
    when "raise"
      target_bet = Integer(raise_to.to_s, 10)
      raise_amount = target_bet - player["street_bet"]
      raise_size = target_bet - state["current_bet"]
      raise InvalidAction, "Raise must exceed the current bet" unless raise_size.positive?
      raise InvalidAction, "Raise is below the minimum" if raise_size < state["minimum_raise"]
      raise InvalidAction, "Raise exceeds your stack" if raise_amount > player["stack"]

      commit(state, player, raise_amount)
      state["minimum_raise"] = raise_size
      state["current_bet"] = player["street_bet"]
      state["last_action"] = "#{player['name']} повысил до #{state['current_bet']}"
      state["pending_player_ids"] = order_after(state["players"], user_id)
        .reject { |entry| entry["folded"] || entry["all_in"] }
        .map { |entry| entry["user_id"] }
    else
      raise InvalidAction, "Unknown action"
    end

    continue_hand(state)
  rescue ArgumentError, TypeError
    raise InvalidAction, "Raise amount must be a whole number"
  end

  private

  def next_dealer(players)
    previous_id = @previous_state&.dig("dealer_user_id")
    previous_index = players.index { |player| player["user_id"] == previous_id }
    players[previous_index ? (previous_index + 1) % players.size : 0]
  end

  def blind_player(players, dealer, blind_number)
    dealer_index = players.index(dealer)
    offset = players.size == 2 ? (blind_number == 1 ? 0 : 1) : blind_number
    players[(dealer_index + offset) % players.size]
  end

  def order_after(players, user_id)
    index = players.index { |player| player["user_id"] == user_id }
    (1..players.size).map { |offset| players[(index + offset) % players.size] }
  end

  def call_amount(state, player)
    [state["current_bet"] - player["street_bet"], 0].max
  end

  def commit(state, player, amount)
    amount = [amount, player["stack"]].min
    player["stack"] -= amount
    player["street_bet"] += amount
    player["total_bet"] += amount
    player["all_in"] = player["stack"].zero?
    state["pot"] += amount
  end

  def continue_hand(state)
    active_players = state["players"].reject { |player| player["folded"] }
    if active_players.size == 1
      award_uncontested_pot(state, active_players.first)
    elsif state["pending_player_ids"].empty?
      if active_players.count { |player| !player["all_in"] } <= 1
        run_out_board(state)
        settle_showdown(state)
      else
        advance_street(state)
      end
    else
      state["current_player_id"] = state["pending_player_ids"].first
    end
    state
  end

  def advance_street(state)
    state["deck"].shift
    case state["street"]
    when "preflop"
      state["board"].concat(state["deck"].shift(3))
      state["street"] = "flop"
    when "flop"
      state["board"] << state["deck"].shift
      state["street"] = "turn"
    when "turn"
      state["board"] << state["deck"].shift
      state["street"] = "river"
    else
      settle_showdown(state)
      return
    end

    state["players"].each { |player| player["street_bet"] = 0 }
    state["current_bet"] = 0
    state["minimum_raise"] = state["big_blind"]
    state["pending_player_ids"] = order_after(state["players"], state["dealer_user_id"])
      .reject { |player| player["folded"] || player["all_in"] }
      .map { |player| player["user_id"] }
    continue_hand(state)
  end

  def run_out_board(state)
    while state["board"].size < 5
      state["deck"].shift
      cards_to_deal = state["board"].empty? ? 3 : 1
      state["board"].concat(state["deck"].shift(cards_to_deal))
    end
  end

  def award_uncontested_pot(state, player)
    player["stack"] += state["pot"]
    state["winner_ids"] = [player["user_id"]]
    state["winner_hands"] = [{ "user_id" => player["user_id"], "name" => player["name"], "hand" => "Без вскрытия" }]
    state["showdown"] = false
    finish(state)
  end

  def settle_showdown(state)
    players = state["players"]
    active_players = players.reject { |player| player["folded"] }
    best_hands = active_players.to_h { |player| [player["user_id"], best_hand(player["hole_cards"] + state["board"])] }
    winners = []
    previous_level = 0

    players.map { |player| player["total_bet"] }.select(&:positive?).uniq.sort.each do |level|
      pot_amount = (level - previous_level) * players.count { |player| player["total_bet"] >= level }
      eligible = active_players.select { |player| player["total_bet"] >= level }
      eligible = active_players if eligible.empty?
      pot_winners = winners_for(eligible, best_hands)
      distribute(pot_winners, pot_amount)
      winners |= pot_winners
      previous_level = level
    end

    state["winner_ids"] = winners.map { |player| player["user_id"] }
    state["winner_hands"] = winners.map do |player|
      { "user_id" => player["user_id"], "name" => player["name"], "hand" => best_hands.fetch(player["user_id"]).name }
    end
    state["showdown"] = true
    state["last_action"] = state["winner_hands"].map { |winner| "#{winner['name']} — #{winner['hand']}" }.join(" · ")
    finish(state)
  end

  def best_hand(cards)
    cards.combination(5).map do |combination|
      PokerRanking::Hand.new(combination.map { |card| ranking_card(card) })
    end.reduce do |best, candidate|
      candidate.defeats?(best) ? candidate : best
    end
  end

  def ranking_card(code)
    rank = code[0...-1] == "T" ? "10" : code[0...-1]
    PokerRanking::Card.new(rank:, suit: SUIT_NAMES.fetch(code[-1]))
  end

  def winners_for(players, hands)
    best = players.map { |player| hands.fetch(player["user_id"]) }.reduce do |current, candidate|
      candidate.defeats?(current) ? candidate : current
    end
    players.select do |player|
      hand = hands.fetch(player["user_id"])
      !hand.defeats?(best) && !best.defeats?(hand)
    end
  end

  def distribute(winners, amount)
    share, remainder = amount.divmod(winners.size)
    winners.each_with_index { |player, index| player["stack"] += share + (index < remainder ? 1 : 0) }
  end

  def finish(state)
    state["pot"] = 0
    state["current_player_id"] = nil
    state["pending_player_ids"] = []
    state["finished"] = true
  end
end