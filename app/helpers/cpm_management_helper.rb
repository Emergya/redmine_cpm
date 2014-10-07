module CpmManagementHelper
	# Controls CPM tab selected
	def selected_tab_class(tab)
    'selected' if case tab
                  when 'assignments'
                    params[:controller] == 'cpm_management' and params[:action] == 'assignments'
                  when 'show'
                    params[:controller] == 'cpm_management' and params[:action] == 'show'
               end
	end

	# Get week or month name for planning columns
	def get_column_name(type,index)
		case type
			when 'day'
				get_from_date(type,index)
			when 'week'
				(get_from_date(type,index)+"<br>"+get_to_date(type,index)).html_safe
			when 'month'
				date = Date.today+index.month
				l(:"cpm.months.#{date.strftime('%B')}")+" "+date.strftime('%Y')
		end
	end

	def get_from_date(type,index)
		date = CPM::CpmDate.get_start_date(type,index)
		date.strftime('%d/%m/%y')
	end

	def get_to_date(type,index)
		date = CPM::CpmDate.get_due_date(type,index)
		date.strftime('%d/%m/%y')
	end
	
	def is_friday(type,index)
		date = CPM::CpmDate.get_start_date(type,index)
		date.wday == 5
	end

	def even_odd(row)
		if row%2==0 
			"even"
		else
			"odd"
		end 
	end
end