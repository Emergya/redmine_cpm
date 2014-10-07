class CpmManagementController < ApplicationController
  unloadable

  before_filter :authorize_global
  before_filter :set_menu_item

  helper :cpm_management

  # Main page for capacities search and management
  def show
    # get all filter names
    @filters = CpmUserCapacity.get_filter_names
    
    # get all filters activated by params
    @active_filters = []
    @active_custom_field_filters = []
    @filters.collect{|f| f[1]}.each do |filter|
      if params[filter].present?
        @active_filters << filter
      elsif params['custom_field'].present? and params['custom_field'].include?(filter)
        @active_custom_field_filters << filter
      end
    end

    # if there are no active filters, show users filter
    if @active_filters.empty? and @active_custom_field_filters.empty?
      @active_filters << 'users'
    end

    # for each activated filter, load it
    @active_filters.each do |active_filter|
      eval("get_filter_"+active_filter)
    end

    @active_custom_field_filters.each do |active_custom_field_filter|
      get_filter_custom_field(active_custom_field_filter)
    end

    # process planning table
    planning
  end

  # Capacity search result
  def planning
    # set black list arrays to empty if 'ignore_black_lists' filter is activated
    if !params['filter_ignore_black_lists'].present?
      ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]
      ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    else
      ignored_users = [0]
      ignored_projects =[0]
    end

    # users and projects to show in planning table
    @users = []
    @projects = []

    # getting @projects array
    # add projects specified by project manager filter
    if params[:project_manager].present?
      project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];
      if project_manager_role.present?
        @projects += MemberRole.find(:all, :include => :member, :conditions => ['members.user_id IN (?) AND role_id = ?', params[:project_manager].join(','), project_manager_role]).collect{|mr| mr.member.project_id}
      end
    end

    # exclude ignored projects
    @projects = @projects.uniq.reject{|p| ignored_projects.include?(p.to_s)}

    # filter projects if custom field filters are specified
    if params[:custom_field].present?
      filtered_projects = []

      # if there are no projects specified and there are field filters specified, get all not ignored projects by default
      if @projects.empty?
        @projects = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| p.id}
      end
      
      # for each project available will check if match with all custom field filters activated
      @projects.each do |p|
        filter = false
        params[:custom_field].each do |cf,v|
          if !filter
            filter = CustomValue.where("customized_type = ? AND customized_id = ? AND custom_field_id = ? AND value IN (?)","Project",p,cf,v.map{|e| e}) == []
          end
        end
        if !filter
          filtered_projects << p
        end
      end

      @projects = filtered_projects
    end

    # add projects specified by project filter
    if params[:projects].present?
      @projects += params[:projects]
    end

    # if there are no projects specified and there are field filters specified, get all not ignored projects by default
    if @projects.empty?
      flash.now[:warning] = l(:'cpm.msg_projects_not_found')
      @projects = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| p.id}
    end

    # getting @users array
    # add users specified by users filter
    if params[:users].present?
      @users += User.where("id IN (?)", params[:users])
    end

    # add users specified by groups filter
    if params[:groups].present?
      @users += Group.where("id IN (?)", params[:groups]).collect{|g| g.users.reject{|u| ignored_users.include?((u.id).to_s)}}.flatten
    end

    # reorder and unify users
    @users = @users.uniq.sort_by{|u| u.login}

    # if there are no users selected, get them based on projects selected
    if !@projects.blank? && @users.blank?
      projects = Project.where("id IN ("+@projects.join(',')+")")

      # get users who are project members
      members = projects.collect{|p| p.members.collect{|m| m.user_id}}.flatten
      # get users who have time entries in projects
      time_entries = projects.collect{|p| p.time_entries.collect{|te| te.user_id}}.flatten

      @users = User.where("id IN (?)", (members+time_entries).uniq).reject{|u| ignored_users.include?((u.id).to_s)}.sort_by{|u| u.login}
    end

    # set time_unit and time_unit_num default values
    @time_unit = params[:time_unit] || 'week'
    @time_unit_num = (params[:time_unit_num] || 12).to_i

    if request.xhr?
      render "cpm_management/_planning" ,layout: false
    end
  end

  # Capacity edit form
  def edit_form
    # set projects black list array to empty if 'ignore_black_lists' filter is activated
    if !params['filter_ignore_black_lists'].present?
      ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    else
      ignored_projects =[0]
    end

    user = User.find_by_id(params[:user_id])
    projects = params[:projects]
    
    @from_date = Date.strptime(params[:from_date], "%d/%m/%y")
    @to_date = Date.strptime(params[:to_date], "%d/%m/%y")

    # load pojects options
    @projects_for_selection = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| [p.name,p.id]}
    
    if projects.present?
      @default_project = projects[0]
    else
      @default_project = nil
    end

    @capacities = user.get_range_capacities(@from_date,@to_date,projects)

    @capacities.each do |c|
      if !c.check_capacity
        flash[:warning] = l(:"cpm.msg_capacity_higher_than_100")
      end
    end

    @cpm_user_capacity = CpmUserCapacity.new
    @cpm_user_capacity.user_id = params[:user_id]

    render layout: false
  end

