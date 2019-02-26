# Changelog

## Unrelease

## v0.9.1

* Fix type spec warnings in `Saxy.SimpleForm`.

## v0.9.0

* Allow turning off streaming feature in config [#30](https://github.com/qcam/saxy/pull/30).
* Skip DTD instead of crashing [#33](https://github.com/qcam/saxy/pull/33).
* Minor bug fix on element attributes order [09b90a9b50ea3ffa17ba2736c29ff791ff9859d0](https://github.com/qcam/saxy/commit/09b90a9b50ea3ffa17ba2736c29ff791ff9859d0).

## v0.8.0

* Improve streaming parsing [#23](https://github.com/qcam/saxy/pull/23).
* Improve parser performance [#24](https://github.com/qcam/saxy/pull/24).
* Improve parser error handling [#25](https://github.com/qcam/saxy/pull/25).

## v0.7.0

* Introduce XML encoder [#17](https://github.com/qcam/saxy/pull/17).
* Fix wrong ASCII code point matching [#20](https://github.com/qcam/saxy/pull/20).
* Brought back UTF-8 encoding validation ([#16](https://github.com/qcam/saxy/pull/16)).

## v0.6.0

* Introduce `:expand_entity` option ([#14](https://github.com/qcam/saxy/pull/14)).
* Hard deprecate `Saxy.Handler.handle_entity_reference/1` callback ([#14](https://github.com/qcam/saxy/pull/14)).
* Fix a UTF-8 buffering bug for streaming parsing ([#13](https://github.com/qcam/saxy/pull/13), [#15](https://github.com/qcam/saxy/pull/15)).
* Return only root tag in simple form parsing ([e8c062](https://github.com/qcam/saxy/commit/e8c062e94f91ccea4491cec29c4c7861e7b7163b)).

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
