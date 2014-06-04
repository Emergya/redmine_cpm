module CPM
  class Hooks < Redmine::Hook::ViewListener
    def view_welcome_index_right(context={ })
      content = User.current.get_capacity_summary

      if content.blank?
      	content = "No tiene establecida ninguna dedicacion para hoy."
      else
      	content = "<h3>Dedicacion para hoy</h3>".html_safe+content
      end

 
      return content_tag(:div, content, :class  => 'box')
    end
  end
end

