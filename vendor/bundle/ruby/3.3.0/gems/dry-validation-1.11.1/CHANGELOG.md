<!--- DO NOT EDIT THIS FILE - IT'S AUTOMATICALLY GENERATED VIA DEVTOOLS --->

## 1.11.1 2025-01-21


### Fixed

- Fixed warning about unused block in macros (@flash-gordon)


[Compare v1.11.0...v1.11.1](https://github.com/dry-rb/dry-validation/compare/v1.11.0...v1.11.1)

## 1.11.0 2025-01-06


### Changed

- Passing non-hash values to `Contract#call` now raises a meaningful error (issue #716 via #723) (@flash-gordon)
- Set minimum Ruby version to 3.1 (@flash-gordon)

[Compare v1.10.0...v1.11.0](https://github.com/dry-rb/dry-validation/compare/v1.10.0...v1.11.0)

## 1.10.0 2022-11-04

This release is mostly about upgrading to dry-core 1.0 and dry-configurable 1.0. One of the outcomes is dropping dependency on dry-container (because it was moved to dry-core). If you happen to use dry-container, please switch to `Dry::Core::Container`.

### Changed

- Upgraded to the latest versions of dry-{core,configurable,logic,types} (@flash-gordon + @solnic)

[Compare v1.9.0...v1.10.0](https://github.com/dry-rb/dry-validation/compare/v1.9.0...v1.10.0)

## 1.9.0 2022-10-15


### Fixed

- Duplicated keys mishandling in rule evaluation (issue #676 fixed via #711) (@mereghost)

### Changed

- Use Zeitwerk for auto-loading (via #715) (@solnic)

[Compare v1.8.1...v1.9.0](https://github.com/dry-rb/dry-validation/compare/v1.8.1...v1.9.0)

## 1.8.1 2022-05-28


### Fixed

- Raise an InvalidKeyErrors on substring of valid keys (issue #705 fixed via #706) (@MatElGran)
- Using `rule(:arr).each { .. }` doesn't crash when `:arr` turns out to be `nil` (issue #708 fixed via #709) (@bautrey37)


[Compare v1.8.0...v1.8.1](https://github.com/dry-rb/dry-validation/compare/v1.8.0...v1.8.1)

## 1.8.0 2022-02-17


### Added

- New rule helper `base_rule_error?` which checks if there's any base error set (via #690) (@wuarmin)

### Changed

- Dependency on dry-schema was bumped to 1.9.1 (@solnic)

[Compare v1.7.0...v1.8.0](https://github.com/dry-rb/dry-validation/compare/v1.7.0...v1.8.0)

## 1.7.0 2021-09-12


### Changed

- [internal] Upgraded to new `setting` API provided in dry-configurable 0.13.0 (@timriley in #686 and 3f8f7d8)
- Bumped dry-schema dependency to 1.8.0 (in part, to ensure dry-configurable 0.13.0 is available) (@timriley)

[Compare v1.6.0...v1.7.0](https://github.com/dry-rb/dry-validation/compare/v1.6.0...v1.7.0)

## 1.6.0 2020-12-05


### Added

- You can now pass a key name or path to `rule_error?` predicate (issue #658 closed via #673) (@moofkit)
- You can now pass initial context object to `Contract#call` (issue #674 via #675) (@pyromaniac)

### Fixed

- Checking `key?` within a rule no longer crashes when value is `nil` or an empty string (issue #670 fixed via #672) (@alexxty7)


[Compare v1.5.6...v1.6.0](https://github.com/dry-rb/dry-validation/compare/v1.5.6...v1.6.0)

## 1.5.6 2020-09-04


### Fixed

- Dependency on dry-schema was bumped to >= 1.5.1. This time for real (@solnic)


[Compare v1.5.5...v1.5.6](https://github.com/dry-rb/dry-validation/compare/v1.5.5...v1.5.6)

## 1.5.5 2020-09-03


### Fixed

- Dependency on dry-schema was bumped to >= 1.5.2 (see #666 for more info) (@artofhuman)


[Compare v1.5.4...v1.5.5](https://github.com/dry-rb/dry-validation/compare/v1.5.4...v1.5.5)

## 1.5.4 2020-08-21


### Added

- You can now pass any key or a path to the rule's `key?` helper (see #664 for more info) (@alassek)

### Fixed

- Full messages work correctly with rule failures now (issue #661 fixed via #662) (@stind)
- Providing a custom message template for array errors works correctly (issue #663 fixed via #665) (@tadeusz-niemiec)


[Compare v1.5.3...v1.5.4](https://github.com/dry-rb/dry-validation/compare/v1.5.3...v1.5.4)

## 1.5.3 2020-07-27


### Added

- You can now access current value's index via `rule(:foo).each do |index:|` (issue #606 done via #657) (@mrbongiolo)

### Fixed

- Using `.each(:foo)` works as expected when there are errors related to other keys (issue #659 fixed via #660) (@solnic)

### Changed

- `Result#error?` is now a public API and it takes into consideration both schema and rule errors (issue #655 fixed via #656) (@PragTob)

[Compare v1.5.2...v1.5.3](https://github.com/dry-rb/dry-validation/compare/v1.5.2...v1.5.3)

## 1.5.2 2020-07-14


### Fixed

- `key?` predicate in rules no longer crashes when the rule path points to a non-existent array value (issue #653 fixed via #654) (@solnic)


[Compare v1.5.1...v1.5.2](https://github.com/dry-rb/dry-validation/compare/v1.5.1...v1.5.2)

## 1.5.1 2020-06-18


### Fixed

- dry-monads no longer required for the `:hints` extension (@schokomarie)
- Using `full: true` option works as expected with custom rule messages (issue #618 fixed via #651) (@sirfilip)
- Using `locale: ...` option works as expected with hints (issue #589 fixed via 652) (@sirfilip)


[Compare v1.5.0...v1.5.1](https://github.com/dry-rb/dry-validation/compare/v1.5.0...v1.5.1)

## 1.5.0 2020-03-11


### Added

- `schema_error?` rule helper (@waiting-for-dev)
- `rule_error?` rule helper (@waiting-for-dev)

### Changed

- dry-schema dependency was bumped to `~> 1.5` (@solnic)
- [internal] `KeyMap` patches have been removed since dry-schema now provides required functionality (@solnic)

[Compare v1.4.2...v1.5.0](https://github.com/dry-rb/dry-validation/compare/v1.4.2...v1.5.0)

## 1.4.2 2020-01-18


### Fixed

- Macros using predicates that accept a range argument work as expected (no need to wrap the argument in an array) (@waiting-for-dev)


[Compare v1.4.1...v1.4.2](https://github.com/dry-rb/dry-validation/compare/v1.4.1...v1.4.2)

## 1.4.1 2020-01-08


### Added

- Pattern matching on result values (@flash-gordon)

### Fixed

- List tokens are correctly interpolated as a comma separated list in rule messages (see #611) (@waiting-for-dev)
- Warnings about delegated keywords (@flash-gordon)


[Compare v1.4.0...v1.4.1](https://github.com/dry-rb/dry-validation/compare/v1.4.0...v1.4.1)

## 1.4.0 2019-12-12


### Added

- Support for multi-schema inheritance (@ianwhite)

### Fixed

- Keyword warnings reported by Ruby 2.7 (@flash-gordon)
- Fixed an issue where `MessageSet` would be marked as empty too early (@ianwhite)
- Messages are correctly generated when there are errors for both an array and one or more of its elements (see #599) (@Bugagazavr)

### Changed

- A meaningful exception is raised when failure options are not valid (@MatElGran)
- [internal] improved performance in `Contract.ensure_valid_keys` (@grzegorz-jakubiak)
- [internal] fixed keyword warnings on MRI 2.7.0 (@flash-gordon)

[Compare v1.3.1...v1.4.0](https://github.com/dry-rb/dry-validation/compare/v1.3.1...v1.4.0)

## 1.3.1 2019-08-16


### Changed

- You can now set an external schema without providing a block (@alassek)

[Compare v1.3.0...v1.3.1](https://github.com/dry-rb/dry-validation/compare/v1.3.0...v1.3.1)

## 1.3.0 2019-08-14


### Added

- Support for setting an external schema (that can be extended too) (fixed #574) (@solnic)

### Fixed

- Using a hash spec to define rule keys with more than one value is properly handled by rule guard now (fixed #576) (@solnic)

### Changed

- `values` within rules uses `Hash#fetch_values` internally now, which improves performance (@esparta)

[Compare v1.2.1...v1.3.0](https://github.com/dry-rb/dry-validation/compare/v1.2.1...v1.3.0)

## 1.2.1 2019-07-16


### Fixed

- Defining an abstract contract class that has no schema no longer crashes (issue #565) (@solnic)
- Fixed an issue where `Rule#each` would crash when the value is not an array (issue #567) (@solnic)
- Fixed an issue where guarding a rule would crash when keys are missing in the input (issue #569) (@solnic)
- Added missing "pathname" require (issue #570) (@solnic)


[Compare v1.2.0...v1.2.1](https://github.com/dry-rb/dry-validation/compare/v1.2.0...v1.2.1)

## 1.2.0 2019-07-08


### Added

- New extension `:predicates_as_macros` (@waiting-for-dev)

### Fixed

- Guarding rules for nested keys works correctly (issue #560) (@solnic)

### Changed

- `dry-schema` dependency was bumped to `>= 1.3.1` (@solnic)

[Compare v1.1.1...v1.2.0](https://github.com/dry-rb/dry-validation/compare/v1.1.1...v1.2.0)

## 1.1.1 2019-06-24


### Fixed

- `Rule#each` works with array values from nested hashes (@mustardnoise)


[Compare v1.1.0...v1.1.1](https://github.com/dry-rb/dry-validation/compare/v1.1.0...v1.1.1)

## 1.1.0 2019-06-14


### Added

- `key?` method available within rules, that can be used to check if there's a value under the rule's default key (refs #540) (@solnic)
- `value` supports hash-based path specifications now (refs #547) (@solnic)
- `value` can read multiple values when the key points to them, ie in case of `rule(geo: [:lat, :lon])` it would return an array with `lat` and `lon` (@solnic)

### Fixed

- Passing multiple macro names to `validate` or `each` works correctly (fixed #538 #541) (@jandudulski)


[Compare v1.0.0...v1.1.0](https://github.com/dry-rb/dry-validation/compare/v1.0.0...v1.1.0)

## 1.0.0 2019-06-10

See [the list of all addressed issues](https://github.com/dry-rb/dry-validation/issues?utf8=✓&q=is%3Aissue+is%3Aclosed+closed%3A%3E%3D2019-01-01+) as well as issues that were moved to dry-schema and [addressed there](https://github.com/dry-rb/dry-schema/issues?q=is%3Aissue+is%3Aclosed+dry-validation+milestone%3A1.0.0).


[Compare v1.0.0...v1.0.0](https://github.com/dry-rb/dry-validation/compare/v1.0.0...v1.0.0)

## 1.0.0 2019-06-10


### Added

- Support for defining rules for each element of an array via `rule(:items).each { ... }` (solnic)
- Support for parameterized macros via `rule(:foo).validate(my_macro: :some_option)` (solnic)
- `values#[]` is now compatible with path specs (symbol, array with keys or dot-notation) (issue #528) (solnic)
- `value` shortcut for accessing the value found under the first key specified by a rule. ie `rule(:foo) { value }` returns `values[:foo]` (solnic)

### Fixed

- Contract's `config.locale` option was replaced by `config.messages.default_locale` to avoid conflicts with run-time `:locale` option and/or whatever is set via `I18n` gem (solnic)
- Macros no longer mutate `Dry::Validation::Contract.macros` when using inheritance (solnic)
- Missing dependency on `dry-container` was added (solnic)

### Changed

- `rule` will raise `InvalidKeysError` when specified keys are not defined by the schema (solnic)
- `Contract.new` will raise `SchemaMissingError` when the class doesn't have schema defined (solnic)
- Contracts no longer support `:locale` option in the constructor. Use `Result#errors(locale: :pl)` to change locale at run-time (solnic)

[Compare v1.0.0.rc3...v1.0.0](https://github.com/dry-rb/dry-validation/compare/v1.0.0.rc3...v1.0.0)

## 1.0.0.rc3 2019-05-06


### Added

- [EXPERIMENTAL] `Validation.register_macro` for registering global macros (solnic)
- [EXPERIMENTAL] `Contract.register_macro` for registering macros available to specific contract classes (solnic)
- `Dry::Validation.Contract` shortcut for quickly defining a contract and getting its instance back (solnic)
- New configuration option `config.locale` for setting the default locale (solnic)

### Fixed

- `config/errors.yml` are now bundled with the gem, **`rc2` was broken because of this** (solnic)


[Compare v1.0.0.rc2...v1.0.0.rc3](https://github.com/dry-rb/dry-validation/compare/v1.0.0.rc2...v1.0.0.rc3)

## 1.0.0.rc2 2019-05-04

This was **yanked** on rubygems.org because the bundled gem was missing `config` directory, thus it was not possible to require it. It was fixed in `rc3`.

### Added

- [EXPERIMENTAL] support for registering macros via `Dry::Validation::Macros.register(:your_macro, &block)` (solnic)
- [EXPERIMENTAL] `:acceptance` as the first built-in macro (issue #157) (solnic)

### Fixed

- Passing invalid argument to `failure` will raise a meaningful error instead of crashing (solnic)

### Changed

- In rule validation blocks, `values` is now an instance of a hash-like `Dry::Validation::Values` class, rather than `Dry::Schema::Result`. This gives more convenient access to data within rules (solnic)
- Dependency on `dry-schema` was updated to `~> 1.0` (solnic)

[Compare v1.0.0.rc1...v1.0.0.rc2](https://github.com/dry-rb/dry-validation/compare/v1.0.0.rc1...v1.0.0.rc2)

## 1.0.0.rc1 2019-04-26


### Added

- `:hints` extension is back (solnic)
- `Result` objects have access to the context object which is shared between rules (flash-gordon)

### Fixed

- Multiple hint messages no longer crash message set (flash-gordon)
- `Contract#inspect` no longer crashes (solnic)

### Changed

- Dependency on `dry-schema` was bumped to `~> 0.6` - this pulls in `dry-types 1.0.0` and `dry-logic 1.0.0` (solnic)
- Dependency on `dry-initializer` was bumped to `~> 3.0` (solnic)

[Compare v1.0.0.beta2...v1.0.0.rc1](https://github.com/dry-rb/dry-validation/compare/v1.0.0.beta2...v1.0.0.rc1)

## 1.0.0.beta2 2019-04-04


### Added

- Support for arbitrary meta-data in failures, ie:

  ```ruby
  class NewUserContract < Dry::Validation::Contract
    params do
      required(:login).filled(:string)
    end

    rule(:login) do
      key.failure(text: 'is taken', code: 123) unless db.unique?(values[:login])
    end
  end
  ```

  Now your error hash will include `{ login: [{ text: 'is taken', code: 123 }] }` (solnic + flash-gordon)

### Changed

- [BREAKING] `Error` was renamed to `Message` as it is a more generic concept (solnic)
- [BREAKING] `ErrorSet` was renamed to `MessageSet` for consistency (solnic)
- [BREAKING] `:monads` extension wraps entire result objects in `Success` or `Failure` (flash-gordon)

[Compare v1.0.0.beta1...v1.0.0.beta2](https://github.com/dry-rb/dry-validation/compare/v1.0.0.beta1...v1.0.0.beta2)

## 1.0.0.beta1 2019-03-26


### Added

- New API for setting failures `base.failure` for base errors and `key.failure` for key errors (solnic)
- Support for `base` errors associated with a key even when child keys have errors too (solnic)
- Support for `base` errors not associated with any key (solnic)
- Result objects use `ErrorSet` object now for managing messages (solnic)
- Nested keys are properly handled when generating messages hash (issue #489) (flash-gordon + solnic)
- Result objects support `locale` and `full` options now (solnic)
- Ability to configure `top_namespace` for messages, which will be used for both schema and rule localization (solnic)
- Rule blocks receive a context object that you can use to share data between rules (solnic)

### Changed

- [BREAKING] `Result#errors` returns an instance of `ErrorSet` now, it's an enumerable, coerible to a hash (solnic)
- [BREAKING] `failure` was removed in favor of `key.failure` or `key(:foo).failure` (solnic)
- [BREAKING] `Result#to_hash` was removed (flash-gordon)

[Compare v1.0.0.alpha2...v1.0.0.beta1](https://github.com/dry-rb/dry-validation/compare/v1.0.0.alpha2...v1.0.0.beta1)

## 1.0.0.alpha2 2019-03-05

First round of bug fixes. Thanks for testing <3!

### Fixed

- Errors with nested messages are correctly built (flash-gordon)
- Messages for nested keys are correctly resolved (solnic)
- A message for a nested key is resolved when it's defined under `errors.rule.%{key}` too, but a message under nested key will override it (solnic)

### Changed

- When a message template is not found a more meaningful error is raised that includes both rule identifier and key path (solnic)

[Compare v1.0.0.alpha1...v1.0.0.alpha2](https://github.com/dry-rb/dry-validation/compare/v1.0.0.alpha1...v1.0.0.alpha2)

## 1.0.0.alpha1 2019-03-04

Complete rewrite on top of `dry-schema`.

### Added

- [BREAKING] `Dry::Validation::Contract` as a replacement for validation schemas (solnic)
- [BREAKING] New `rule` DSL with an improved API for setting error messages (solnic)


[Compare v0.13.0...v1.0.0.alpha1](https://github.com/dry-rb/dry-validation/compare/v0.13.0...v1.0.0.alpha1)

## 0.13.0 2019-01-29


### Fixed

- Warning about method redefined (amatsuda)

### Changed

- `dry-logic` was bumped to `~> 0.5` (solnic)
- `dry-types` was bumped to `~> 0.14` (solnic)

[Compare v0.12.3...v0.13.0](https://github.com/dry-rb/dry-validation/compare/v0.12.3...v0.13.0)

## 0.12.3 2019-01-29


### Changed

- [internal] dry-logic was pinned to `~> 0.4.2` (flash-gordon)

[Compare v0.12.2...v0.12.3](https://github.com/dry-rb/dry-validation/compare/v0.12.2...v0.12.3)

## 0.12.2 2018-08-29


### Fixed

- Use correct key names for rule messages when using i18n (jozzi05)


[Compare v0.12.1...v0.12.2](https://github.com/dry-rb/dry-validation/compare/v0.12.1...v0.12.2)

## 0.12.1 2018-07-06


### Fixed

- [internal] fixed deprecation warnings (flash-gordon)


[Compare v0.12.0...v0.12.1](https://github.com/dry-rb/dry-validation/compare/v0.12.0...v0.12.1)

## 0.12.0 2018-05-31


### Changed

- Code updated to work with `dry-types` 0.13.1 and `dry-struct` 0.5.0, these are now minimal supported versions (flash-gordon)
- [BREAKING] `Form` was renamed to `Params` to be consistent with the latest changes from `dry-types`. You can `require 'dry/validation/compat/form'` to use the previous names but it will be removed in the next version (flash-gordon)

[Compare v0.11.1...v0.12.0](https://github.com/dry-rb/dry-validation/compare/v0.11.1...v0.12.0)

## 0.11.1 2017-09-15


### Changed

- `Result#to_either` was renamed to `#to_monad`, the previous name is kept for backward compatibility (flash-gordon)
- [internal] fix warnings from dry-types v0.12.0

[Compare v0.11.0...v0.11.1](https://github.com/dry-rb/dry-validation/compare/v0.11.0...v0.11.1)

## 0.11.0 2017-05-30


### Changed

- [internal] input processor compilers have been updated to work with new dry-types' AST (GustavoCaso)

[Compare v0.10.7...v0.11.0](https://github.com/dry-rb/dry-validation/compare/v0.10.7...v0.11.0)

## 0.10.7 2017-05-15


### Fixed

- `validate` can now be defined multiple times for the same key (kimquy)
- Re-using rules between schemas no longer mutates original rule set (pabloh)


[Compare v0.10.6...v0.10.7](https://github.com/dry-rb/dry-validation/compare/v0.10.6...v0.10.7)

## 0.10.6 2017-04-26


### Fixed

- Fixes issue with wrong localized error messages when namespaced messages are used (kbredemeier)


[Compare v0.10.5...v0.10.6](https://github.com/dry-rb/dry-validation/compare/v0.10.5...v0.10.6)

## 0.10.5 2017-01-12


### Fixed

- Warnings under MRI 2.4.0 are gone (koic)


[Compare v0.10.4...v0.10.5](https://github.com/dry-rb/dry-validation/compare/v0.10.4...v0.10.5)

## 0.10.4 2016-12-03


### Fixed

- Updated to dry-core >= 0.2.1 (ruby warnings are gone) (flash-gordon)
- `format?` predicate is excluded from hints (solnic)

### Changed

- `version` file is now required by default (georgemillo)

[Compare v0.10.3...v0.10.4](https://github.com/dry-rb/dry-validation/compare/v0.10.3...v0.10.4)

## 0.10.3 2016-09-27


### Fixed

- Custom predicates work correctly with `each` macro (solnic)


[Compare v0.10.2...v0.10.3](https://github.com/dry-rb/dry-validation/compare/v0.10.2...v0.10.3)

## 0.10.2 2016-09-23


### Fixed

- Constrained types + hints work again (solnic)


[Compare v0.10.1...v0.10.2](https://github.com/dry-rb/dry-validation/compare/v0.10.1...v0.10.2)

## 0.10.1 2016-09-22


### Fixed

- Remove obsolete require of `dry/struct` which is now an optional extension (flash-gordon)


[Compare v0.10.0...v0.10.1](https://github.com/dry-rb/dry-validation/compare/v0.10.0...v0.10.1)

## 0.10.0 2016-09-21


### Added

- Support for `validate` DSL which accepts an arbitratry validation block that gets executed in the context of a schema object and is treated as a custom predicate (solnic)
- Support for `or` error messages ie "must be a string or must be an integer" (solnic)
- Support for retrieving error messages exclusively via `schema.(input).errors` (solnic)
- Support for retrieving hint messages exclusively via `schema.(input).hints` (solnic)
- Support for opt-in extensions loaded via `Dry::Validation.load_extensions(:my_ext)` (flash-gordon)
- Add `:monads` extension which transforms a result instance to `Either` monad, `schema.(input).to_either` (flash-gordon)
- Add `dry-struct` integration via an extension activated by `Dry::Validation.load_extensions(:struct)` (flash-gordon)

### Fixed

- Input rules (defined via `input` macro) are now lazy-initialized which makes it work with predicates defined on the schema object (solnic)
- Hints are properly generated based on argument type in cases like `size?`, where the message should be different for strings (uses "length") or other types (uses "size") (solnic)
- Defining nested keys without `schema` blocks results in `ArgumentError` (solnic)

### Changed

- [BREAKING] `when` macro no longer supports multiple disconnected rules in its block, whatever the block returns will be used for the implication (solnic)
- [BREAKING] `rule(some_name: %i(some keys))` will _always_ use `:some_name` as the key for failure messages (solnic)

[Compare v0.9.5...v0.10.0](https://github.com/dry-rb/dry-validation/compare/v0.9.5...v0.10.0)

## 0.9.5 2016-08-16


### Fixed

- Infering multiple predicates with options works as expected ie `value(:str?, min_size?: 3, max_size?: 6)` (solnic)
- Default `locale` configured in `I18n` is now respected by the messages compiler (agustin + cavi21)


[Compare v0.9.4...v0.9.5](https://github.com/dry-rb/dry-validation/compare/v0.9.4...v0.9.5)

## 0.9.4 2016-08-11


### Fixed

- Error messages for sibling deeply nested schemas are nested correctly (timriley)


[Compare v0.9.3...v0.9.4](https://github.com/dry-rb/dry-validation/compare/v0.9.3...v0.9.4)

## 0.9.3 2016-07-22


### Added

- Support for range arg in error messages for `excluded_from?` and `included_in?` (mrbongiolo)
- `Result#message_set` returns raw message set object (solnic)

### Fixed

- Error messages for high-level rules in nested schemas are nested correctly (solnic)
- Dumping error messages works with high-level rules relying on the same value (solnic)

### Changed

- `#messages` is no longer memoized (solnic)

[Compare v0.9.2...v0.9.3](https://github.com/dry-rb/dry-validation/compare/v0.9.2...v0.9.3)

## 0.9.2 2016-07-13


### Fixed

- Constrained types now work with `each` macro (solnic)
- Array coercion without member type works now ie `required(:arr).maybe(:array?)` (solnic)


[Compare v0.9.1...v0.9.2](https://github.com/dry-rb/dry-validation/compare/v0.9.1...v0.9.2)

## 0.9.1 2016-07-11


### Fixed

- `I18n` backend is no longer required and set by default (solnic)


[Compare v0.9.0...v0.9.1](https://github.com/dry-rb/dry-validation/compare/v0.9.0...v0.9.1)

## 0.9.0 2016-07-08


### Added

- Support for defining maybe-schemas via `maybe { schema { .. } }` (solnic)
- Support for interpolation of custom failure messages for custom rules (solnic)
- Support for defining a base schema **class** with config and rules (solnic)
- Support for more than 1 predicate in `input` macro (solnic)
- Class-level `define!` API for defining rules on a class (solnic)
- `:i18n` messages support merging from other paths via `messages_file` setting (solnic)
- Support for message token transformations in custom predicates (fran-worley)
- [EXPERIMENTAL] Ability to compose predicates that accept dynamic args provided by the schema (solnic)

### Fixed

- Duped key names in nested schemas no longer result in invalid error messages structure (solnic)
- Error message structure for deeply nested each/schema rules (solnic)
- Values from `option` are passed down to nested schemas when using `Schema#with` (solnic)
- Hints now work with array elements too (solnic)
- Hints for elements are no longer provided for an array when the value is not an array (solnic)
- `input` macro no longer messes up error messages for nested structures (solnic)

### Changed

- Tokens for `size?` were renamed `left` => `size_left` and `right` => `size_right` (fran-worley)

[Compare v0.8.0...v0.9.0](https://github.com/dry-rb/dry-validation/compare/v0.8.0...v0.9.0)

## 0.8.0 2016-07-01


### Added

- Explicit interface for type specs used to set up coercions, ie `required(:age, :int)` (solnic)
- Support new dry-logic predicates: `:excluded_from?`, `:excludes?`, `:included_in?`, `:includes?`, `:not_eql?`, `:odd?`, `:even?` (jodosha, fran-worley)
- Support for blocks in `value`, `filled` and `maybe` macros (solnic)
- Support for passing a schema to `value|filled|maybe` macros ie `maybe(SomeSchema)` (solnic)
- Support for `each(SomeSchema)` (solnic)
- Support for `value|filled|maybe` macros + `each` inside a block ie: `maybe(:filled?) { each(:int?) }` (solnic)
- Support for dedicated hint messages via `en.errors.#{predicate}.(hint|failure)` look-up paths (solnic)
- Support for configuring custom DSL extensions via `dsl_extensions` setting on Schema class (solnic)
- Support for preconfiguring a predicate for the input value ie `value :hash?` used for prerequisite-checks (solnic)
- Infer coercion from constrained types (solnic)
- Add value macro (coop)
- Enable .schema to accept objects that respond to #schema (ttdonovan)
- Support for schema predicates which don't need any arguments (fran-worley)
- Error and hint messages have access to all predicate arguments by default (fran-worley+solnic)
- Invalid predicate name in DSL will raise an error (solnic)
- Predicate with invalid arity in DSL will raise an error (solnic)

### Fixed

- Support for jRuby 9.1.1.0 (flash-gordon)
- Fix bug when using predicates with options in each and when (fran-worley)
- Fix bug when validating custom types (coop)
- Fix depending on deeply nested values in high-lvl rules (solnic)
- Fix duplicated error message for lt? when hint was used (solnic)
- Fix hints for nested schemas (solnic)
- Fix an issue where rules with same names inside nested schemas have incorrect hints (solnic)
- Fix a bug where hints were being generated 4 times (solnic)
- Fix duplicated error messages when message is different than a hint (solnic)

### Changed

- Uses new `:weak` hash constructor from dry-types 0.8.0 which can partially coerce invalid hash (solnic)
- `key` has been deprecated in favor of `required` (coop)
- `required` has been deprecated in favor of `filled` (coop)
- Now relies on dry-logic v0.3.0 and dry-types v0.8.0 (fran-worley)
- Tring to use illogical predicates with maybe and filled macros now raise InvalidSchemaError (fran-worley)
- Enable coercion on form.true and form.false (fran-worley)
- Remove attr (will be extracted to a separate gem) (coop)
- Deprecate required in favour of filled (coop)
- Deprecate key in favor of required (coop)
- Remove nested key syntax (solnic)

[Compare v0.7.4...v0.8.0](https://github.com/dry-rb/dry-validation/compare/v0.7.4...v0.8.0)

## 0.7.4 2016-04-06


### Added

- `Schema.JSON` with json-specific coercions (coop)
- Support for error messages for `odd? and`even?` predicates (fran-worley)

### Fixed

- Depending on deeply nested values in high-level rules works now (solnic)


[Compare v0.7.3...v0.7.4](https://github.com/dry-rb/dry-validation/compare/v0.7.3...v0.7.4)

## 0.7.3 2016-03-30


### Added

- Support for inferring rules from constrained type (coop + solnic)
- Support for inferring nested schemas from `Dry::Types::Struct` classes (coop)
- Support for `number?` predicate (solnic)

### Fixed

- Creating a nested schema properly sets full path to nested data structure (solnic)
- Error message for `empty?` predicate is now correct (jodosha)


[Compare v0.7.2...v0.7.3](https://github.com/dry-rb/dry-validation/compare/v0.7.2...v0.7.3)

## 0.7.2 2016-03-28


### Added

- Support for nested schemas inside high-level rules (solnic)
- `Schema#to_proc` so that you can do `data.each(&schema)` (solnic)


[Compare v0.7.1...v0.7.2](https://github.com/dry-rb/dry-validation/compare/v0.7.1...v0.7.2)

## 0.7.1 2016-03-21


### Added

- You can use `schema` inside `each` macro (solnic)

### Fixed

- `confirmation` macro defines an optional key with maybe value with `_confirmation` suffix (solnic)
- `each` macro works correctly when its inner rule specify just one key (solnic)
- error messages for `each` rules where input is equal are now correctly generated (solnic)

### Changed

- Now depends on `dry-logic` >= `0.2.1` (solnic)

[Compare v0.7.0...v0.7.1](https://github.com/dry-rb/dry-validation/compare/v0.7.0...v0.7.1)

## 0.7.0 2016-03-16


### Added

- Support for macros:
  - `required` - when value must be filled
  - `maybe` - when value can be nil (or empty, in case of `Form`)
  - `when` - for composing high-level rule based on predicates applied to a
    validated value
  - `confirmation` - for confirmation validation
- Support for `value(:foo).eql?(value(:bar))` syntax in high-level rules (solnic)
- New DSL for defining schema objects `Dry::Validation.Schema do .. end` (solnic)
- Ability to define a schema for an array via top-level `each` rule (solnic)
- Ability to define nested schemas via `key(:location).schema do .. end` (solnic)
- Ability to re-use schemas inside other schemas via `key(:location).schema(LocationSchema)` (solnic)
- Ability to inherit rules from another schema via `Dry::Validation.Schema(Other) do .. end` (solnic)
- Ability to inject arbitrary dependencies to schemas via `Schema.option` + `Schema#with` (solnic)
- Ability to provide translations for rule names under `%{locale}.rules.%{name}` pattern (solnic)
- Ability to configure input processor, either `:form` or `:sanitizer` (solnic)
- Ability to pass a constrained dry type when defining keys or attrs, ie `key(:age, Types::Age)` (solnic)
- `Result#messages` supports `:full` option to get messages with rule names, disabled by default (solnic)
- `Validation::Result` responds to `#[]` and `#each` (delegating to its output)
  and it's an enumerable (solnic)

### Fixed

- Qualified rule names properly use last node by default for error messages (solnic)
- Validation hints only include relevant messages (solnic)
- `:yaml` messages respect `:locale` option in `Result#messages` (solnic)

### Changed

- `schema` was **removed** from the DSL, just use `key(:name).schema` instead (solnic)
- `confirmation` is now a macro that you can call on a key rule (solnic)
- rule names for nested structures are now fully qualified, which means you can
  provide customized messages for them. ie `user: :email` (solnic)
- `Schema::Result#params` was renamed to `#output` (solnic)
- `Schema::Result` is now `Validation::Result` and it no longer has success and
  failure results, only error results are provided (solnic)

[Compare v0.6.0...v0.7.0](https://github.com/dry-rb/dry-validation/compare/v0.6.0...v0.7.0)

## 0.6.0 2016-01-20


### Added

- Support for validating objects with attr readers via `attr` (SunnyMagadan)
- Support for `value` interface in the DSL for composing high-level rules based on values (solnic)
- Support for `rule(name: :something)` syntax for grouping high-level rules under
  the same name (solnic)
- Support for `confirmation(:foo, some_predicate: some_argument)` shortcut syntax (solnic)
- Support for error messages for grouped rules (like `confirmation`) (solnic)
- Schemas support injecting rules from the outside (solnic)
- ## Changed
- `rule` uses objects that inherit from `BasicObject` to avoid conflicts with
  predicate names and built-in `Object` methods (solnic)
- In `Schema::Form` both `key` and `optional` will apply `filled?` predicate by
  default when no block is passed (solnic)


[Compare v0.5.0...v0.6.0](https://github.com/dry-rb/dry-validation/compare/v0.5.0...v0.6.0)

## 0.5.0 2016-01-11


### Fixed

- `Schema::Form` uses safe `form.array` and `form.hash` types which fixes #42 (solnic)

### Changed

- Now depends on [dry-logic](https://github.com/dry-rb/dry-logic) for predicates and rules (solnic)
- `dry/validation/schema/form` is now required by default (solnic)

[Compare v0.4.1...v0.5.0](https://github.com/dry-rb/dry-validation/compare/v0.4.1...v0.5.0)

## 0.4.1 2015-12-27


### Added

- Support for `each` and type coercion inference in `Schema::Form` (solnic)


[Compare v0.4.0...v0.4.1](https://github.com/dry-rb/dry-validation/compare/v0.4.0...v0.4.1)

## 0.4.0 2015-12-21


### Added

- Support for high-level rule composition via `rule` interface (solnic)
- Support for exclusive disjunction (aka xor/^ operator) (solnic)
- Support for nested schemas within a schema class (solnic)
- Support for negating rules via `rule(name).not` (solnic)
- Support for `validation hints` that are included in the error messages (solnic)

### Fixed

- Error messages hash has now consistent structure `rule_name => [msgs_array, input_value]` (solnic)


[Compare v0.3.1...v0.4.0](https://github.com/dry-rb/dry-validation/compare/v0.3.1...v0.4.0)

## 0.3.1 2015-12-08


### Added

- Support for `Range` and `Array` as an argument in `size?` predicate (solnic)

### Fixed

- Error compiler returns an empty hash rather than a nil when there are no errors (solnic)


[Compare v0.3.0...v0.3.1](https://github.com/dry-rb/dry-validation/compare/v0.3.0...v0.3.1)

## 0.3.0 2015-12-07


### Added

- I18n messages support (solnic)
- Ability to configure `messages` via `configure { config.messages = :i18n }` (solnic)
- `rule` interface in DSL for defining rules that depend on other rules (solnic)
- `confirmation` interface as a shortcut for defining "confirmation of" rule (solnic)
- Error messages can be now matched by input value type too (solnic)

### Fixed

- `optional` rule with coercions work correctly with `|` + multiple `&`s (solnic)
- `Schema#[]` checks registered predicates first before defaulting to its own predicates (solnic)

### Changed

- `Schema#messages(input)` => `Schema#call(input).messages` (solnic)
- `Schema#call` returns `Schema::Result` which has access to all rule results,
  errors and messages
- `Schema::Result#messages` returns a hash with rule names, messages and input values (solnic)

[Compare v0.2.0...v0.3.0](https://github.com/dry-rb/dry-validation/compare/v0.2.0...v0.3.0)

## 0.2.0 2015-11-30


### Added

- `Schema::Form` with a built-in coercer inferred from type-check predicates (solnic)
- Ability to pass a block to predicate check in the DSL ie `value.hash? { ... }` (solnic)
- Optional keys using `optional(:key_name) { ... }` interface in the DSL (solnic)
- New predicates:
  - `bool?`
  - `date?`
  - `date_time?`
  - `time?`
  - `float?`
  - `decimal?`
  - `hash?`
  - `array?`

### Fixed

- Added missing `and` / `or` interfaces to composite rules (solnic)


[Compare v0.1.0...v0.2.0](https://github.com/dry-rb/dry-validation/compare/v0.1.0...v0.2.0)

## 0.1.0 2015-11-25

First public release
