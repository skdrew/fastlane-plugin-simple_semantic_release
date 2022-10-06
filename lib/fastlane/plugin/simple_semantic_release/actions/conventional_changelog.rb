require 'fastlane/action'
require_relative '../helper/simple_semantic_release_helper'

module Fastlane
  module Actions
    class ConventionalChangelogAction < Action
      def self.run(params)
        version = 'get_latest_tag'
        version = 'get_current_version_tags' if params[:version] == 'released'

        tags = Helper::SimpleSemanticReleaseHelper.send(version,
          match: params[:match],
          debug: params[:debug]
        )

        result = Helper::SimpleSemanticReleaseHelper.scan_current_release(
          tags: tags,
          tag_version_match: params[:tag_version_match],
          ignore_scopes: params[:ignore_scopes],
          debug: params[:debug]
        )

        note_builder(
          commits: result[:commits],
          version: result[:current_version],
          commit_url: params[:commit_url],
          display_links: params[:display_links],
          display_title: params[:display_title],
          format: params[:format],
          order: params[:order],
          sections: params[:sections],
          title: params[:title]
        )
      end

      def self.note_builder(params)
        sections = params[:sections]

        result = ""

        # Begining of release notes
        if params[:display_title] == true
          title = style_text(params[:version], params[:format], "title").to_s
          title += " - #{params[:title]}" if params[:title]
          title += " - (#{Date.today})"

          result += "#{title}\n\n"
        end

        params[:order].each do |type|
          # write section only if there is at least one commit
          next if params[:commits].none? { |commit| commit[:type] == type }

          result += style_text(sections[type.to_sym], params[:format], "heading").to_s
          result += "\n\n"

          params[:commits].each do |commit|
            next if commit[:type] != type || commit[:is_merge]

            result += "-"

            unless commit[:scope].nil?
              formatted_text = style_text("#{commit[:scope]}", params[:format], "bold").to_s
              result += " #{formatted_text}"
            end

            result += " #{commit[:subject]}"

            if params[:display_links] == true
              styled_link = build_commit_link(commit, params[:commit_url], params[:format]).to_s
              result += " (#{styled_link})"
            end

            result += "\n"
          end
          result += "\n"
        end

        if params[:commits].any? { |commit| commit[:breaking_change] == true }
          result += style_text("BREAKING CHANGES", params[:format], "heading").to_s
          result += "\n\n"

          params[:commits].each do |commit|
            next unless commit[:breaking_change]
            result += "- #{commit[:breaking_change]}" # This is the only unique part of this loop

            if params[:display_links] == true
              styled_link = build_commit_link(commit, params[:commit_url], params[:format]).to_s
              result += " (#{styled_link})"
            end

            result += "\n"
          end

          result += "\n"
        end

        # Trim any trailing newlines
        result.rstrip!
      end

      def self.style_text(text, format, style)
        # formats the text according to the style we're looking to use

        # Skips all styling
        case style
        when "title"
          if format == "markdown"
            "## [#{text}]"
          elsif format == "slack"
            "*#{text}*"
          else
            text
          end
        when "heading"
          if format == "markdown"
            "### #{text}"
          elsif format == "slack"
            "*#{text}*"
          else
            "#{text}:"
          end
        when "bold"
          if format == "markdown"
            "**#{text}**"
          elsif format == "slack"
            "*#{text}*"
          else
            text
          end
        else
          text # catchall, shouldn't be needed
        end
      end

      def self.build_commit_link(commit, commit_url, format)
        # formats the link according to the output format we need
        short_hash = commit[:short_hash]
        hash = commit[:hash]
        url = "#{commit_url}/#{hash}"

        case format
        when "slack"
          "<#{url}|#{short_hash}>"
        when "markdown"
          "[#{short_hash}](#{url})"
        else
          url
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Get commits since last version and generates release notes"
      end

      def self.details
        "Uses conventional commits. It groups commits by their types and generates release notes in markdown or slack format."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(
            key: :version,
            description: "Select commits that have been released or not",
            default_value: 'unreleased',
            optional: true,
            verify_block: proc do |value|
              UI.user_error!("Version can only be 'unreleased' or 'released', you provided '#{value}'") unless ['released', 'unreleased'].include?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :tag_version_match,
            description: "To parse version number from tag name",
            default_value: '\d+\.\d+\.\d+'
          ),
          FastlaneCore::ConfigItem.new(
            key: :match,
            description: "Match parameter of git describe. See man page of git describe for more info",
            verify_block: proc do |value|
              UI.user_error!("No match for analyze_commits action given, pass using `match: 'expr'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :format,
            description: "You can use either markdown, slack or plain",
            default_value: "markdown",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :title,
            description: "Title for release notes",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :commit_url,
            description: "Uses as a link to the commit",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :order,
            description: "You can change the order of groups in release notes",
            default_value: ["feat", "fix"],
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :sections,
            description: "Map type to section title",
            default_value: {
              feat: "Features",
              fix: "Bug fixes",
            },
            type: Hash,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_author,
            description: "Whether you want to show the author of the commit",
            default_value: false,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_title,
            description: "Whether you want to hide the title/header with the version details at the top of the changelog",
            default_value: true,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_links,
            description: "Whether you want to display the links to commit IDs",
            default_value: true,
            type: Boolean,
            optional: true
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
        []
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns generated release notes as a string"
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["xotahal"]
      end

      def self.is_supported?(platform)
        # you can do things like
        true
      end
    end
  end
end
