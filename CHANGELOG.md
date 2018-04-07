# Changelog

## Unreleased

* Introduce `:expand_entity` option.
* Hard deprecate `Saxy.Handler.handle_entity_reference/1` callback.
* Fix a UTF-8 buffering bug for streaming parsing.

## v0.5.0

* Introduce Simple Form parsing.
* Parse misc after finishing parsing root element.

## v0.4.0

* Supported Elixir v1.3.
* Increased parsing speed by 22 times.
* Improved returning error.
* Added `handle_entity_reference` callback in `Saxy.Handler`.

**Breaking changes:**

* Required entity reference handling in `Saxy.Handler`.
