class AddLastTestToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :last_test, :datetime
  end
end
