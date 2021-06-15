# frozen_string_literal: true

require "decidim/core"
require "csv"

namespace :decidim do
  Rails.logger = Logger.new(STDOUT)

  namespace :capco_data do
    namespace :proposals do
      desc "Import proposals from CSV"
      task import: :environment do |task|
        # USAGE : bundle exec rake decidim:capco_data:proposals:import <organisation_host> <process_slug> <component_id> <file_path>
        ARGV.each { |a| task a.to_sym do ; end }
        @ROOT = task.application.original_dir
        @TYPES = {}

        if Decidim::Organization.exists?(:host => ARGV[1])
          @organization = Decidim::Organization.find_by(:host => ARGV[1])
        else
          Rails.logger.error "Could not find any organization with host \"#{ARGV[1]}\""
          exit 1
        end

        if Decidim::ParticipatoryProcess.exists?(:slug => ARGV[2], :decidim_organization_id => @organization.id)
          @space = Decidim::ParticipatoryProcess.find_by(:slug => ARGV[2], :decidim_organization_id => @organization.id)
        else
          Rails.logger.error "Could not find an space with slug \"#{ARGV[2]}\""
          exit 1
        end

        if Decidim::Component.exists?(:id => ARGV[3], :participatory_space_id => @space.id)
          @component = Decidim::Component.find(ARGV[3])
        else
          Rails.logger.error "Could not find a component with id \"#{ARGV[3]}\" in space \"#{ARGV[2]}\""
          exit 1
        end

        if check_file(ARGV[4], :csv)
          @csv = CSV.read(path_for(ARGV[4]), col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true)
        else
          Rails.logger.error "Could not load CSV file \"#{ARGV[4]}\""
          exit 1
        end

        import_proposals

        Rails.logger.close
        exit
      end
    end

    namespace :projects do
      desc "Import budget projects from CSV"
      task import: :environment do |task|
        # USAGE : bundle exec rake decidim:capco_data:projects:import <organisation_host> <process_slug> <budget_component_id> <proposal_component_id> <file_path>
        ARGV.each { |a| task a.to_sym do ; end }
        @ROOT = task.application.original_dir
        @TYPES = {}

        if Decidim::Organization.exists?(:host => ARGV[1])
          @organization = Decidim::Organization.find_by(:host => ARGV[1])
        else
          Rails.logger.error "Could not find any organization with host \"#{ARGV[1]}\""
          exit 1
        end

        if Decidim::ParticipatoryProcess.exists?(:slug => ARGV[2], :decidim_organization_id => @organization.id)
          @space = Decidim::ParticipatoryProcess.find_by(:slug => ARGV[2], :decidim_organization_id => @organization.id)
        else
          Rails.logger.error "Could not find an space with slug \"#{ARGV[2]}\""
          exit 1
        end

        if Decidim::Component.exists?(:id => ARGV[3], :participatory_space_id => @space.id)
          @budget_component = Decidim::Component.find(ARGV[3])
        else
          Rails.logger.error "Could not find a component with id \"#{ARGV[3]}\" in space \"#{ARGV[2]}\""
          exit 1
        end

        if Decidim::Component.exists?(:id => ARGV[4], :participatory_space_id => @space.id)
          @proposal_component = Decidim::Component.find(ARGV[4])
        else
          Rails.logger.error "Could not find a component with id \"#{ARGV[4]}\" in space \"#{ARGV[2]}\""
          exit 1
        end

        if check_file(ARGV[5], :csv)
          @csv = CSV.read(path_for(ARGV[5]), col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true)
        else
          Rails.logger.error "Could not load CSV file \"#{ARGV[5]}\""
          exit 1
        end

        import_projects

        Rails.logger.close
        exit
      end
    end

    namespace :results do
      desc "Import results from CSV"
      task import: :environment do |task|
        # USAGE : bundle exec rake decidim:capco_data:budget:import <organisation_host> <process_slug> <accountability_component_id> <budget_component_id> <file_path>
        ARGV.each { |a| task a.to_sym do ; end }
        @ROOT = task.application.original_dir
        @TYPES = {}

        if Decidim::Organization.exists?(:host => ARGV[1])
          @organization = Decidim::Organization.find_by(:host => ARGV[1])
        else
          Rails.logger.error "Could not find any organization with host \"#{ARGV[1]}\""
          exit 1
        end

        if Decidim::ParticipatoryProcess.exists?(:slug => ARGV[2], :decidim_organization_id => @organization.id)
          @space = Decidim::ParticipatoryProcess.find_by(:slug => ARGV[2], :decidim_organization_id => @organization.id)
        else
          Rails.logger.error "Could not find an space with slug \"#{ARGV[2]}\""
          exit 1
        end

        if Decidim::Component.exists?(:id => ARGV[3], :participatory_space_id => @space.id)
          @accountability_component = Decidim::Component.find(ARGV[3])
        else
          Rails.logger.error "Could not find a component with id \"#{ARGV[3]}\" in space \"#{ARGV[2]}\""
          exit 1
        end

        if Decidim::Component.exists?(:id => ARGV[4], :participatory_space_id => @space.id)
          @budget_component = Decidim::Component.find(ARGV[4])
        else
          Rails.logger.error "Could not find a component with id \"#{ARGV[4]}\" in space \"#{ARGV[2]}\""
          exit 1
        end

        if check_file(ARGV[5], :csv)
          @csv = CSV.read(path_for(ARGV[5]), col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true)
        else
          Rails.logger.error "Could not load CSV file \"#{ARGV[5]}\""
          exit 1
        end

        import_results

        Rails.logger.close
        exit
      end
    end


  end