# Search filters
  def get_filter_users
    ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]

    if params['show_banned_users'].present?
      ignored_users = [0]
    end

    @users_selected = []
    if params['users'].present?
      @users_selected = params['users']
    end

    @users_options = User.where("id NOT IN(?)", ignored_users).sort_by{|u| u.login}.collect{|u| [u.login, (u.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/users', :layout => false, :locals => { :options => @users_options }) }
    end
  end

  def get_filter_groups
    ignored_groups = Setting.plugin_redmine_cpm['ignored_groups'] || [0]
    if params['show_banned_groups'].present?
      ignored_groups = [0]
    end

    @groups_selected = []
    if params['groups'].present?
      @groups_selected = params['groups']
    end

    @groups_options = Group.where("id NOT IN (?)", ignored_groups).sort_by{|g| g.name}.collect{|g| [g.name, (g.id).to_s]}
    
    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/groups', :layout => false, :locals => { :options => @groups_options }) }
    end
  end

  def get_filter_projects
    ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    if params['show_banned_projects'].present?
      ignored_projects = [0]
    end

    @projects_selected = []
    if params['projects'].present?
      @projects_selected = params['projects']
    end

    @projects_options = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| [CGI::escapeHTML(p.name), (p.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/projects', :layout => false, :locals => { :options => @projects_options }) }
    end
  end

  def get_filter_project_manager
    project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];

    role_pm = Role.find_by_id(project_manager_role)

    users = []
    Project.all.collect{|p|
      project_manager = p.users_by_role[role_pm]
      if project_manager.present?
        project_manager.each do |pm|
          users << pm
        end
      end
    }

    @project_manager_selected = []
    if params['project_manager'].present?
      @project_manager_selected = params['project_manager']
    end

    @project_manager_options = users.uniq.sort.collect{|u| [u.login, (u.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/project_manager', :layout => false, :locals => { :options => @project_manager_options }) }
    end
  end

  def get_filter_custom_field(custom_field_id=nil)
    custom_field = CustomField.find_by_id(params[:custom_field_id] || custom_field_id)

    @custom_field_options ||= {}
    @custom_field_size ||= {}
    @custom_field_name ||= {}
    @custom_field_selected ||= {}
    case custom_field.field_format
      when 'list'
        @custom_field_name[custom_field.id.to_s] = custom_field.name
        @custom_field_options[custom_field.id.to_s] = custom_field.possible_values.collect{|o| [o, o]}
        @custom_field_size[custom_field.id.to_s] = ([10,@custom_field_options[custom_field.id.to_s].count].min).to_s

        if params['custom_field'].present?
          @custom_field_selected[custom_field.id.to_s] = params['custom_field'][custom_field.id.to_s] || []
        end

        if request.xhr?
          render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/custom_field_list', :layout => false, :locals => { :id => custom_field.id }) }
        end
    end

  end

  def get_filter_time_unit
    @time_unit_options = ['day','week','month'].collect{|tu| [l(:"cpm.label_#{tu}"), tu]}
    @time_unit_selected = params['time_unit'] || 'week'

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/time_unit', :layout => false )}
    end
  end

  def get_filter_time_unit_num
    @value = params['time_unit_num'] || '12';
    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/time_unit_num', :layout => false )}
    end
  end

  def get_filter_ignore_black_lists
    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/ignore_black_lists', :layout => false )}
    end
  end

  private
  def set_menu_item
    self.class.menu_item params['action'].to_sym
  end
end
