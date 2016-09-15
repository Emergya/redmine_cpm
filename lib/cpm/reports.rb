module CPM
  class Reports
    unloadable
	DEFAULT_REPORTS = ['users','projects']

    def self.generate_report(data)
      case data[:type]
      when 'projects'
        generate_report_projects(data[:selected])
      when 'users'
        generate_report_users(data[:selected])
      else
        {}
      end
    end

    def self.generate_report_users(selected_users)
      result = {
        :headers => [:project, :capacity, :from_date, :to_date],
        :data => {}
      }

      users = selected_users.present? ? 
        User.find(selected_users).sort_by(&:login) : 
        User.allowed.sort_by(&:login)

      users.each do |user|
        user_capacities = user.cpm_capacities.current.allowed.map{|c| c.attributes.slice("project_id", "capacity", "from_date", "to_date")}.group_by{|c| Project.find(c["project_id"]).name}
        result[:data][user.login] = user_capacities.present? ? user_capacities : {}
      end

      result
    end

    def self.generate_report_projects(selected_projects)
      result = {
        :headers => [:user, :capacity, :from_date, :to_date],
        :data => {}
      }

      projects = selected_projects.present? ? 
        Project.find(selected_projects).sort_by(&:name) : 
        Project.allowed.sort_by(&:name)

      projects.each do |project|
        project_capacities = project.capacities.current.allowed.map{|c| c.attributes.slice("user_id", "capacity", "from_date", "to_date")}.group_by{|c| User.find(c["user_id"]).login}
        result[:data][project.name] = project_capacities.present? ? project_capacities : {}   
      end

      result
    end
	end
end
