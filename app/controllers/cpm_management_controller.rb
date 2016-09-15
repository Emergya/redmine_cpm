class CpmManagementController < ApplicationController
  unloadable

  before_filter :authorize_global, :only => [:show]
  before_filter :set_menu_item
  before_filter :oauth_authentication, :only => :show, :unless => :oauth_token?

  def oauth_token?
    !Setting.plugin_redmine_cpm[:google_calendar].present? or session[:oauth_token].present?
  end

  # Main page for capacities search and management
  def show
    # get all filter names
    @filters = CPM::Filters.get_names

    # get all filters activated by params
    @active_filters, @active_custom_field_filters = CPM::Filters.get_actives(params)

    # for each activated filter, load it
    @active_filters.each do |active_filter|
      eval("get_filter_"+active_filter)
    end

    @active_custom_field_filters.each do |active_custom_field_filter|
      get_filter_custom_field(active_custom_field_filter)
    end

    # process planning table
    if params[:commit].present?
      planning
    end
  end

  # Capacity search result
  def planning
    # getting @projects array
    @projects = CPM::Filters.get_projects(params)
    # getting @users array
    @users = @projects.present? ? CPM::Filters.get_users(params, @projects) : []

    # set time_unit and time_unit_num default values
    @time_unit = params[:time_unit] || 'week'
    @time_unit_num = (params[:time_unit_num] || 12).to_i

    # if google calendar integration is activated, get google calendar info
    if Setting.plugin_redmine_cpm[:google_calendar].present?
      @calendar = CPM::Calendar.get_calendar
    end

    # if google calendar integration is activated, create new capacities for each entry
    if @calendar.present?
      absence_project_id = Setting.plugin_redmine_cpm['absence_project']
      if absence_project_id.present?
        holidays = {}
        @users.each do |user|
          holidays[user.id] = []
          if @calendar[user.login].present?
            @calendar[user.login].each do |cpm|
              holidays[user.id] << CpmUserCapacity.new(user_id: user.id, project_id: absence_project_id, capacity: 100, from_date: cpm[0].to_datetime, to_date: cpm[1].to_datetime)
            end
          end
        end
      end
    end

    # create object for result table info
    @capacities = {}
    all_start_day = CPM::CpmDate.get_start_date(@time_unit, 0)
    all_end_day = CPM::CpmDate.get_due_date(@time_unit, @time_unit_num)
    @users.each do |user|
      @capacities[user.id] = @time_unit_num.times.collect{|i| {'value' => 0.0, 'tooltip' => ""}}
      # get all user capacities
      capacities = CpmUserCapacity.where('user_id = ? AND project_id IN(?) AND from_date <= ? AND to_date >= ?',user.id, @projects.map{|p| p.id.to_s}, all_end_day, all_start_day)
      capacities += holidays[user.id] if holidays.present?

      capacities.each do |capacity|
        # for each user capacity, update respective table cell
        @time_unit_num.times do |i|
          start_day = CPM::CpmDate.get_start_date(@time_unit,i)
          end_day = CPM::CpmDate.get_due_date(@time_unit,i)
          @capacities[user.id][i]['value'] += capacity.get_relative(start_day, end_day)
          @capacities[user.id][i]['tooltip'] += capacity.get_tooltip(start_day, end_day)
        end
      end
    end

    # passing projects as parameter to edit capacity panel
    @projects_params = @projects.map(&:id)
    
    # if request is called from AJAX, update only 'planning' partial
    if request.xhr?
      render "cpm_management/_planning" ,layout: false
    end
  end

  # Capacity edit form
  def edit_form
    user = User.find_by_id(params[:user_id])

    # get all available projects
    all_projects = Project.allowed(params['ignore_black_lists'].present?).sort_by{|p| p.name}

    if params[:projects].present?
      projects = params[:projects]
    else
      projects = all_projects.collect{|p| p.id}
    end
    
    @from_date = Date.strptime(params[:from_date], "%d/%m/%y")
    @to_date = Date.strptime(params[:to_date], "%d/%m/%y")

    # load pojects options
    @projects_for_selection = all_projects.collect{|p| [p.name,p.id]}
    
    if projects.present?
      @default_project = projects[0]
    else
      @default_project = nil
    end

    @capacities = user.get_range_capacities(@from_date,@to_date,projects)

    # show warning notice if user capacity is over 100
    @capacities.each do |c|
      if !c.check_capacity(Project.not_allowed(params['ignore_black_lists'].present?))
        flash[:warning] = l(:"cpm.msg_capacity_higher_than_100")
      end
    end

    @cpm_user_capacity = CpmUserCapacity.new
    @cpm_user_capacity.user_id = params[:user_id]

    render layout: false
  end

# Search filters
  def get_filter_users
    @users_selected = []
    if params['users'].present?
      @users_selected = params['users']
    end

    @users_options = User.allowed(params['show_all_users']).sort_by{|u| u.login}.collect{|u| [u.login, (u.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/users', :layout => false, :locals => { :options => @users_options }) }
    end
  end

  def get_filter_groups
    @groups_selected = []
    if params['groups'].present?
      @groups_selected = params['groups']
    end

    @groups_options = Group.allowed(params['show_all_groups']).sort_by{|g| g.name}.collect{|g| [g.name, (g.id).to_s]}
    
    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/groups', :layout => false, :locals => { :options => @groups_options }) }
    end
  end

  def get_filter_projects
    @projects_selected = []
    if params['projects'].present?
      @projects_selected = params['projects']
    end

    @projects_options = Project.allowed(params['show_all_projects']).sort_by{|p| p.name}.collect{|p| [p.name, (p.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/projects', :layout => false, :locals => { :options => @projects_options }) }
    end
  end

  def get_filter_project_manager
    project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];

    users = User.get_by_role(project_manager_role)

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

  def get_filter_knowledges
    @knowledges_selected = []
    if params['knowledges'].present?
      @knowledges_selected = params['knowledges']
    end

    if params['show_all_knowledges'].present?
      @knowledges_options = Knowledge.name_options
    else
      @knowledges_options = Knowledge.main_options
    end

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/knowledges', :layout => false, :locals => { :options => @knowledges_options }) }
    end
  end
  

# Google Calendar
  def oauth_authentication
    session[:params] = params
    redirect_to oauth_client.auth_code.authorize_url(:redirect_uri => oauth_callback_url, :scope => scopes, :access_type => 'offline', :approval_prompt => 'force')
  end

  def oauth_callback
    token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => oauth_callback_url)
    session[:oauth_token] = (token.to_hash).to_json

    params = session[:params]

    redirect_to :action => 'show', :params => params
  end

  def oauth_token
    @token ||= OAuth2::AccessToken.from_hash(oauth_client, JSON.parse(session[:oauth_token]))

    if !@token.present? or @token.expired?
      @token = @token.refresh!
      #session[:oauth_token] = @token.to_hash.to_json

      #session.delete(:oauth_token)
    end

    @token
  end

  def oauth_client
    @client ||= OAuth2::Client.new(Setting.plugin_redmine_cpm[:client_id], Setting.plugin_redmine_cpm[:client_secret],
      :site => 'https://accounts.google.com',
      :authorize_url => '/o/oauth2/auth',
      :token_url => '/o/oauth2/token',
      :access_type => 'offline',
      :approval_prompt => 'force')
  end

  def scopes
    'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.readonly'
  end


  private
  def set_menu_item
    self.class.menu_item params['action'].to_sym
  end
end
