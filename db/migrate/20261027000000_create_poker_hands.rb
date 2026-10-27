class CreatePokerHands < ActiveRecord::Migration[8.0]
  def change
    create_table :poker_hands do |t|
      t.references :poker_table, null: false, foreign_key: true
      t.json :state, null: false, default: {}
      t.datetime :finished_at

      t.timestamps
    end

    add_index :poker_hands, :poker_table_id,
      unique: true,
      where: "finished_at IS NULL",
      name: "index_active_poker_hand_per_table"
  end
end