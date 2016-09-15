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

  scope :current, -> { where("to_date >= ?", Date.today) }
  scope :allowed, -> { where("user_id NOT IN (?) AND project_id NOT IN(?)", User.not_allowed, Project.not_allowed) }

  before_save do 
    self.editor_id = User.current.id
  end

  # validates from_date starts before due_date
  def to_date_after_from_date
    if from_date.present? && to_date.present?
      errors.add(:to_date, :msg_to_date_after_from_date) if to_date < from_date
    end
  end

  # check if user's total capacity on a day is higher than 100
  def check_capacity(ignored_projects = [0])
    result = true

    user = User.find_by_id(self.user_id)
    initial_day = [Date.parse(self.from_date.to_s), DateTime.now].max
    days = (Date.parse(self.to_date.to_s) - initial_day).to_i

    (0..days).each do |i|
      date = initial_day + i.day
      if get_total_capacity(self.user_id, date, ignored_projects) > 100    
        result = false
      end
    end

    result
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

  # Get capacity relative value between start_day and end_day
  def get_relative(start_day, end_day)
    result = 0

    if self.to_date >= start_day and self.from_date <= end_day
      fd = [Date.parse(self.from_date.to_s),start_day].max
      td = [Date.parse(self.to_date.to_s),end_day].min

      if start_day != end_day
        result = (self.capacity*(td - fd + 1).to_f)/(end_day - start_day + 1).to_f
      else
        result = self.capacity.to_f
      end
    end

    result
  end

  # Show user capacity tooltip
  def get_tooltip(start_day, end_day)
    result = ""

    if self.to_date >= start_day and self.from_date <= end_day      
      editor = l(:"cpm.unknown")
      if self.editor.present?
        editor = self.editor.login
      end

      result = CGI::escapeHTML(self.project.name)+": <b>"+(self.capacity).to_s+"%</b>. "+self.from_date.strftime('%d/%m/%y')+" - "+self.to_date.strftime('%d/%m/%y')+". "+l(:"cpm.label_edited_by")+" "+editor+"<br>"
    end

    result
  end

  private
  def get_total_capacity(user_id, date, ignored_projects = [0])
    CpmUserCapacity.where("user_id = ? AND from_date <= ? AND to_date >= ? AND project_id NOT IN (?)", user_id, date, date, ignored_projects).inject(0) { |sum, e| 
      sum += e.capacity  
    }
  end
end
