require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class SimpleSemanticReleaseHelper
      # class methods that you define here become available in your action
      # as `Helper::SimpleSemanticReleaseHelper.your_method`

      def self.get_version_commits(params)
        # if no tags match, display all commits
        tag_comparison = "'#{params[:tags][0]}'...'#{params[:tags][1]}'" unless params[:tags].length == 0
        UI.message "Comparing all commits between tags #{params[:tags][0]} and #{params[:tags][1]}" unless params[:tags].length == 0

        command = "git log --pretty='#{params[:format]}' #{tag_comparison}"
        commits = Actions.sh(command, log: params[:debug])

        commits.strip.split('|>')
      end

      def self.get_tags(params)
        tags = []

        command = "git tag --sort=-taggerdate --list '#{params[:match]}' | head -#{params[:limit]}"
        result = Actions.sh(command, log: params[:debug])

        result.each_line { |line| tags << line.strip unless line == '\n'}

        tags
      end

      def self.get_latest_tags(params)
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

      def self.parse_commit(params)
        # conventional commits are in format
        # type: subject (fix: app crash - for example)
        commit_line = params[:commit_line]

        parts = commit_line.split("|")
        commit_subject = parts[0].strip
        commit_body = parts[1]

        releases = { fix: "patch", feat: "minor" }
        pattern = params[:pattern]
        breaking_change_pattern = /BREAKING CHANGES?: (.*)/
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

          # UI.message "Type: #{type}"
          # UI.message "Scope: #{scope}"
          # UI.message "Exclamation mark: #{exclamation_mark}"
          # UI.message "Subject: #{subject}"

          result[:is_valid] = true
          result[:type] = type
          result[:scope] = scope
          result[:subject] = subject

          unless commit_body.nil?
            breaking_change_matched = commit_body.match(breaking_change_pattern)
            breaking_change = true unless breaking_change_matched.nil?
          end

          unless releases.nil?
            result[:release] = releases[type.to_sym]
            result[:release] = 'major' if breaking_change or exclamation_mark
          end
        end

        result
      end

      def self.semver_gt(first, second)
        first_major = (first.split('.')[0] || 0).to_i
        first_minor = (first.split('.')[1] || 0).to_i
        first_patch = (first.split('.')[2] || 0).to_i

        second_major = (second.split('.')[0] || 0).to_i
        second_minor = (second.split('.')[1] || 0).to_i
        second_patch = (second.split('.')[2] || 0).to_i

        # Check if next version is higher then last version
        if first_major > second_major
          return true
        elsif first_major == second_major
          if first_minor > second_minor
            return true
          elsif first_minor == second_minor
            if first_patch > second_patch
              return true
            end
          end
        end

        return false
      end

      def self.semver_lt(first, second)
        return !semver_gt(first, second)
      end
    end
  end
end
