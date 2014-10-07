module CPM
  class CpmDate
    unloadable

    def self.get_start_date(time_unit,index)
      case time_unit
        when 'day'
          weekends = 0
          (0..index).each do |i|
            weekday = (Date.today + i.day + weekends.day).wday

            while is_weekend(weekday)
              weekends += 1
              weekday = (Date.today + i.day + weekends.day).wday
            end
          end

          start_date = Date.today + weekends.day + index.day
        when 'week'
          date = Date.today + index.week
          start_date = date.beginning_of_week
        when 'month'
          date = Date.today + index.month
          start_date = date.beginning_of_month
      end
    end

    def self.get_due_date(time_unit,index)
      case time_unit
        when 'day'
          get_start_date(time_unit,index)
        when 'week'
          date = Date.today + index.week
          due_date = date.end_of_week-2
        when 'month'
          date = Date.today + index.month
          due_date = date.end_of_month
      end
    end

    def self.is_weekend(day)
      result = (day.to_i == 6 || day.to_i == 0)
    end
  end
end
