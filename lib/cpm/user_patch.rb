require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

module CPM
  unloadable
  module UserPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will be reloaded in development

        has_many :cpm_capacities, :class_name => 'CpmUserCapacity', :dependent => :destroy
        has_many :cpm_editions, :class_name => 'CpmUserCapacity', :foreign_key => 'editor_id'
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def get_capacity(type,i,projects=nil)
        start_day = CpmDate.get_start_date(type,i)
        end_day = CpmDate.get_due_date(type,i)

        suma = self.get_range_capacities(start_day,end_day,projects).inject(0) { |sum, e| 
          # Min and max day for capacity calculation
          iday = [Date.parse(e.from_date.to_s),start_day].max
          eday = [Date.parse(e.to_date.to_s),end_day].min
          
          # Number of incurred and max days for capacity calculation
          ndays = (eday - iday + 1).to_f
          maxdays = (end_day - start_day + 1).to_f

          sum += (e.capacity * (ndays/maxdays)).to_i
        }

        suma
      end

      # Get all capacities from start_date to due_date and which belong to a project (optional)
      def get_range_capacities(start_date,due_date,projects_id=nil)
        if projects_id.present?
          query = "from_date <= ? AND to_date >= ? AND project_id IN ("+projects_id.join(',')+")"
        else
          ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
          query = "from_date <= ? AND to_date >= ? AND project_id NOT IN ("+ignored_projects.join(',')+")"
        end

        self.cpm_capacities.where(query, due_date+1, start_date)
      end

      # Show user capacity tooltip
      def get_tooltip(type,i,projects)
        start_day = CpmDate.get_start_date(type,i)
        end_day = CpmDate.get_due_date(type,i)

        self.get_range_capacities(start_day,end_day,projects).collect{|e| 
          editor = l(:"cpm.unknown")
          if e.editor.present?
            editor = e.editor.login
          end

          CGI::escapeHTML(e.project.name)+": <b>"+(e.capacity).to_s+"%</b>. "+e.from_date.strftime('%d/%m/%y')+" - "+e.to_date.strftime('%d/%m/%y')+". "+l(:"cpm.label_edited_by")+" "+editor
        }.join("<br>")
      end

      # Show user tooltip
      def show_tooltip_info
        profile_id = Setting.plugin_redmine_cpm['cmi_profile'] || []

        info = self.name

        if profile_id.present?
          profile = self.custom_values.where("custom_field_id = ?", profile_id)
          if profile.present?
            info += " ("+profile[0].value+")"
          end
        end

        projects = self.projects

        if projects.present?
          info += "<br><br><b>"+l('label_project_plural')+":</b><ul>"
          if projects.length > 5
            4.times do |i|
              info += "<li>"+projects[i].name+"</li>"
            end
            info += "</ul>"+l('cpm.label_other_projects', :n => (projects.length-4).to_s);
          else projects.length <= 5
            (projects.length).times do |i|
              info += "<li>"+projects[i].name+"</li>"
            end
            info += "</ul>"
          end
        end

        info
      end

      # Get html capacity summary for user's welcome page
      def get_capacity_summary
        today = Date.today
        capacities = self.get_range_capacities(today,today)

        summary = ""

        if capacities.any?
          summary += "<ul>"
          capacities.each do |c|
            summary += "<li><a href='projects/"+c.project.identifier+"'>"+CGI::escapeHTML(c.project.name)+"</a> - "+(c.capacity).to_s+"%</li>"
          end
          summary += "</ul>"
        end

        summary.html_safe
      end
    end
  end
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    require_dependency 'user'
    User.send(:include, CPM::UserPatch)
  end
else
  Dispatcher.to_prepare do
    require_dependency 'user'
    User.send(:include, CPM::UserPatch)
  end
end
