# frozen_string_literal: true

require "decidim/core"
require "csv"

# USAGE : bundle exec rake decidim:capco_users:import my.organizaton.host.com admin@example.org ~/path/to/users.csv
# SEND INVITATION :
# Decidim::User.where.not(invitation_token: nil).where(invitation_sent_at: nil).each do |u|
#   u.deliver_invitation
# end
#


namespace :decidim do
  Rails.logger = Logger.new(STDOUT)

  namespace :capco_users do
    desc "Import users from CSV"
    task import: :environment do |task|
      ARGV.each { |a| task a.to_sym do ; end }
      @ROOT = task.application.original_dir
      @TYPES = {}

      if Decidim::Organization.exists?(:host => ARGV[1])
        @organization = Decidim::Organization.find_by(:host => ARGV[1])
      else
        Rails.logger.error "Could not find any organization with host \"#{ARGV[1]}\""
        exit 1
      end

      if Decidim::User.exists?(:email => ARGV[2], :admin => true, :decidim_organization_id => @organization.id)
        @invited_by = Decidim::User.find_by(:email => ARGV[2], :admin => true)
      else
        Rails.logger.error "Could not find an administrator with email \"#{ARGV[2]}\""
        exit 1
      end

      import_users

      Rails.logger.close
      exit
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

def suspicious_date(row)
  if row["confirmedAccountAt"].present? && row["lastLogin"].present?
    return row["confirmedAccountAt"][0..-3] == row["lastLogin"][0..-3]
  else
    return true
  end
end

def calculate_activity(row)
  activity_count = 0
  activity_count += Integer(row["contributionsCount"])
  activity_count += Integer(row["opinionsCount"])
  activity_count += Integer(row["opinionVotesCount"])
  activity_count += Integer(row["opinionVersionsCount"])
  activity_count += Integer(row["arguments.totalCount"])
  activity_count += Integer(row["argumentVotesCount"])
  activity_count += Integer(row["proposalsCount"])
  activity_count += Integer(row["proposalVotesCount"])
  activity_count += Integer(row["commentVotesCount"])
  activity_count += Integer(row["sourcesCount"])
  activity_count += Integer(row["repliesCount"])
  activity_count += Integer(row["commentsCount"])
  activity_count += Integer(row["projectsCount"])
  activity_count
end

def import_users

  if check_file(ARGV[3], :csv)
    @csv = CSV.read(path_for(ARGV[3]), col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true)
  else
    Rails.logger.error "Could not load CSV file \"#{ARGV[3]}\""
    exit 1
  end

  @validated = []
  @deleted = []
  @facebook_only = []
  @suspicious_email = []
  @suspicious = []
  @no_activity = []

  @csv.each do |row|

    if row["email"].blank? || !ValidEmail2::Address.new(row["email"]).valid? || row["emailConfirmed"] == "No"
      if row["email"].blank? && row["facebookId"].present? && calculate_activity(row) > 0
        @facebook_only.push(row)
      elsif calculate_activity(row) > 0
        @deleted.push(row)
      else
        @suspicious_email.push(row)
      end
    elsif suspicious_date(row) && (row["websiteUrl"].present? || row["biography"].present?) && calculate_activity(row) == 0
      @suspicious.push(row)
    elsif calculate_activity(row) == 0
      @no_activity.push(row)
    else
      @validated.push(row)
    end

  end

  Rails.logger.info "found #{@csv.count} rows"
  Rails.logger.info "validated --> #{@validated.count} rows"
  Rails.logger.info "deleted with activity --> #{@deleted.count} rows"
  Rails.logger.info "facebook only --> #{@facebook_only.count} rows"
  Rails.logger.info "without proper email --> #{@suspicious_email.count} rows"
  Rails.logger.info "suspicious --> #{@suspicious.count} rows"
  Rails.logger.info "without activity #{@no_activity.count} rows"


  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[3], ".csv")}_validated.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @validated.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[3], ".csv")}_deleted.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @deleted.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[3], ".csv")}_facebook_only.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @facebook_only.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[3], ".csv")}_suspicious_email.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @suspicious_email.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[3], ".csv")}_suspicious.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @suspicious.each do |row|
      file << row.to_h.values
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[3], ".csv")}_no_activity.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @no_activity.each do |row|
      file << row.to_h.values
    end
  end


  # unless Decidim::User.exists?(:email => @validated.first["email"].downcase, :decidim_organization_id => @organization.id)
  #   new_user = Decidim::User.new(
  #     email: @validated.first["email"].downcase,
  #     name: @validated.first["username"],
  #     nickname: @validated.first["url"].split("/")&.last.downcase,
  #     organization: @organization,
  #     admin: false,
  #     roles: [],
  #     locale: "fr",
  #     email_on_notification: false,
  #     newsletter_notifications_at: nil,
  #     extended_data: { "source_id": @validated.first[0] }
  #   )
  #   new_user.invite!(@invited_by)
  # end

  @errors = []

  @validated.each do |row|
    unless Decidim::User.exists?(:email => row["email"].downcase, :decidim_organization_id => @organization.id)
      begin
        new_user = Decidim::User.new(
          email: row["email"].downcase,
          name: row["username"],
          nickname: Decidim::User.exists?(:nickname => row["url"]&.split("/")&.last&.downcase&.truncate(20, omission: ''), :decidim_organization_id => @organization.id) ? "" : row["url"]&.split("/")&.last&.downcase&.truncate(20, omission: ''),
          organization: @organization,
          admin: false,
          roles: [],
          locale: "fr",
          email_on_notification: false,
          newsletter_notifications_at: nil,
          extended_data: { "source_id": row[0] }
        )
        new_user.invite!(@invited_by) do |u|
          u.skip_invitation = true
        end
      rescue ActiveRecord::RecordNotUnique
        @errors.push(row)
        next
      end
    end
  end

  CSV.open(@ROOT + "/tmp/#{File.basename(ARGV[3], ".csv")}_errors.csv", mode = "w+", col_sep: ';', headers: true, skip_blanks: true, liberal_parsing: true) do |file|
    file << @csv.headers
    @errors.each do |row|
      file << row.to_h.values
    end
  end

end
