# Pack Ruby

Ruby via mise + bundler, tests with rspec, console with pry.

## Version
`.ruby-version` at the project root (mise reads it). Example:
```
3.3.4
```
Per-project override in `./mise.toml`:
```toml
[tools]
ruby = "3.3.4"
```

See the `Gemfile` in this dir as minimal base.

## Usage
```sh
mise install
gem install bundler
bundle install
bundle exec rspec
bundle exec pry
```
