# greeter-core

[![CI](https://github.com/greeterhq/greeter-core/actions/workflows/ci.yml/badge.svg)](https://github.com/greeterhq/greeter-core/actions/workflows/ci.yml)

Pure domain core and ports for the Greeter application.

## Quick start

Install the gem from rubygems.org, then start an `irb` session that greets
Alice Bonsu. The gem is pure domain logic with no I/O, so the session drives it
with the bundled `FixedClock` test double — no adapter required. `GreetingService`
accepts any `clock:` that responds to `#now`; a real app injects its own.

```bash
gem install greeter-core

irb -r greeter/core -r greeter/core/testing <<'RUBY'
clock    = Greeter::Core::Testing::FixedClock.new
service  = Greeter::Core::Domain::GreetingService.new(clock: clock)
greeting = service.greet('alice bonsu')
puts greeting.guest_name.display   # => Alice Bonsu
RUBY
```

## Install locally and try it in irb

Build the gem from the gemspec and install the resulting `.gem` into your local
RubyGems, then explore it in an `irb` session. This gem is pure domain + ports
with no I/O, so the `irb` walkthrough drives it with the bundled `FixedClock`
test double — no adapter required.

### 1. Build and install from source

```bash
# from the greeter-core root
gem build greeter-core.gemspec        # => greeter-core-<version>.gem
gem install ./greeter-core-*.gem      # installs into your local RubyGems
```

### 2. Use it in an irb session

Start `irb` with the library required (the gem is not auto-loaded into a plain
`irb`):

```bash
irb -r greeter/core -r greeter/core/testing
```

Then, in the session:

```ruby
# A clock is injected; the testing double returns a fixed time (no Time.now).
clock   = Greeter::Core::Testing::FixedClock.new
service = Greeter::Core::Domain::GreetingService.new(clock: clock)

greeting = service.greet('alice bonsu')
greeting.guest_name.display   # => "Alice Bonsu"
greeting.greeted_at           # => 2024-06-01 09:00:00 UTC

# Names are validated; invalid input raises InvalidGuestName.
service.greet('')             # => raises Greeter::Core::Domain::InvalidGuestName
```

If you prefer not to pass `-r` flags, start a bare `irb` and require the files
from inside the session instead:

```ruby
require 'greeter/core'
require 'greeter/core/testing'
```

### Uninstall

```bash
gem uninstall greeter-core
```

## Install, verify, commit
### from greeter-core root
`bundle install`

### domain + ports + testing specs
`bundle exec rspec`

### lint
`bundle exec rubocop`

### smoke-test the packaged load path resolves and behaves
```bash
bundle exec ruby -Ilib -e "require 'greeter/core'; puts Greeter::Core::Domain::GuestName.new('alice bonsu').display" # => Alice Bonsu
```

### confirm the gem builds cleanly
```bash
gem build greeter-core.gemspec
```


## Publishing to RubyGems.org

The `publish` job in `.github/workflows/ci.yml` publishes the gem to
[rubygems.org](https://rubygems.org). It runs **only when a version tag is
pushed** (a tag matching `v*`, e.g. `v0.1.0`) and **only after** the `lint`,
`functional`, and `performance` jobs pass.

Publishing uses RubyGems **trusted publishing** (OIDC): GitHub Actions proves its
identity to RubyGems and receives a short-lived, single-use API key at run time.
No long-lived RubyGems API key is stored in GitHub.

### 1. Create the RubyGems account (one time)

- Sign up / sign in at <https://rubygems.org>.
- Enable MFA on the account (RubyGems requires it for publishing).

### 2. Configure trusted publishing on RubyGems (one time)

The gem is already registered on rubygems.org
(<https://rubygems.org/gems/greeter-core>). Open the gem page → **Trusted
publishers** → **Create**, and add a GitHub Actions publisher matching this repo
and workflow:

| Field | Value |
| --- | --- |
| Repository owner | `greeterhq` |
| Repository name | `greeter-core` |
| Workflow filename | `ci.yml` |
| Environment | `rubygems` |

The **Environment** must match the `environment: rubygems` set on the `publish`
job in the workflow.

### 3. Create the matching GitHub environment (one time)

In the GitHub repo: **Settings → Environments → New environment**, name it
`rubygems`. No secrets are needed — trusted publishing supplies the credential.
Optionally add a **deployment protection rule** (e.g. required reviewer, or
restrict to tags matching `v*`) so releases require approval.

There are **no repository secrets to add** for publishing.

### 4. Release a new version

1. Bump `VERSION` in `lib/greeter/core/version.rb` (the workflow fails if the tag
   and gem version disagree).
2. Commit and push to your default branch.
3. Tag and push the tag:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

The `publish` job runs after the lint/functional/performance gate and publishes
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
