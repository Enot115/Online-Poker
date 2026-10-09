# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_09_210000) do
  create_table "challenge_completions", force: :cascade do |t|
    t.integer "daily_challenge_id", null: false
    t.integer "user_id", null: false
    t.integer "reward_chips", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_challenge_id", "user_id"], name: "index_challenge_completions_on_daily_challenge_id_and_user_id", unique: true
    t.index ["daily_challenge_id"], name: "index_challenge_completions_on_daily_challenge_id"
    t.index ["user_id"], name: "index_challenge_completions_on_user_id"
    t.check_constraint "reward_chips > 0", name: "challenge_completions_reward_positive"
  end

  create_table "daily_challenges", force: :cascade do |t|
    t.string "title", null: false
    t.text "prompt", null: false
    t.string "answer", null: false
    t.integer "reward_chips", null: false
    t.date "active_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_on"], name: "index_daily_challenges_on_active_on", unique: true
    t.check_constraint "reward_chips > 0", name: "daily_challenges_reward_positive"
  end

  create_table "poker_tables", force: :cascade do |t|
    t.string "name", null: false
    t.integer "small_blind", null: false
    t.integer "big_blind", null: false
    t.integer "buy_in", null: false
    t.integer "max_players", default: 6, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "big_blind >= small_blind", name: "poker_tables_blinds_valid"
    t.check_constraint "buy_in >= big_blind", name: "poker_tables_buy_in_valid"
    t.check_constraint "max_players > 0", name: "poker_tables_capacity_positive"
    t.check_constraint "small_blind > 0", name: "poker_tables_small_blind_positive"
  end

  create_table "table_seats", force: :cascade do |t|
    t.integer "poker_table_id", null: false
    t.integer "user_id", null: false
    t.integer "stack", null: false
    t.datetime "left_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["poker_table_id", "user_id"], name: "index_active_table_seats_on_table_and_user", unique: true, where: "left_at IS NULL"
    t.index ["poker_table_id"], name: "index_table_seats_on_poker_table_id"
    t.index ["user_id"], name: "index_table_seats_on_user_id"
    t.check_constraint "stack >= 0", name: "table_seats_stack_nonnegative"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", limit: 60, null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "chip_balance", default: 0, null: false
    t.index "LOWER(email)", name: "index_users_on_LOWER_email", unique: true
    t.check_constraint "chip_balance >= 0", name: "users_chip_balance_nonnegative"
  end

  add_foreign_key "challenge_completions", "daily_challenges"
  add_foreign_key "challenge_completions", "users"
  add_foreign_key "table_seats", "poker_tables"
  add_foreign_key "table_seats", "users"
end
