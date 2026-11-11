# Updating applications to the verified Rails 8.1 stack

Use the McRipper forks' default branches (`master`, except Search and GoodJob
which use `main`) or the exact verified Git revisions. These changes are Git
updates; OTP 0.3.0 has not been published to RubyGems by this work.

```ruby
gem 'trestle', github: 'McRipper/trestle', branch: 'master'
gem 'trestle-auth', github: 'McRipper/trestle-auth', branch: 'master'
gem 'trestle-auth-otp', github: 'McRipper/trestle-auth-otp', branch: 'master'
gem 'trestle-search', github: 'McRipper/trestle-search', branch: 'main'
gem 'trestle-active_storage', github: 'McRipper/trestle-active_storage', branch: 'master'
gem 'trestle-good_job', github: 'McRipper/trestle-good_job', branch: 'main'
gem 'trestle-mobility', github: 'McRipper/trestle-mobility', branch: 'master'
```

Include only the plugins actually used by each application. Remove old version
constraints that exclude Trestle 0.10, Auth 0.5 or Search 0.5. Update the selected
gems with Bundler and commit the resulting Gemfile.lock. For reproducible rollout,
replace `branch:` with `ref:` using the SHAs in the verification's revisions.json.
Do not update every unrelated application dependency as part of this step.

OTP 0.3.0 requires Ruby 3.2+, Active Record >= 7.1 and < 9, ROTP >= 6.4 and < 7,
RQRCode >= 3.2 and < 4, and rqrcode_core >= 2.1 and < 3. Update these dependencies
with the plugin so that an old application lockfile does not retain earlier series.
The plugin no longer loads `active_model_otp`; a separate application dependency on
its released 2.3.4 version still conflicts with ROTP 6.4 and must be migrated too.
The model helpers `otp_random_secret`, `otp_code` and `provisioning_uri` are retained.

For applications using OTP 0.2.x:

1. Configure Active Record encryption keys in application credentials/secret storage.
2. Generate and review `rails g trestle:auth:otp:upgrade Administrator`, using the
   actual model name. Deploy/apply the schema migration before serving the new code.
3. Preserve existing OTP secrets. After a database backup, encrypt them in place
   with `Administrator.find_each(&:encrypt)`; never regenerate enrolled users' keys.
4. Remove custom OTP checkboxes and secret/QR displays. Enrollment and factor changes
   now use `/admin/otp`, relative to the application's Trestle mount path.
5. Existing sessions must sign in again. Ask enrolled users to save recovery codes.
6. Test both Basic/Devise integration as applicable, password reset, recovery, role
   restrictions, custom admin forms and any custom Warden strategies in staging.

See the OTP repository README for new installations and Devise models that never
had OTP columns. No application production migrations are run by this harness.

If moving from GoodJob 3, follow its supported staged migration to 3.99.x and then
4.x. This suite creates a new GoodJob 4 test schema; it does not migrate existing jobs.
Storage services, DeepL calls, video/PDF previews and application-specific custom
forms also need their own application tests. Image thumbnails use `resize_to_limit`
with libvips and retain their aspect ratio.
