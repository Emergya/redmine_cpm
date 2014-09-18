﻿class CpmManagementController < ApplicationController
  unloadable

  before_filter :authorize_global
  before_filter :set_menu_item

  helper :cpm_management

  # Main page for capacities search and management
  def show
    project_filters = Setting.plugin_redmine_cpm['project_filters'] || [0]
    custom_field_filters = CustomField.where("id IN (?)",project_filters.map{|e| e.to_s}).collect{|cf| [cf.name,cf.id.to_s]}
    @filters = [['','default']] + custom_field_filters + ['users','groups','projects','project_manager','time_unit','time_unit_num','ignore_black_lists'].collect{|f| [l(:"cpm.label_#{f}"),f]}
  end

  # Form for add capacities to users
  def assignments
    # load users options
    ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]
    @users_for_selection = User.where("id NOT IN (?)", ignored_users).sort_by{|u| u.login}.collect{|u| [u.login,u.id]}

    # load pojects options
    @projects_for_selection = Project.get_not_ignored_projects.sort_by{|p| p.name}.collect{|p| [p.name,p.id]}

    @cpm_user_capacity = CpmUserCapacity.new
  end

  # Capacity search result
  def planning
    if !params['ignore_blacklists'].present?
      ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]
      ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    else
      ignored_users = [0]
      ignored_projects =[0]
    end
    @users = []
    @projects = []

# getting @projects array
  # add projects specified by project filter
    if params[:projects].present?
      @projects += params[:projects]
    end

    # add projects specified by project manager filter
    if params[:project_manager].present?
      project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];
      if project_manager_role.present?
        @projects += MemberRole.find(:all, :include => :member, :conditions => ['members.user_id IN (?) AND role_id = ?', params[:project_manager].join(','), project_manager_role]).collect{|mr| mr.member.project_id}
      end
    end

    # exclude ignored projects
    @projects = @projects.uniq.reject{|p| ignored_projects.include?(p.to_s)}

# filtering @projects array by custom field filters
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
            filter = CustomValue.where("customized_type = ? AND customized_id = ? AND custom_field_id = ? AND value IN (?)","Project",p,cf,v.map{|e| e.to_s}) == []
          end
        end
        if !filter
          filtered_projects << p
        end
      end

      @projects = filtered_projects
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

    # join users
    @users = @users.uniq.sort_by{|u| u.login}

# if @users array is empty, get it based on @projects array
    # get users specified by project if there are not using filter for users or groups
    if !@projects.blank? && @users.blank?
      projects = Project.where("id IN ("+@projects.join(',')+")")

      # get users who are project members
      members = projects.collect{|p| p.members.collect{|m| m.user_id}}.flatten
      # get users who have time entries in projects
      time_entries = projects.collect{|p| p.time_entries.collect{|te| te.user_id}}.flatten

      @users = User.where("id IN (?)", (members+time_entries).uniq).reject{|u| ignored_users.include?((u.id).to_s)}.sort_by{|u| u.login}
    end

    @time_unit = params[:time_unit] || 'week'

    if params[:time_unit_num].present?
      @time_unit_num = params[:time_unit_num].to_i
    else
      @time_unit_num = 12
    end

    render layout: false
  end

  # Capacity edit form
  def edit_form
    if !params['ignore_blacklists'].present?
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
    #user.cpm_user_capacity.where('to_date >= ?', Date.today)

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
    # load users options
    ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]
    if params['show_banned'].present? and params['show_banned'] == 'true'
      ignored_users = [0]
    end

    actived_options = []
    if params['options'].present?
      actived_options = params['options'].collect{|i,o| o['value']}
    end

    @options = User.where("id NOT IN (?)", ignored_users).sort_by{|u| u.login}.collect{|u| "<option value='"+(u.id).to_s+"' "+(actived_options.include?((u.id).to_s)? "selected" : "")+">"+u.login+"</option>"}.join('')
  
    render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/users', :layout => false, :locals => { :options => @options }) }
  end

  def get_filter_groups
    # load groups options
    ignored_groups = Setting.plugin_redmine_cpm['ignored_groups'] || [0]
    if params['show_banned'].present? and params['show_banned'] == 'true'
      ignored_groups = [0]
    end

    actived_options = []
    if params['options'].present?
      actived_options = params['options'].collect{|i,o| o['value']}
    end

    @options = Group.where("id NOT IN (?)", ignored_groups).sort_by{|g| g.name}.collect{|g| "<option value='"+(g.id).to_s+"' "+(actived_options.include?((g.id).to_s)? "selected" : "")+">"+g.name+"</option>"}.join('')
    
    render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/groups', :layout => false, :locals => { :options => @options }) }
  end

  def get_filter_projects
    # load projects options
    ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    if params['show_banned'].present? and params['show_banned'] == 'true'
      ignored_projects = [0]
    end

    actived_options = []
    if params['options'].present?
      actived_options = params['options'].collect{|i,o| o['value']}
    end

    @options = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| "<option value='"+(p.id).to_s+"' "+(actived_options.include?((p.id).to_s)? "selected" : "")+">"+CGI::escapeHTML(p.name)+"</option>"}.join('')

    render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/projects', :layout => false, :locals => { :options => @options }) }
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

    @options = users.uniq.sort.collect{|u| "<option value='"+(u.id).to_s+"' >"+u.login+"</option>"}.join('')

    render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/project_managers', :layout => false, :locals => { :options => @options }) }
  end

  def get_filter_custom_field
    custom_field = CustomField.find_by_id(params[:custom_field_id])

    case custom_field.field_format
      when 'list'
        @options = custom_field.possible_values.collect{|o| "<option value='"+o+"'>"+o+"</option>"}
        size = ([10,@options.count].min).to_s
        @options = @options.join('')

        render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/custom_field_list', :layout => false, :locals => { :options => @options, :size => size, :custom_field => custom_field }) }
    end
  end

  def get_filter_time_unit
    render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/time_unit', :layout => false )}
  end

  def get_filter_time_unit_num
    render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/time_unit_num', :layout => false )}
  end

  def get_filter_ignore_black_lists
    render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/ignore_black_lists', :layout => false )}
  end

  private
  def set_menu_item
    self.class.menu_item params['action'].to_sym
  end
end
