class AddReadingSpeedWpmToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :reading_speed_wpm, :integer, null: false, default: 200
  end
end