end


def path_for(path)
  if path.start_with?("/")
    path
  else
    @ROOT + "/" + path
  end
end

def check_file(path, ext = nil)
  check = true

  if path.blank?
    Rails.logger.error "File path is blank"
    check = false
  end

  unless File.exist?(path_for(path))
    Rails.logger.error "File does not exist or is unreachable"
    check = false
  end

  if ext.present? && File.extname(path) != ".#{ext.to_s}"
    Rails.logger.error "File extension does not match \"#{ext.to_s}\""
    check = false
  end

  return check
end

def find_or_create_author(uid)
  author = Decidim::User.where("extended_data @> ?", { source_id: uid }.to_json).first
  # uid = nil will not return records where extended_data.source_id does not exist
  # could also work with Decidim::User.where("extended_data ->> 'source_id' = ?", uid).first
  extended_data = uid.present? ? { source_id: uid } : {}
  author ||= Decidim::User.create!(
    email: "",
    name: I18n.t("decidim.anonymous_user"),
    nickname: "anon#{Decidim::User.maximum(:id).next}",
    organization: @organization,
    admin: false,
    roles: [],
    locale: @organization.default_locale,
    email_on_notification: false,
    newsletter_notifications_at: nil,
    managed: true,
    tos_agreement: true,
    accepted_tos_version: @organization.tos_version,
    extended_data: extended_data
  )
  author
end

def convert_status(status)
  case status
  when "Réalisable"
    "accepted"
  when "Non réalisable"
    "rejected"
  when "En cours d'analyse"
    "evaluating"
  else
    nil
  end
end

def convert_body(summary, description)
  body = ""
  body += summary.gsub(".", ".\n").gsub(":", ":\n") + "\n\n" if summary.present?
  body += description.gsub(".", ".\n").gsub(":", ":\n") if description.present?
  body = "Pas de description disponible" if body.blank?
  body
end

