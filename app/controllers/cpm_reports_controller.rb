class CpmReportsController < ApplicationController
  unloadable

  #before_filter :authorize_global, :only => [:show]
  before_filter :set_menu_item
  menu_item :reports, :only => :index

  # Main view for reports generation
  def index
    # Load report types
    @report_types = ['']+CPM::Reports::DEFAULT_REPORTS.map{|r| [l(:"cpm.label_#{r}"), r]}
    
    if params[:report_type].present? and CPM::Reports::DEFAULT_REPORTS.include?(params[:report_type])
      @report = {
        :type => params[:report_type],
        :selected => params[params[:report_type]]
      }

      @result = CPM::Reports.generate_report(@report)

      # If it's an export request, load export headers
      if params[:format].present?
        @format = params[:format]
        export  
      # If it isn't an export request, load selected filter options
      else
        eval("get_filter_"+@report[:type])
      end
    end
  end

  # Show user reports options data
  def get_filter_users
    @users_selected = []
    if params['users'].present?
      @users_selected = params['users']
    end

    @users_options = User.allowed.sort_by{|u| u.login}.collect{|u| [u.login, (u.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_reports/filters/users', :layout => false) }
    end
  end

  def get_filter_projects
    @projects_selected = []
    if params['projects'].present?
      @projects_selected = params['projects']
    end

    @projects_options = Project.allowed.sort_by{|p| p.name}.collect{|p| [p.name, (p.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_reports/filters/projects', :layout => false) }
    end
  end

  # Add headers to generate the file to export with the proper file extension
  def export
    headers['Content-Type'] = "text/plain" #"application/vnd.ms-excel"
    headers['Content-Disposition'] = 'attachment; filename="'+@report[:type]+'_planning_'+Date.today.strftime("%Y%m%d")+'.'+@format+'"'
    headers['Cache-Control'] = ''

    render 'cpm_reports/_report', :layout => false
  end

  private
  def set_menu_item
    self.class.menu_item params['action'].to_sym
  end
end