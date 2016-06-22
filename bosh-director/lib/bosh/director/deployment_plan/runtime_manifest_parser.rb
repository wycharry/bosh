module Bosh::Director
  module DeploymentPlan
    class RuntimeManifestParser
      include ValidationHelper

      def initialize(logger, deployment=nil)
        @deployment = deployment
        @logger = logger
      end

      def parse(runtime_manifest)
        parse_releases(runtime_manifest)

        parse_addons(runtime_manifest)
      end

      private

      def parse_releases(runtime_manifest)
        @release_specs = []

        if runtime_manifest['release']
          if runtime_manifest['releases']
            raise RuntimeAmbiguousReleaseSpec,
                  "Runtime manifest contains both 'release' and 'releases' " +
                      'sections, please use one of the two.'
          end
          @release_specs << runtime_manifest['release']
        else
          safe_property(runtime_manifest, 'releases', :class => Array).each do |release|
            @release_specs << release
          end
        end

        @release_specs.each do |release_spec|
          if release_spec['version'] =~ /(^|[\._])latest$/
            raise RuntimeInvalidReleaseVersion,
                  "Runtime manifest contains the release '#{release_spec['name']}' with version as '#{release_spec['version']}'. " +
                      "Please specify the actual version string."
          end

          if @deployment
            deployment_release = @deployment.release(release_spec["name"])
            if deployment_release
              if deployment_release.version != release_spec["version"].to_s
                raise RuntimeInvalidDeploymentRelease, "Runtime manifest specifies release '#{release_spec["name"]}' with version as '#{release_spec["version"]}'. " +
                      "This conflicts with version '#{deployment_release.version}' specified in the deployment manifest."
              else
                next
              end
            end

            release_version = DeploymentPlan::ReleaseVersion.new(@deployment.model, release_spec)
            release_version.bind_model

            @deployment.add_release(release_version)
          end
        end
      end

      def parse_addons(runtime_manifest)
        addons = safe_property(runtime_manifest, 'addons', :class => Array, :default => [])
        addons.each do | addon_spec |
          # addon_spec = {
          #   'name' => 'security',
          #   'jobs' => [
          #     {
          #       'name' => 'strongswan',
          #       'release' => 'strongswan',
          #     }
          #   ]
          # }
          deployment_plan_templates = []

          addon_jobs = safe_property(addon_spec, 'jobs', :class => Array, :default => [])

          addon_jobs.each do |addon_job|
            if !@release_specs.find { |release_spec| release_spec['name'] == addon_job['release'] }
              raise RuntimeReleaseNotListedInReleases,
                    "Runtime manifest specifies job '#{addon_job['name']}' which is defined in '#{addon_job['release']}', but '#{addon_job['release']}' is not listed in the releases section."
            end

            if @deployment
              @deployment.parse_addons(@release_specs, addon_job)
            end
          end
        end
      end
    end
  end
end