def import_proposals

  @proposals = {}
  @proposals_not_found = []
  @proposals_count = 0
  @votes_count = 0
  @comments_count = 0
  @comments_votes_count = 0
  @errors = []

  @csv.each do |row|
    Rails.logger.debug "Importing #{row[0]} ..."

    begin
      if row["proposal_publicationStatus"] == "PUBLISHED" && row["proposal_status_name"] != "Projets fusionnés"
        case row[0] # contribution_type
        when "proposal"
          Rails.logger.debug "State #{convert_status(row["proposal_status_name"])}"
          author = find_or_create_author(row["proposal_author_id"])
          category = Decidim::Category.where(participatory_space: @space).where( "name @> ?", { "#{@organization.default_locale}": row["proposal_category_name"] }.to_json ).first
          scope = Decidim::Scope.where(organization: @organization).where( "name @> ?", { "#{@organization.default_locale}": row["proposal_district_name"] }.to_json ).first
          proposal = Decidim::Proposals::Proposal.new(
            title: row["proposal_title"],
            body: convert_body(row["proposal_summary"], row["proposal_description"]),
            component: @component,
            category: category,
            scope: scope,
            state: convert_status(row["proposal_status_name"]),
            answer: { "#{@organization.default_locale}": row["proposal_officialResponse"] } ,
            answered_at: row["proposal_officialResponse"].present? ? DateTime.parse(row["proposal_publishedAt"]) : nil ,
            created_at: DateTime.parse(row["proposal_createdAt"]),
            published_at: DateTime.parse(row["proposal_publishedAt"]),
            state_published_at: row["proposal_status_name"].present? ? DateTime.parse(row["proposal_publishedAt"]) : nil
          )
          proposal.add_coauthor(author, user_group: nil)
          @proposals[row["proposal_id"]] = proposal
          proposal.save!
          @proposals_count += 1
        when "proposalVote"
          proposal = nil
          author = find_or_create_author(row["proposal_votes_author_id"])
          proposal = @proposals[row["proposal_id"]]
          if proposal.present?
            vote = proposal.votes.build(
              author: author,
              temporary: false,
              created_at: DateTime.parse(row["proposal_votes_createdAt"])
            )
            vote.save!
          else
            @proposals_not_found.push(row)
            @errors.push(row)
          end
          @votes_count += 1
        when "proposalComment"
          if row["proposal_comments_publicationStatus"] == "PUBLISHED"
            proposal = nil
            author = find_or_create_author(row["proposal_comments_author_id"])
            proposal = @proposals[row["proposal_id"]]
            if proposal.present?
              comment = Decidim::Comments::Comment.new(
                author: author,
                commentable: proposal,
                root_commentable: proposal,
                body: convert_body(nil, row["proposal_comments_body"]).truncate(1000),
                alignment: 0,
                decidim_user_group_id: nil,
                created_at: DateTime.parse(row["proposal_comments_createdAt"]),
                updated_at: DateTime.parse(row["proposal_comments_publishedAt"])
              )
              comment.save!
            else
              @proposals_not_found.push(row)
              @errors.push(row)
            end
          end
          @comments_count += 1
        end
      elsif row[0] == "proposalCommentVote"
        @comments_votes_count += 1
      end
    rescue StandardError => e
      Rails.logger.error row
      Rails.logger.error e
      @errors.push(row)
    end
  end

  Rails.logger.info "found #{@csv.count} rows"
  Rails.logger.info "proposals --> #{@proposals_count} rows"
  Rails.logger.info "votes --> #{@votes_count} rows"
  Rails.logger.info "comments --> #{@comments_count} rows"
  Rails.logger.info "comments votes --> #{@comments_votes_count} rows"
  Rails.logger.info "proposals_not_found --> #{@proposals_not_found.count} rows"
  Rails.logger.info "errors --> #{@errors.count} rows"


  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[4], ".csv")}_proposals_not_found.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @proposals_not_found.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[4], ".csv")}_errors.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @errors.each do |row|
      file << row.to_h.values
    end
  end

end

def import_projects

  @projects = {}
  @projects_not_found = []
  @projects_count = 0
  @votes_count = 0
  @comments_count = 0
  @comments_votes_count = 0
  @errors = []

  @csv.each do |row|
    Rails.logger.debug "Importing #{row[0]} ..."

    begin
      if row["proposal_publicationStatus"] == "PUBLISHED" && row["proposal_status_name"] != "Projets fusionnés"
        case row[0] # contribution_type
        when "proposal"
          author = find_or_create_author(row["proposal_author_id"])
          category = Decidim::Category.where(participatory_space: @space).where( "name @> ?", { "#{@organization.default_locale}": row["proposal_category_name"] }.to_json ).first
          scope = Decidim::Scope.where(organization: @organization).where( "name @> ?", { "#{@organization.default_locale}": row["proposal_district_name"] }.to_json ).first
          project = Decidim::Budgets::Project.new(
            title: { "#{@organization.default_locale}": row["proposal_title"] },
            description: { "#{@organization.default_locale}": convert_body(row["proposal_summary"], row["proposal_description"]) },
            component: @budget_component,
            category: category,
            scope: scope,
            budget: row["proposal_estimation"],
            created_at: DateTime.parse(row["proposal_createdAt"])
          )
          @projects[row["proposal_id"]] = project
          project.save!
          linked_proposals = Decidim::Proposals::Proposal.where(component: @proposal_component, state: "accepted", scope: scope, title: row["proposal_title"]).to_a
          project.link_resources(linked_proposals, "included_proposals")
          @projects_count += 1
        when "proposalVote"
          project = nil
          author = find_or_create_author(row["proposal_votes_author_id"])
          project = @projects[row["proposal_id"]]
          if project.present?
            order = Decidim::Budgets::Order.find_or_create_by!(user: author, component: @budget_component)
            order.projects << project
            order.checked_out_at = DateTime.parse(row["proposal_votes_createdAt"])
            order.save!
          else
            @projects_not_found.push(row)
            @errors.push(row)
          end
          @votes_count += 1
        when "proposalComment"
          if row["proposal_comments_publicationStatus"] == "PUBLISHED"
            project = nil
            author = find_or_create_author(row["proposal_comments_author_id"])
            project = @projects[row["proposal_id"]]
            if project.present?
              comment = Decidim::Comments::Comment.new(
                author: author,
                commentable: project,
                root_commentable: project,
                body: convert_body(nil, row["proposal_comments_body"]).truncate(1000),
                alignment: 0,
                decidim_user_group_id: nil,
                created_at: DateTime.parse(row["proposal_comments_createdAt"]),
                updated_at: DateTime.parse(row["proposal_comments_publishedAt"])
              )
              comment.save!
            else
              @projects_not_found.push(row)
              @errors.push(row)
            end
          end
          @comments_count += 1
        end
      elsif row[0] == "proposalCommentVote"
        @comments_votes_count += 1
      end
    rescue StandardError => e
      Rails.logger.error row
      Rails.logger.error e
      @errors.push(row)
    end
  end

  Rails.logger.info "found #{@csv.count} rows"
  Rails.logger.info "projects --> #{@projects_count} rows"
  Rails.logger.info "votes --> #{@votes_count} rows"
  Rails.logger.info "comments --> #{@comments_count} rows"
  Rails.logger.info "comments votes --> #{@comments_votes_count} rows"
  Rails.logger.info "projects_not_found --> #{@projects_not_found.count} rows"
  Rails.logger.info "errors --> #{@errors.count} rows"


  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[4], ".csv")}_projects_not_found.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @projects_not_found.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[4], ".csv")}_errors.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @errors.each do |row|
      file << row.to_h.values
    end
  end

