class MakeDailyChallengesHourly < ActiveRecord::Migration[8.0]
  def up
    remove_index :daily_challenges, :active_on
    add_column :daily_challenges, :hour, :integer
    add_index :daily_challenges, [:active_on, :hour], unique: true
    add_check_constraint :daily_challenges, "hour IS NULL OR (hour >= 0 AND hour < 24)",
      name: "daily_challenges_hour_valid"
  end

  def down
    remove_check_constraint :daily_challenges, name: "daily_challenges_hour_valid"
    remove_index :daily_challenges, [:active_on, :hour]
    remove_column :daily_challenges, :hour
    add_index :daily_challenges, :active_on, unique: true
  end
end