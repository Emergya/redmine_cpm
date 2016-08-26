require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

module CPM
  unloadable
  module ProjectPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will be reloaded in development

        has_many :capacities, :class_name => 'CpmUserCapacity', :dependent => :destroy
      end
    end

    module ClassMethods
      def not_allowed(ignore_blacklist = false)
        if ignore_blacklist
          [0]
        else
          if Setting.plugin_redmine_cpm['ignore_unselected_projects']
            Project.active.map(&:id) - Setting.plugin_redmine_cpm['ignored_projects'].map(&:to_i) || [0]
          else
            Setting.plugin_redmine_cpm['ignored_projects'] || [0]
          end
        end
      end

      def allowed(ignore_blacklist = false, project_list = [])
        if project_list.present?
          active.where("id IN (?) AND id NOT IN (?)", project_list, not_allowed(ignore_blacklist))
        else
          active.where("id NOT IN (?)", not_allowed(ignore_blacklist))
        end
      end
    end

    module InstanceMethods
    end
  end
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    require_dependency 'project'
    Project.send(:include, CPM::ProjectPatch)
  end
else
  Dispatcher.to_prepare do
    require_dependency 'project'
    Project.send(:include, CPM::ProjectPatch)
  end
end