end


def import_results

  @results = {}
  @results_not_found = []
  @results_count = 0
  @comments_count = 0
  @errors = []

  @csv.each do |row|
    Rails.logger.debug "Importing #{row[0]} ..."

    begin
      if row["proposal_publicationStatus"] == "PUBLISHED" && row["proposal_status_name"] != "Projets fusionnés"
        case row[0] # contribution_type
        when "proposal"
          author = find_or_create_author(row["proposal_author_id"])
          category = Decidim::Category.where(participatory_space: @space).where( "name @> ?", { "#{@organization.default_locale}": row["proposal_category_name"] }.to_json ).first
          scope = Decidim::Scope.where(organization: @organization).where( "name @> ?", { "#{@organization.default_locale}": row["proposal_district_name"] }.to_json ).first
          status = Decidim::Accountability::Status.where(component: @accountability_component).where( "name @> ?", { "#{@organization.default_locale}": row["proposal_status_name"] }.to_json ).first
          result = Decidim::Accountability::Result.new(
            title: { "#{@organization.default_locale}": row["proposal_title"] },
            description: { "#{@organization.default_locale}": convert_body(row["proposal_summary"], row["proposal_description"]) },
            component: @accountability_component,
            category: category,
            scope: scope,
            decidim_accountability_status_id: status.id,
            created_at: DateTime.parse(row["proposal_createdAt"])
          )
          @results[row["proposal_id"]] = result
          result.save!

          linked_projects = Decidim::Budgets::Project.where(component: @budget_component, scope: scope).where( "title @> ?", { "#{@organization.default_locale}": row["proposal_title"] }.to_json ).to_a
          result.link_resources(linked_projects, "included_projects")

          linked_proposals = []
          linked_projects.each do |p|
            linked_proposals.concat(p.linked_resources(:proposals, "included_proposals").to_a)
          end
          result.link_resources(linked_proposals, "included_proposals")

          @results_count += 1
        when "proposalComment"
          if row["proposal_comments_publicationStatus"] == "PUBLISHED"
            result = nil
            author = find_or_create_author(row["proposal_comments_author_id"])
            result = @results[row["proposal_id"]]
            if result.present?
              comment = Decidim::Comments::Comment.new(
                author: author,
                commentable: result,
                root_commentable: result,
                body: convert_body(nil, row["proposal_comments_body"]).truncate(1000),
                alignment: 0,
                decidim_user_group_id: nil,
                created_at: DateTime.parse(row["proposal_comments_createdAt"]),
                updated_at: DateTime.parse(row["proposal_comments_publishedAt"])
              )
              comment.save!
            else
              @results_not_found.push(row)
              @errors.push(row)
            end
          end
          @comments_count += 1
        end
      end
    rescue StandardError => e
      Rails.logger.error row
      Rails.logger.error e
      @errors.push(row)
    end
  end

  Rails.logger.info "found #{@csv.count} rows"
  Rails.logger.info "results --> #{@results_count} rows"
  Rails.logger.info "comments --> #{@comments_count} rows"
  Rails.logger.info "results_not_found --> #{@results_not_found.count} rows"
  Rails.logger.info "errors --> #{@errors.count} rows"


  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[4], ".csv")}_results_not_found.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @results_not_found.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[4], ".csv")}_errors.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @errors.each do |row|
      file << row.to_h.values
    end
  end

end
