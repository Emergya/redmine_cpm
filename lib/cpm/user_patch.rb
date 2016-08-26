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
      def not_allowed(ignore_blacklist = false)
        if ignore_blacklist
          [0]
        else
          if Setting.plugin_redmine_cpm['ignore_unselected_users']
            User.all.map(&:id) - Setting.plugin_redmine_cpm['ignored_users'].map(&:to_i) || [0]
          else
            Setting.plugin_redmine_cpm['ignored_users'] || [0]
          end
        end
      end

      def allowed(ignore_blacklist = false, user_list = [])
        if user_list.present?
          active.where("users.id IN (?) AND users.id NOT IN (?)", user_list, not_allowed(ignore_blacklist))
        else
          active.where("users.id NOT IN (?)", not_allowed(ignore_blacklist))
        end
      end

      # Get users who has the specified role in almost any project
      def get_by_role(role_id)
        allowed = Project.allowed.collect{|p| p.id}
        
        User.joins(:members, {:members => :member_roles}).where("members.project_id NOT IN ("+Project.not_allowed.join(',')+") AND member_roles.role_id = ? AND users.id NOT IN ("+not_allowed.join(',')+")", role_id).uniq
      end
    end

    module InstanceMethods
      # Get all capacities from start_date to due_date and which belong to a project (optional)
      def get_range_capacities(start_date,due_date,projects_id=nil)
        if projects_id.present?
          query = "from_date <= ? AND to_date >= ? AND project_id IN ("+projects_id.join(',')+")"
        else
          query = "from_date <= ? AND to_date >= ? AND project_id NOT IN ("+Project.not_allowed.join(',')+")"
        end

        self.cpm_capacities.where(query, due_date+1, start_date)
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

      # Show knowledges tooltip
      def show_tooltip_knowledges
        info = "<ul>"

        user_knowledges.sort_by{|k| k.name}.each do |knowledge|
          info += "<li>"
          info += "<b>" if knowledge.knowledge.main.present?
          info += knowledge.name+" - "+knowledge.level_name
          info += "</b>" if knowledge.knowledge.main.present?
          info += "</li>"
        end

        info += "</ul>"

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
