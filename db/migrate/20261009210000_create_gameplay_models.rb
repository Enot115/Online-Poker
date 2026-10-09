class CreateGameplayModels < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :chip_balance, :integer, null: false, default: 0
    add_check_constraint :users, "chip_balance >= 0", name: "users_chip_balance_nonnegative"

    create_table :poker_tables do |t|
      t.string :name, null: false
      t.integer :small_blind, null: false
      t.integer :big_blind, null: false
      t.integer :buy_in, null: false
      t.integer :max_players, null: false, default: 6
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_check_constraint :poker_tables, "small_blind > 0", name: "poker_tables_small_blind_positive"
    add_check_constraint :poker_tables, "big_blind >= small_blind", name: "poker_tables_blinds_valid"
    add_check_constraint :poker_tables, "buy_in >= big_blind", name: "poker_tables_buy_in_valid"
    add_check_constraint :poker_tables, "max_players > 0", name: "poker_tables_capacity_positive"

    create_table :table_seats do |t|
      t.references :poker_table, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :stack, null: false
      t.datetime :left_at

      t.timestamps
    end
    add_index :table_seats, [:poker_table_id, :user_id],
      unique: true,
      where: "left_at IS NULL",
      name: "index_active_table_seats_on_table_and_user"
    add_check_constraint :table_seats, "stack >= 0", name: "table_seats_stack_nonnegative"

    create_table :daily_challenges do |t|
      t.string :title, null: false
      t.text :prompt, null: false
      t.string :answer, null: false
      t.integer :reward_chips, null: false
      t.date :active_on, null: false

      t.timestamps
    end
    add_index :daily_challenges, :active_on, unique: true
    add_check_constraint :daily_challenges, "reward_chips > 0",
      name: "daily_challenges_reward_positive"

    create_table :challenge_completions do |t|
      t.references :daily_challenge, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :reward_chips, null: false

      t.timestamps
    end
    add_index :challenge_completions, [:daily_challenge_id, :user_id], unique: true
    add_check_constraint :challenge_completions, "reward_chips > 0",
      name: "challenge_completions_reward_positive"
  end
end
