module CPM
  class Filters
    include Redmine::I18n

    DEFAULT_FILTERS = ['users','groups','projects','project_manager','time_unit','time_unit_num','ignore_black_lists']

    # Array of filter names
    def self.get_names
      project_filters = Setting.plugin_redmine_cpm['project_filters'] || [0]
      custom_field_filters = CustomField.where("id IN (?)",project_filters.map{|e| e.to_s}).collect{|cf| [cf.name,cf.id.to_s]}
      
      filters = [['','default']] + custom_field_filters + DEFAULT_FILTERS.collect{|f| [l(:"cpm.label_#{f}"),f]}

      if Setting.plugin_redmine_cpm['plugin_knowledge_manager'].present?
        filters << [l(:"cpm.label_knowledges"),'knowledges']
      end

      filters
    end

    # Return default active filters and custom active filters
    def self.get_actives(filters)
      available_filters = get_names
      active_filters = []
      active_custom_field_filters = []
      available_filters.collect{|f| f[1]}.each do |filter|
        if filters[filter].present?
          active_filters << filter
        elsif filters['custom_field'].present? and filters['custom_field'].include?(filter)
          active_custom_field_filters << filter
        end
      end

      # if there are no active filters, show default filters
      if active_filters.empty? and active_custom_field_filters.empty?
        if Setting.plugin_redmine_cpm['default_active_filters']
          active_filters = Setting.plugin_redmine_cpm['default_active_filters']
        else
          active_filters << 'users'
        end
      end

      [active_filters, active_custom_field_filters]
    end

    # Return projects fitlered
    def self.get_projects(filters)
      projects = []
      # add projects specified by project filter
      if filters[:projects].present?
        projects = projects(filters[:projects])
      else
        projects = Project.all.collect{|p| p.id} #.sort_by{|p| p.name}
      end

      # add projects specified by project manager filter
      if filters[:project_manager].present?
        projects = project_manager(filters[:project_manager], projects)
      end

      # filter projects if custom field filters are specified
      if filters[:custom_field].present?
        projects = custom_field(filters[:custom_field], projects)
      end

      # projects = Project.find(projects).map(&:self_and_descendants).flatten.uniq.sort_by(&:name)
      Project.allowed(filters['ignore_black_lists'].present?, projects).flatten.uniq.sort_by(&:name)
    end

    # Return users filtered
    def self.get_users(filters, projects = [])
      users = []
      # add users specified by users filter
      if filters[:users].present?
        users = users(filters[:users])
      else
        users = User.all.collect{|u| u.id}
      end

      # add users specified by groups filter
      if filters[:groups].present?
        users = groups(filters[:groups], users)
      end
      
      # knowledge filter
      if filters[:knowledges].present?
        users = knowledges(filters[:knowledges], users)
      end

      # if there are NO users filters active, get users based on projects selected
      if projects.present? and !filters[:users].present? and !filters[:groups].present? and !filters[:knowledges].present?
        # get users who are project members
        members = User.allowed(filters['ignore_black_lists'].present?).joins(:members).where("members.project_id IN (?)", projects.map(&:id))
        # get users who have time entries in projects
        time_entries = User.allowed(filters['ignore_black_lists'].present?).joins('LEFT JOIN time_entries ON time_entries.user_id = users.id').where("time_entries.project_id IN (?)", projects.map(&:id))
        # get users who have capacity registered in projects
        capacity = projects.map{|p| p.capacities.map(&:user)}.flatten

        users = (members + time_entries + capacity).uniq.map(&:id)
      end

      User.allowed(filters['ignore_black_lists'].present?, users).flatten.uniq.sort_by(&:login)
    end

    # Specific filters

    def self.projects(projects)
      if Setting.plugin_redmine_cpm['add_subprojects']
        Project.find(projects).map(&:self_and_descendants).flatten.uniq.map(&:id)
      else
        projects
      end
    end

    def self.users(users)
      users
    end

    def self.groups(groups, users) #, ignore_blacklist)
      User.joins(:groups).where("groups_users.id IN (?) AND users.id IN (?)", groups, users).map(&:id)
    end

    def self.project_manager(ids, projects)
    	project_manager_role = Setting.plugin_redmine_cpm['project_manager_role']
      if project_manager_role.present?
        projects = MemberRole.joins(:member).where('members.user_id IN ('+ids.to_a.join(',')+') AND members.project_id IN (?) AND role_id = ?', projects, project_manager_role).collect{|mr| mr.member.project_id}
      end

      projects
    end

    def self.custom_field(filters, projects)
    	filtered_projects = []
      
      # for each project available will check if match with all custom field filters activated
      projects.each do |p|
        filter = false
        filters.each do |cf,v|
          if !filter
            filter = CustomValue.where("customized_type = ? AND customized_id = ? AND custom_field_id = ? AND value IN (?)","Project",p,cf,v.map{|e| e}) == []
          end
        end
        if !filter
          filtered_projects << p
        end
      end

      filtered_projects
    end

    def self.time_unit
    end

    def self.time_unit_num
    end

    def self.knowledges(knowledges, users)
      User.with_knowledges(knowledges,users).collect{|u| u.id}
    end

	end
end