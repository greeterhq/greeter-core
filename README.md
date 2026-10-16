# greeter-core

[![CI](https://github.com/greeterhq/greeter-core/actions/workflows/ci.yml/badge.svg)](https://github.com/greeterhq/greeter-core/actions/workflows/ci.yml)

Pure domain core and ports for the Greeter application.

## Usage
```ruby
require 'greeter/core'

clock    = my_clock # any object responding to #now
service  = Greeter::Core::Domain::GreetingService.new(clock: clock)
greeting = service.greet('alice')
greeting.guest_name.display # => "Alice"
```

## Testing helpers
```ruby
require 'greeter/core/testing'
clock = Greeter::Core::Testing::FixedClock.new
```

## Install, verify, commit
### from greeter-core root
`bundle install`

### domain + ports + testing specs
`bundle exec rspec`

### lint
`bundle exec rubocop`

### smoke-test the packaged load path resolves and behaves
`bundle exec ruby -Ilib -e "require 'greeter/core'; puts Greeter::Core::Domain::GuestName.new('alice bonsu').display" # => Alice Bonsu

## confirm the gem builds cleanly
gem build greeter-core.gemspec


## Publishing to RubyGems.org

The `publish` job in `.github/workflows/ci.yml` publishes the gem to
[rubygems.org](https://rubygems.org). It runs **only when a version tag is
pushed** (a tag matching `v*`, e.g. `v0.1.0`) and **only after** the `spec`,
`lint`, and `perf` jobs pass.

Publishing uses RubyGems **trusted publishing** (OIDC): GitHub Actions proves its
identity to RubyGems and receives a short-lived, single-use API key at run time.
No long-lived RubyGems API key is stored in GitHub.

### 1. Create the RubyGems account (one time)

- Sign up / sign in at <https://rubygems.org>.
- Enable MFA on the account (RubyGems requires it for publishing).

### 2. Reserve the gem name (first release only)

Trusted publishing can only be configured on a gem that already exists on
rubygems.org. For the very first `0.1.0` release, do a one-time manual push from
your machine so the name is registered:

```bash
gem build greeter-core.gemspec
gem signin
gem push greeter-core-0.1.0.gem   # prompts for RubyGems credentials + MFA
```

After that, all future releases go through the automated workflow below.

### 3. Configure trusted publishing on RubyGems (one time)

On rubygems.org, open the gem page → **Trusted publishers** → **Create**, and add
a GitHub Actions publisher matching this repo and workflow:

| Field | Value |
| --- | --- |
| Repository owner | your GitHub username/org |
| Repository name | `greeter-core` |
| Workflow filename | `ci.yml` |
| Environment | `rubygems` |

The **Environment** must match the `environment: rubygems` set on the `publish`
job in the workflow.

### 4. Create the matching GitHub environment (one time)

In the GitHub repo: **Settings → Environments → New environment**, name it
`rubygems`. No secrets are needed — trusted publishing supplies the credential.
Optionally add a **deployment protection rule** (e.g. required reviewer, or
restrict to tags matching `v*`) so releases require approval.

There are **no repository secrets to add** for publishing.

### 5. Release a new version

1. Bump `VERSION` in `lib/greeter/core/version.rb` (the workflow fails if the tag
   and gem version disagree).
2. Commit and push to your default branch.
3. Tag and push the tag:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

The `publish` job runs after the test/lint/perf gate and publishes
`greeter-core-<version>` to rubygems.org via trusted publishing.

### Consuming the published gem

Because it's public on rubygems.org, no special configuration is needed:

```ruby
# Gemfile
gem "greeter-core"
```

```bash
gem install greeter-core
```
