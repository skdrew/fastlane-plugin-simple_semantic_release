require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class SimpleSemanticReleaseHelper
      # class methods that you define here become available in your action
      # as `Helper::SimpleSemanticReleaseHelper.your_method`

      def self.scan_current_release(params)
        version_commits = get_version_commits(
          tags: params[:tags],
          debug: params[:debug]
        )

        current_version = get_current_version_number(
          tags: params[:tags],
          tag_version_match: params[:tag_version_match]
        )
        next_version = get_next_version_number(
          ignore_scopes: params[:ignore_scopes],
          commits: version_commits,
          version_number: current_version
        )

        {
          commits: version_commits,
          current_version: current_version,
          next_version: next_version
        }
      end

      def self.get_commits(params)
        # if no tags match, display all commits
        tag_comparison = "'#{params[:tags][0]}'...'#{params[:tags][1]}'" unless params[:tags].length == 0
        UI.message "Comparing all commits between tags #{params[:tags][0]} and #{params[:tags][1]}" unless params[:tags].length == 0

        command = "git log --pretty='%s|%b|%H|%h|%at|>' #{tag_comparison}"
        commits = Actions.sh(command, log: params[:debug])

        commits.strip.split('|>')
      end

      def self.get_version_commits(params)
        commits = get_commits(params)

        commits.map do |commit_line|
          parse_commit(commit_line)
        end
      end

      def self.get_current_version_number(params)
        tags = params[:tags]
        version_number = '0.0.0'

        if tags.length > 0
          # first tag in tags array is the latest one
          parsed_version = tags[0].match(params[:tag_version_match])

          if parsed_version.nil?
            UI.user_error!("Error while parsing version from tag #{tags[0]} by using tag_version_match - #{params[:tag_version_match]}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
          end

          version_number = parsed_version[0]
        end

        version_number
      end

      def self.get_next_version_number(params)
        next_major = (params[:version_number].split('.')[0] || 0).to_i
        next_minor = (params[:version_number].split('.')[1] || 0).to_i
        next_patch = (params[:version_number].split('.')[2] || 0).to_i

        major_changes = 0
        minor_changes = 0
        patch_changes = 0

        params[:commits].each do |commit|
          unless commit[:scope].nil?
            next if params[:ignore_scopes].include?(commit[:scope])
          end

          if commit[:release] == "major"
            major_changes += 1
          elsif commit[:release] == "minor"
            minor_changes += 1
          elsif commit[:release] == "patch"
            patch_changes += 1
          end
        end

        if major_changes > 0
          UI.message "Found at least one major change, bumping major version"

          next_major += 1
          next_minor = 0
          next_patch = 0
        elsif minor_changes > 0
          UI.message "Found at least one minor change, bumping minor version"

          next_minor += 1
          next_patch = 0
        elsif patch_changes > 0
          UI.message "Found at least one patch change, bumping patch version"

          next_patch += 1
        end

        UI.message "Found:"
        UI.message "- major changes: #{major_changes}"
        UI.message "- minor changes: #{minor_changes}"
        UI.message "- patch changes: #{patch_changes}"

        "#{next_major}.#{next_minor}.#{next_patch}"
      end

      def self.get_tags(params)
        tags = []

        command = "git tag --sort=-taggerdate --list '#{params[:match]}' | head -#{params[:limit]}"
        result = Actions.sh(command, log: params[:debug])

        result.each_line { |line| tags << line.strip unless line == '\n'}

        tags
      end

      def self.get_latest_tag(params)
        tags = get_tags({
          limit: 1,
          match: params[:match],
          debug: params[:debug]
        })

        tags.push('HEAD')
      end

      def self.get_current_version_tags(params)
        tags = get_tags({
          limit: 2,
          match: params[:match],
          debug: params[:debug]
        })

        # only one tag matches, match that tag against HEAD
        if tags.length == 1
          UI.message "Only one previous tag matches, will compare against HEAD"
          tags.push('HEAD')
        end

        tags
      end

      def self.parse_commit(commit_line)
        # conventional commits are in format
        # type: subject (fix: app crash - for example)
        pattern = /^(build|docs|fix|feat|chore|style|refactor|perf|test)(?:\((.*)\))?(!?)\: (.*)/
        breaking_change_pattern = /BREAKING CHANGES?: (.*)/
        releases = { fix: "patch", feat: "minor" }

        parts = commit_line.strip.split("|")

        commit_subject  = parts[0].strip
        commit_body     = parts[1]
        hash            = parts[2]
        short_hash      = parts[3]
        commit_date     = parts[4]

        breaking_change = false

        matched = commit_subject.match(pattern)

        result = {
          is_valid: false,
          subject: commit_subject,
          is_merge: !(commit_subject =~ /^Merge/).nil?,
          type: 'no_type'
        }

        unless matched.nil?
          type =              matched[1]
          scope =             matched[2]
          exclamation_mark =  matched[3] == '!'
          subject =           matched[4]

          result[:is_valid]         = true
          result[:breaking_change]  = false
          result[:type]             = type
          result[:scope]            = scope
          result[:subject]          = subject
          result[:hash]             = hash
          result[:short_hash]       = short_hash
          result[:commit_date]      = commit_date

          unless commit_body.nil?
            breaking_change_matched = commit_body.match(breaking_change_pattern)
            result[:breaking_change] = true unless breaking_change_matched.nil?
          end

          unless releases.nil?
            result[:release] = releases[type.to_sym]
            result[:release] = 'major' if result[:breaking_change] or exclamation_mark
          end
        end

        result
      end
    end
  end
end
