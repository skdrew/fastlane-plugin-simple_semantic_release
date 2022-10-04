require 'fastlane/action'
require_relative '../helper/simple_semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
      RELEASE_ANALYZED = :RELEASE_ANALYZED
      RELEASE_IS_NEXT_VERSION_HIGHER = :RELEASE_IS_NEXT_VERSION_HIGHER
      RELEASE_LAST_VERSION = :RELEASE_LAST_VERSION
      RELEASE_NEXT_VERSION = :RELEASE_NEXT_VERSION
    end

    class AnalyzeCommitsAction < Action
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
          next_major += 1
          next_minor = 0
          next_patch = 0
        elsif minor_changes > 0
          next_minor += 1
          next_patch = 0
        elsif patch_changes > 0
          next_patch += 1
        end

        "#{next_major}.#{next_minor}.#{next_patch}"
      end

      def self.parse_version_commits(commits)
        releases = { fix: "patch", feat: "minor" }
        format_pattern = /^(build|docs|fix|feat|chore|style|refactor|perf|test)(?:\((.*)\))?(!?)\: (.*)/

        commits.map do |commit_line|
          Helper::SimpleSemanticReleaseHelper.parse_commit(
            commit_line: commit_line.strip,
            releases: releases,
            pattern: format_pattern
          )
        end
      end

      def self.run(params)
        version_tags = Helper::SimpleSemanticReleaseHelper.get_current_version_tags({
          match: params[:match],
          debug: params[:debug]
        })
        version_commits = Helper::SimpleSemanticReleaseHelper.get_version_commits({
          format: '%s|%b|>',
          tags: version_tags,
          debug: params[:debug]
        })

        parsed_commits = parse_version_commits(version_commits)

        current_version_number = get_current_version_number({
          tags: version_tags,
          tag_version_match: params[:tag_version_match]
        })
        next_version_number = get_next_version_number({
          ignore_scopes: params[:ignore_scopes],
          commits: parsed_commits,
          version_number: current_version_number
        })

        next_version_releasable = Helper::SimpleSemanticReleaseHelper.semver_gt(next_version_number, current_version_number)

        success_message = "Next version (#{next_version_number}) is higher than last version (#{current_version_number}). This version should be released."

        UI.success(success_message) if next_version_releasable

        Actions.lane_context[SharedValues::RELEASE_ANALYZED] = true
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_HIGHER] = next_version_releasable
        Actions.lane_context[SharedValues::RELEASE_LAST_VERSION] = current_version_number
        Actions.lane_context[SharedValues::RELEASE_NEXT_VERSION] = next_version_number

        [next_version_number, next_version_releasable]
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Finds a tag of last release and determinates version of next release"
      end

      def self.details
        "This action will find a last release tag and analyze all commits since the tag. It uses conventional commits. Every time when commit is marked as fix or feat it will increase patch or minor number (you can setup this default behaviour). After all it will suggest if the version should be released or not."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(
            key: :match,
            description: "Match parameter of git describe. See man page of git describe for more info",
            verify_block: proc do |value|
              UI.user_error!("No match for analyze_commits action given, pass using `match: 'expr'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :tag_version_match,
            description: "To parse version number from tag name",
            default_value: '\d+\.\d+\.\d+'
          ),
          FastlaneCore::ConfigItem.new(
            key: :ignore_scopes,
            description: "To ignore certain scopes when calculating releases",
            default_value: [],
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :debug,
            description: "True if you want to log out a debug info",
            default_value: false,
            type: Boolean,
            optional: true
          )
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['RELEASE_ANALYZED', 'True if commits were analyzed.'],
          ['RELEASE_IS_NEXT_VERSION_HIGHER', 'True if next version is higher then last version'],
          ['RELEASE_NEXT_VERSION', 'Next version string in format (major.minor.patch)'],
          ['RELEASE_LAST_VERSION', 'Last version number - parsed from last tag.'],
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns true if the next version is higher then the last version"
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["xotahal", "skdrew"]
      end

      def self.is_supported?(platform)
        # you can do things like
        true
      end
    end
  end
end
