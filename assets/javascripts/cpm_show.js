class CpmManagementController < ApplicationController
  unloadable

  before_filter :authorize_global
  before_filter :set_menu_item

  helper :cpm_management

  # Main page for capacities search and management
  def show
    project_filters = Setting.plugin_redmine_cpm['project_filters'] || [0]
    custom_field_filters = CustomField.where("id IN (?)",project_filters.map{|e| e.to_s}).collect{|cf| [cf.name,cf.id.to_s]}
    @filters = [['','default']] + custom_field_filters + ['users','groups','projects','project_manager','time_unit','time_unit_num'].collect{|f| [l(:"cpm.label_#{f}"),f]}
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
    @users = []
    @projects = []

    # add projects specified by project filter
    if params[:projects].present?
      @projects += params[:projects]
    end

    if params[:project_manager].present?
      @projects += MemberRole.find(:all, :include => :member, :conditions => ['members.user_id IN (?) AND role_id = ?', params[:project_manager].join(','), 3]).collect{|mr| mr.member.project_id}
    end

    @projects = @projects.uniq

    # filter projects if custom field filters are specified
    if params[:custom_field].present?
      filtered_projects = []

      # if there are no projects specified and there are field filters specified, get all not ignored projects by default
      if @projects.empty?
        @projects = Project.get_not_ignored_projects.sort_by{|p| p.name}.collect{|p| p.id}
      end
      
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

    # add users specified by users filter
    if params[:users].present?
      @users += User.where("id IN (?)", params[:users])
    end

    # add users specified by groups filter
    if params[:groups].present?
      @users += Group.where("id IN (?)", params[:groups]).collect{|g| g.users}.flatten
    end

    # join users
    @users = @users.uniq.sort_by{|u| u.login}

    # get users specified by project if there are not using filter for users or groups
    if !@projects.blank? && @users.blank?
      projects = Project.where("id IN ("+@projects.join(',')+")")

      members = projects.collect{|p| p.members.collect{|m| m.user_id}}.flatten
      time_entries = projects.collect{|p| p.time_entries.collect{|te| te.user_id}}.flatten

      @users = User.where("id IN (?)", (members+time_entries).uniq).sort_by{|u| u.login}
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
    user = User.find_by_id(params[:user_id])
    projects = params[:projects]
    
    @from_date = Date.strptime(params[:from_date], "%d/%m/%y")
    @to_date = Date.strptime(params[:to_date], "%d/%m/%y")

    # load pojects options
    @projects_for_selection = Project.get_not_ignored_projects.sort_by{|p| p.name}.collect{|p| [p.name,p.id]}
    
    if projects.present?
      @default_project = projects[0]
    else
      @default_project = nil
    end

    @capacities = user.get_range_capacities(@from_date,@to_date,projects)
    #user.cpm_user_capacity.where('to_date >= ?', Date.today)

    @cpm_user_capacity = CpmUserCapacity.new
    @cpm_user_capacity.user_id = params[:user_id]

    render layout: false
  end

# Search filters
  def get_filter_users
    # load users options
    ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]
    options = User.where("id NOT IN (?)", ignored_users).sort_by{|u| u.login}.collect{|u| "<option value='"+(u.id).to_s+"'>"+u.login+"</option>"}

    render text: "<span class='filter_name'>"+l(:"cpm.label_users")+"</span> <select name='users[]' class='filter_users' size=10 multiple>"+options.join('')+"</select>"
  end

  def get_filter_groups
    # load users options
    ignored_groups = Setting.plugin_redmine_cpm['ignored_groups'] || [0]
    options = Group.where("id NOT IN (?)", ignored_groups).sort_by{|g| g.name}.collect{|g| "<option value='"+(g.id).to_s+"'>"+g.name+"</option>"}

    render text: "<span class='filter_name'>"+l(:"cpm.label_groups")+"</span> <select name='groups[]' class='filter_groups' size=10 multiple>"+options.join('')+"</select>"
  end

  def get_filter_projects
    # load projects options
    options = Project.get_not_ignored_projects.sort_by{|p| p.name}.collect{|p| "<option value='"+(p.id).to_s+"'>"+CGI::escapeHTML(p.name)+"</option>"}

    render text: "<span class='filter_name'>"+l(:"cpm.label_projects")+"</span> <select name='projects[]' class='filter_projects' size=10 multiple>"+options.join('')+"</select>"
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

    options = users.uniq.sort.collect{|u| "<option value='"+(u.id).to_s+"'>"+u.login+"</option>"}

    render text: "<span class='filter_name'>"+l(:"cpm.label_project_manager")+"</span> <select name='project_manager[]' class='filter_projects' size=10 multiple>"+options.join('')+"</select>"
  end

  def get_filter_custom_field
    custom_field = CustomField.find_by_id(params[:custom_field_id])

    case custom_field.field_format
      when 'list'
        options = custom_field.possible_values.collect{|o| "<option value='"+o+"'>"+o+"</option>"}
        size = [10,options.count].min
        render text: "<span class='filter_name'>"+custom_field.name+"</span> <select name='custom_field["+params[:custom_field_id].to_s+"][]' class='filter_"+custom_field.id.to_s+"' size="+size.to_s+" multiple>"+options.join('')+"</select>"
    end
  end

  def get_filter_time_unit
    options = "<option value='day'>"+l(:"cpm.label_day")+"</option><option value='week'>"+l(:"cpm.label_week")+"</option><option value='month'>"+l(:"cpm.label_month")+"</option>"

    render text: "<span class='filter_name'>"+l(:"cpm.label_time_unit")+"</span> <select name='time_unit' class='filter_time_unit'>"+options+"</select>";
  end

  def get_filter_time_unit_num
    render text: "<span class='filter_name'>"+l(:"cpm.label_time_unit_num")+"</span> <input name='time_unit_num' type='text' value='12' class='filter_time_unit_num' />"
  end

  private
  def set_menu_item
    self.class.menu_item params['action'].to_sym
  end
end
