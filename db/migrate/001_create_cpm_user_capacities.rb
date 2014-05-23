class CreateCpmUser
    create_table :cpm_user_capacities, :force => true do |t|
      t.column :user_id, :integer, :null => false
      t.column :project_id, :integer, :null => false
      t.column :capacity, :integer, :null => false, :default => 0
      t.column :from_date, :datetime, :null => false
      t.column :to_date, :datetime, :null => false
    end
  end

  def self.down
    drop_table :cpm_user_capacities
  end
end
