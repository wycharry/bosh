module Bosh::Director
  module DeploymentPlan
    class DeploymentSpecParser
      include ValidationHelper

      def initialize(deployment, event_log, logger)
        @event_log = event_log
        @logger = logger
        @deployment = deployment
      end

      # @param [Hash] manifest Raw deployment manifest
      # @return [DeploymentPlan::Planner] Deployment as build from deployment_spec
      def parse(deployment_manifest, options = {})
        @deployment_manifest = deployment_manifest
        @job_states = safe_property(options, 'job_states', :class => Hash, :default => {})

        parse_options = {}
        if options['canaries']
          parse_options['canaries'] = options['canaries']
          @logger.debug("Using canaries value #{options['canaries']} given in a command line.")
        end

        if options['max_in_flight']
          parse_options['max_in_flight'] = options['max_in_flight']
          @logger.debug("Using max_in_flight value #{options['max_in_flight']} given in a command line.")
        end

        parse_stemcells
        parse_properties
        parse_releases
        parse_update(parse_options)
        parse_jobs(parse_options)

        if (@deployment_manifest['addons'] != nil)
          parse_addons(@deployment_manifest['releases'], @deployment_manifest['addons'])
        end
        @deployment
      end

      def parse_addons(releases, addons)
        addons.each do |addon_spec|
          addon_jobs = addon_spec['jobs']

          addon_jobs.each do |addon_job|
            if !releases.find { |release_spec| release_spec['name'] == addon_job['release'] }
              raise RuntimeReleaseNotListedInReleases,
                "Deployment manifest specifies job '#{addon_job['name']}' from release '#{addon_job['release']}', but '#{addon_job['release']}' is not listed in the releases section."
            end

            parse_addon(releases, addon_job)
          end
        end
      end

      def parse_addon(releases, addon_job)
        valid_release_versions = releases.map {|r| r['name'] }
        deployment_release_ids = Models::Release.where(:name => valid_release_versions).map {|r| r.id}
        deployment_jobs = @deployment.instance_groups

        templates_from_model = Models::Template.where(:name => addon_job['name'], :release_id => deployment_release_ids)
        if templates_from_model == nil
          raise "Job '#{addon_job['name']}' not found in Template table"
        end

        release = @deployment.release(addon_job['release'])
        release.bind_model

        template = DeploymentPlan::Template.new(release, addon_job['name'])

        deployment_jobs.each do |j|
          templates_from_model.each do |template_from_model|
            if template_from_model.consumes != nil
              template_from_model.consumes.each do |consumes|
                template.add_link_from_release(j.name, 'consumes', consumes["name"], consumes)
              end
            end
            if template_from_model.provides != nil
              template_from_model.provides.each do |provides|
                template.add_link_from_release(j.name, 'provides', provides["name"], provides)
              end
            end
          end

          provides_links = safe_property(addon_job, 'provides', class: Hash, optional: true)
          provides_links.to_a.each do |link_name, source|
            template.add_link_from_manifest(j.name, "provides", link_name, source)
          end

          consumes_links = safe_property(addon_job, 'consumes', class: Hash, optional: true)
          consumes_links.to_a.each do |link_name, source|
            template.add_link_from_manifest(j.name, 'consumes', link_name, source)
          end

          if addon_job.has_key?('properties')
            template.add_template_scoped_properties(addon_job['properties'], j.name)
          end
        end

        template.bind_models
        deployment_plan_templates.push(template)

        deployment_jobs.each do |job|
          merge_addon(job, deployment_plan_templates, addon_spec['properties'])
          #merge_addon()
        end
      end

      def merge_addon(job, addon_jobs, properties)
        # iterate through deployment plan instance group jobs and see if any of them are the
        # same name as the addon_job, if they are throw an error, otherwise add to instance group
        if job.templates
          job.templates.each do |job_template|
            addon_jobs.each do |addon_job_template|
              if addon_job_template.name == job_template.name
                raise "Colocated job '#{addon_job_template.name}' is already added to the instance group '#{job.name}'."
              end
            end
          end
          job.templates.concat(addon_jobs)
        else
          job.templates = addon_jobs
        end

        if properties
          if job.all_properties
            job.all_properties.merge!(properties)
          else
            job.all_properties = properties
          end
        end
      end

      private

      def parse_stemcells
        if @deployment_manifest.has_key?('stemcells')
          safe_property(@deployment_manifest, 'stemcells', :class => Array).each do |stemcell_hash|
            alias_val = safe_property(stemcell_hash, 'alias', :class=> String)
            if @deployment.stemcells.has_key?(alias_val)
              raise StemcellAliasAlreadyExists, "Duplicate stemcell alias '#{alias_val}'"
            end
            @deployment.add_stemcell(Stemcell.parse(stemcell_hash))
          end
        end
      end

      def parse_properties
        @deployment.properties = safe_property(@deployment_manifest, 'properties',
          :class => Hash, :default => {})
      end

      def parse_releases
        release_specs = []

        if @deployment_manifest.has_key?('release')
          if @deployment_manifest.has_key?('releases')
            raise DeploymentAmbiguousReleaseSpec,
              "Deployment manifest contains both 'release' and 'releases' " +
                'sections, please use one of the two.'
          end
          release_specs << @deployment_manifest['release']
        else
          safe_property(@deployment_manifest, 'releases', :class => Array).each do |release|
            release_specs << release
          end
        end

        release_specs.each do |release_spec|
          @deployment.add_release(ReleaseVersion.new(@deployment.model, release_spec))
        end
      end

      def parse_update(parse_options)
        update_spec = safe_property(@deployment_manifest, 'update', :class => Hash)
        @deployment.update = UpdateConfig.new(update_spec.merge(parse_options))
      end

      def parse_jobs(parse_options)
        if @deployment_manifest.has_key?('jobs') && @deployment_manifest.has_key?('instance_groups')
          raise JobBothInstanceGroupAndJob, "Deployment specifies both jobs and instance_groups keys, only one is allowed"
        end

        jobs = safe_property(@deployment_manifest, 'jobs', :class => Array, :default => [])
        instance_groups = safe_property(@deployment_manifest, 'instance_groups', :class => Array, :default => [])

        if !instance_groups.empty?
          jobs = instance_groups
        end

        jobs.each do |job_spec|
          # get state specific for this job or all jobs
          state_overrides = @job_states.fetch(job_spec['name'], @job_states.fetch('*', {}))
          job_spec = job_spec.recursive_merge(state_overrides)
          @deployment.add_job(InstanceGroup.parse(@deployment, job_spec, @event_log, @logger, parse_options))
        end
      end
    end
  end
end
