require 'json'
require 'open3'
require 'time'

workspace, output = ARGV
names = %w[trestle trestle-auth trestle-auth-otp trestle-search trestle-active_storage trestle-good_job trestle-mobility]
repositories = names.to_h do |name|
  directory = name == 'trestle-auth-otp' ? ENV.fetch('TRESTLE_OTP_PATH', File.join(workspace, name)) : File.join(workspace, name)
  head, status = Open3.capture2('git', '-C', directory, 'rev-parse', 'HEAD')
  abort "Cannot identify #{name}" unless status.success?
  branch, = Open3.capture2('git', '-C', directory, 'rev-parse', '--abbrev-ref', 'HEAD')
  [name, { 'sha' => head.strip, 'branch' => branch.strip,
    'version' => Gem.loaded_specs.fetch(name).version.to_s }]
end
File.write(output, JSON.pretty_generate('verified_at' => Time.now.utc.iso8601,
  'ruby' => RUBY_VERSION, 'rails' => Gem.loaded_specs.fetch('rails').version.to_s,
  'repositories' => repositories) + "\n")
