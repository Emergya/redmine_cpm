require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

# Patches Redmine's Issue dynamically.  Adds relationships
# Issue +has_one+ to Incident and ImprovementAction
module CPM
  module ProjectsControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will be reloaded in development
        alias_method_chain :settings, :cpm
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def settings_with_cpm
        settings_without_cpm
        @capacities = []
      end
    end
  end
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    # use require_dependency if you plan to utilize development mode
    require_dependency 'projects_controller'
    ProjectsController.send(:include, CPM::ProjectsControllerPatch)
  end
else
  Dispatcher.to_prepare do
    require_dependency 'projects_controller'
    ProjectsController.send(:include, CPM::ProjectsControllerPatch)
  end
end
