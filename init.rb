require 'cpm/user_patch'
require 'cpm/project_patch'
require 'cpm/hooks'
require 'cpm/cpm_menu_helper_patch'

Redmine::Plugin.register :redmine_cpm do
  name 'Capacity Planning Manager'
  author 'Emergya'
  description 'This plugin allows to manage and planning users capacity.'
  version '0.0.1'

  project_module :cpmplugin do
		permission :cpm_management, { :cpm_management => [:show, :assignments] }
	end

  settings :default => {}, :partial => 'settings/cpm_settings'
  menu  :top_menu, :cpm, { :controller => 'cpm_management', :action => 'show'}, 
  			:caption => 'CPM',
				:if => Proc.new { User.current.allowed_to?(:cpm_management, nil, :global => true) }

  menu :cpm_menu, :show, { :controller => 'cpm_management', :action => 'show' },
       :caption => :'cpm.label_management'
end
