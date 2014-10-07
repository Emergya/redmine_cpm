class CpmUserCapacity < ActiveRecord::Base
	belongs_to :user
  belongs_to :project
  belongs_to :editor, :class_name => "User", :foreign_key => "editor_id"

  unloadable
  validates :capacity, :presence => true, numericality: { only_integer: true }, :inclusion => {:in => (0..100).step(5), :message => " tiene que ser multiplo de 5 comprendido entre 0 y 100."}
  validates :from_date,	:presence => true, 
  						:format => {:with => /^\d{4}-\d{2}-\d{2}/, :message => " tiene que ser una fecha válida" }
  validates :to_date, 	:presence => true, 
  						:format => {:with => /^\d{4}-\d{2}-\d{2}/, :message => " tiene que ser una fecha válida" }
  validate :to_date_after_from_date

  before_save do 
    self.editor_id = User.current.id
  end

  def to_date_after_from_date
    if from_date.present? && to_date.present?
      errors.add(:to_date, :msg_to_date_after_from_date) if to_date < from_date
    end
  end

  # send a notice if user's total capacity on a day is higher than 100
  def check_capacity
    result = true

    user = User.find_by_id(self.user_id)
    days = (Date.parse(self.to_date.to_s) - Date.parse(self.from_date.to_s)).to_i

    (0..days).each do |i|
      date = self.from_date + i.day

      if get_total_capacity(self.user_id, date) > 100    
        result = false
      end
    end

    result
  end

  def get_total_capacity(user_id, date)
    CpmUserCapacity.where("user_id = ? AND from_date <= ? AND to_date >= ?", user_id, date, date).inject(0) { |sum, e| 
      sum += e.capacity  
    }
  end

  def get_error_message
    error_msg = ""
    
    # get errors list
    self.errors.full_messages.each do |msg|
      if error_msg != ""
        error_msg << "<br>"
      end
      error_msg << msg
    end

    error_msg
  end

  # Array of filter names
  def self.get_filter_names
    project_filters = Setting.plugin_redmine_cpm['project_filters'] || [0]
    custom_field_filters = CustomField.where("id IN (?)",project_filters.map{|e| e.to_s}).collect{|cf| [cf.name,cf.id.to_s]}
    [['','default']] + custom_field_filters + ['users','groups','projects','project_manager','time_unit','time_unit_num','ignore_black_lists'].collect{|f| [l(:"cpm.label_#{f}"),f]}
  end

end
