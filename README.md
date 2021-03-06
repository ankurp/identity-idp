Identity-IdP (Upaya)
====================

[![Build Status](https://circleci.com/gh/18F/identity-idp.svg?style=svg)](https://circleci.com/gh/18F/identity-idp)
[![Code Climate](https://api.codeclimate.com/v1/badges/e78d453f7cbcac64a664/maintainability)](https://codeclimate.com/github/18F/identity-idp/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/e78d453f7cbcac64a664/test_coverage)](https://codeclimate.com/github/18F/identity-idp/test_coverage)
[![security](https://hakiri.io/github/18F/identity-idp/master.svg)](https://hakiri.io/github/18F/identity-idp/master)

A Identity Management System powering login.gov.

### Local development

#### Dependencies

- Ruby 2.6
- [Postgresql](http://www.postgresql.org/download/)
- [Redis 2.8+](http://redis.io/)
- [Node.js v12.x.x](https://nodejs.org)
- [Yarn](https://yarnpkg.com/en/)

#### Running the app with Docker

See the [Docker documentation](./docs/Docker.md) to get up and running

#### Setting up and running the app without Docker

1. Make sure you have a working development environment with all the
  [dependencies](#dependencies) installed. On OS X, the easiest way
  to set up a development environment is by running our [Laptop]
  script. The script will install all of this project's dependencies.

  If using rbenv, you may need to alias your specific installed ruby version to the more generic version found in the `.ruby-version` file. To do this, use [`rbenv-aliases`](https://github.com/tpope/rbenv-aliases):

  ```
  git clone git://github.com/tpope/rbenv-aliases.git "$(rbenv root)/plugins/rbenv-aliases" # install rbenv-aliases per its documentation

  rbenv alias 2.6 2.6.5 # create the version alias
  ```

2. Make sure Postgres and Redis are running.

  For example, if you've installed the laptop script on OS X, you can start the services like this:

  ```
  $ brew services start redis
  $ brew services start postgresql
  ```

3. Create the development and test databases:

  ```
  $ psql -c "CREATE DATABASE upaya_development;"
  $ psql -c "CREATE DATABASE upaya_test;"
  ```

4. Run the following command to set up the environment:

  ```
  $ make setup
  ```

  This command copies sample configuration files, installs required gems
  and sets up the database.

5. Run the app server with:

  ```
  $ make run
  ```


If you want to develop without an internet connection, you can set
`RAILS_OFFLINE=1` in your environment. This disables the `mx` record
check on email addresses.

If you want to measure the app's performance in development, set the
`rack_mini_profiler` option to `'on'` in `config/application.yml` and
restart the server. See the [rack_mini_profiler] gem for more details.

[Laptop]: https://github.com/18F/laptop
[rack_mini_profiler]: https://github.com/MiniProfiler/rack-mini-profiler

#### Testing Analytics

If you want to visualize and query the event and log data, you can install
the latest versions of Elasticsearch, Logstash, and Kibana.
On OS X, the easiest way is with Homebrew:

```
brew tap homebrew/services

brew install elasticsearch logstash kibana

brew services start elasticsearch
brew services start kibana
```

Start logstash by running this command from this repo's root directory:
```
logstash -f logstash.conf
```

When you trigger an event in the app (such as signing in), you should see some
output in the logstash window.

To explore the data with Kibana, visit http://localhost:5601

##### Troubleshooting Kibana errors
Below are some common errors:

- On the Kibana website: "Your Kibana index is out of date, reset it or use the
X-Pack upgrade assistant."

- In the logstash output:
  ```
  Failed to parse mapping [_default_]: [include_in_all] is not allowed for
  indices created on or after version 6.0.0 as [_all] is deprecated. As a
  replacement, you can use an [copy_to] on mapping fields to create your own
  catch all field.
  ```

Solution, assuming you don't use these services for other apps and are OK with
deleting existing data:

1. Stop all services:
  - Press `ctrl-c` to stop logstash if it's running
  ```console
  brew services stop elasticsearch
  brew services stop kibana
  ```

2. Uninstall everything:
  ```console
  brew uninstall --force elasticsearch
  brew uninstall --force logstash
  brew uninstall --force kibana
  ```
3. Reinstall everything:
  ```console
  brew install elasticsearch logstash kibana
  ```

4. Start the services:
  ```console
  brew services start elasticsearch
  brew services start kibana
  ```

5. Delete the old Kibana index:
  ```console
  curl -XDELETE http://localhost:9200/.kibana
  ```

6. Delete the old logstash template:
  - Visit http://localhost:5601/app/kibana#/dev_tools/console?_g=()
  - Paste `DELETE /_template/logstash` in the box on the left and click
  the green "play" button to run the command

7. Start logstash in a new Terminal tab:
  ```console
  logstash -f logstash.conf
  ```

8. Launch the IdP app and sign in to generate some events. You should see output
in the logstash tab without any errors.

9. Visit http://localhost:5601/ and click "Discover" on the left sidebar. If you
get a warning that no default index pattern exists, copy the last pattern that
appears in the list, which will have the format `logstash-year.month.day`. Paste
it into the "Index pattern" field, then click the "Next step" button.

10. On `Step 2 of 2: Configure settings`, select `@timestamp` from the
`Time Filter field name` dropdown, then click "Create index pattern".

11. Create some more events on the IdP app.

12. Refresh the Kibana website. You should now see new events show up in the
Discover section.

### Viewing the app locally

Once it is up and running, the app will be accessible at
`http://localhost:3000/` by default.

To view email messages, Mailcatcher must be running. You can check if it's
running by visiting http://localhost:1080/. To run Mailcatcher:

```
$ mailcatcher
```

If you would like to run the application on a different port:

* Change the port number for `mailer_domain_name` and `domain_name` in `config/application.yml`
* Run the app on your desired port like `make run PORT=1234`

If you would like to see the Spanish translations on a particular page, add
`?locale=es` to the end of the URL, such as `http://localhost:3000/?locale=es`.
Currently, you'll need to add `?locale=es` to each URL manually. We are working
on a more robust and user-friendly way to switch between locales.

To see outbound SMS messages and phone calls, visit `http://localhost:3000/test/telephony`.

### Running Tests

To run all the tests:

```
$ make test
```

To run a subset of tests excluding slow tests (such as accessibility specs):
```
$ make fast_test
```

#### Smoke Tests

The smoke tests are a series of RSpec tests designed to run against deployed environments. To run them against the local Rails server:

```bash
./bin/smoke_test --local
```

To run the smoke tests against a deployed server, make sure you set up a `.env` file with the right configuration values, see [monitor_config.rb](spec/support/monitor/monitor_config.rb) for the full list of environment variables used. The script below will `source` that file and add the variables to the environment.

```bash
MONITOR_ENV=INT ./bin/smoke_test --remote
```

#### Speeding up local development and testing
To automatically run the test that corresponds to the file you are editing,
run `bundle exec guard` with the env var `GUARD_RSPEC_CMD` set to your preferred
command for running `rspec`. For example, if you use [Zeus](https://github.com/burke/zeus),
you would set the env var to `zeus rspec`:
```console
GUARD_RSPEC_CMD="zeus rspec" bundle exec guard
```

If you don't specify the `GUARD_RSPEC_CMD` env var, it will default to
`bundle exec rspec`.

We recommend setting up a shell alias for running this command, such as:
```console
alias idpguard='GUARD_RSPEC_CMD="zeus rspec" bundle exec guard'
```

#### Troubleshooting
If you are on a mac, if you receive the following prompt the first time you run the test suite, enter `sekret` as the passphrase:

![alt text][mac-test-passphrase-prompt]

#### Documentation for the testing tools we use
[RSpec](https://relishapp.com/rspec/rspec-core/docs/command-line)

[Guard](https://github.com/guard/guard-rspec)

JavaScript unit tests run using the mocha test runner. Check out the
[mocha documentation](https://mochajs.org/) for more details.

### Setting up Geolocation

The app uses MaxMind Geolite2 for geolocation.
To test geolocation locally you will need to add a copy of the Geolite2-City database to the IdP.

The Geolite2-City database can be downloaded from MaxMind's site at [https://dev.maxmind.com/geoip/geoip2/geolite2/](https://dev.maxmind.com/geoip/geoip2/geolite2/).

Download the GeoIP2 Binary and save it at `geo_data/GeoLite2-City.mmdb`.
The app will start using that Geolite2 file for geolocation after restart.

### User flows

We have an automated tool for generating user flows using real views generated from the application. These specs are excluded from our typical spec run because of the overhead of generating screenshots for each view.

The local instance of the application must be running in order to serve up the assets (eg. `make run`). Then, you can specify where the assets are hosted from and generate the views with:

```
$ RAILS_ASSET_HOST=localhost:3000 rake spec:user_flows
```

Then, visit http://localhost:3000/user_flows in your browser!

##### Exporting

The user flows tool also has an export feature which allows you to export everything for the web. You may host these assets with someting like [`simplehttpserver`](https://www.npmjs.com/package/simplehttpserver) or publish to [Federalist](https://federalist.18f.gov/). To publish user flows for Federalist, first make sure the application is running locally (eg. localhost:3000) and run:

```
$ RAILS_ASSET_HOST=localhost:3000 FEDERALIST_PATH=/site/user/repository rake spec:user_flows:web
```

This will output your site to `public/site/user/repository` for quick publishing to [Federalist](https://federalist-docs.18f.gov/pages/using-federalist/). To test compatibility, run `simplehttpserver` from the app's `public` folder and visit `http://localhost:8000/<FEDERALIST PATH>/user_flows` in your browser.

[laptop script]: https://github.com/18F/laptop

### Proofing vendors

Some proofing vendor code is located in private Github repositories because of NDAs. You can still use it
in your local development environment if you have access to the private repository.

Example:

#### Check out the private repository for `somevendorname`

```
$ cd vendor
$ git clone git@github.com:18F/identity-somevendorname-api-client-gem.git somevendorname
```

#### Add the vendor configuration

Add appropriate vendor environment variables to `config/application.yml` -- see a member of the
login.gov team for credentials and other values.

### Why 'Upaya'?

"skill in means" https://en.wikipedia.org/wiki/Upaya

### Managing translation files

To help us handle extra newlines and make sure we wrap lines consistently, we have a script called `./scripts/normalize-yaml` that helps format YAML consistently. After importing translations (or making changes to the *.yml files with strings, run this for the IDP app:

```
$ make normalize_yaml
```

[mac-test-passphrase-prompt]: mac-test-passphrase-prompt.png "Mac Test Passphrase Prompt"
