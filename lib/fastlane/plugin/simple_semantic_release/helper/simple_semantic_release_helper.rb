require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class SimpleSemanticReleaseHelper
      # class methods that you define here become available in your action
      # as `Helper::SimpleSemanticReleaseHelper.your_method`
      #
      def self.git_log(params)
        command = "git log --pretty='#{params[:pretty]}' --reverse #{params[:start]}..HEAD"
        Actions.sh(command, log: params[:debug]).chomp
      end

      def self.parse_commit(params)
        # conventional commits are in format
        # type: subject (fix: app crash - for example)
        commit_line = params[:commit_line]

        parts = commit_line.split("|")
        commit_subject = parts[0].strip
        commit_body = parts[1]

        releases = params[:releases]
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
