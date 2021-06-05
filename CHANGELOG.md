# Changelog

## v1.4.0 - 2020-06-05

* Optimize `Saxy.parse_string` (about 20% faster) [#84](https://github.com/qcam/saxy/pull/84).
  Previously this could be achieved with application config, you no longer have
  to do that.
* Support custom transformer in `Saxy.Builder` [#87](https://github.com/qcam/saxy/pull/87).
* Miscellaneous fixes [#81](https://github.com/qcam/saxy/pull/81),
  [#82](https://github.com/qcam/saxy/pull/82),
  [#89](https://github.com/qcam/saxy/pull/89).

## v1.3.0 - 2020-10-18

* Fix Saxy.Builder primitive type implementations.
* Add `:cdata` SAX event type.
* Introduce `:cdata_as_characters` option in parsers.

## v1.2.2 - 2020-10-02

* Bring back accidentally removed XML builders.

## v1.2.1 - 2020-09-27 (retired)

* Fix incorrect type spec.

## v1.2.0 - 2020-06-02

* Fix XML encoding without prolog [#57](https://github.com/qcam/saxy/pull/57).
* Fix integer typespec [#58](https://github.com/qcam/saxy/pull/58).
* Introduce parser halting [#66](https://github.com/qcam/saxy/pull/66).
* Speed up XML builder [#69](https://github.com/qcam/saxy/pull/69).

## v1.1.0 - 2020-02-09

* Introduce `:character_data_max_length` option in stream and partial parsing.

## v1.0.0 - 2019-12-19

* Support Elixir 1.6+.
* Fix white spaces emitting bug in empty elements.

## v0.10.0 - 2019-08-26

* Add support of partial parsing [#42](https://github.com/qcam/saxy/pull/42).

## v0.9.1 - 2019-02-26

* Fix type spec warnings in `Saxy.SimpleForm`.

## v0.9.0 - 2018-10-21

* Allow turning off streaming feature in config [#30](https://github.com/qcam/saxy/pull/30).
* Skip DTD instead of crashing [#33](https://github.com/qcam/saxy/pull/33).
* Minor bug fix on element attributes order [09b90a9b50ea3ffa17ba2736c29ff791ff9859d0](https://github.com/qcam/saxy/commit/09b90a9b50ea3ffa17ba2736c29ff791ff9859d0).

## v0.8.0 - 2018-09-05

* Improve streaming parsing [#23](https://github.com/qcam/saxy/pull/23).
* Improve parser performance [#24](https://github.com/qcam/saxy/pull/24).
* Improve parser error handling [#25](https://github.com/qcam/saxy/pull/25).

## v0.7.0 - 2018-07-14

* Introduce XML encoder [#17](https://github.com/qcam/saxy/pull/17).
* Fix wrong ASCII code point matching [#20](https://github.com/qcam/saxy/pull/20).
* Brought back UTF-8 encoding validation ([#16](https://github.com/qcam/saxy/pull/16)).

## v0.6.0 - 2018-04-08

* Introduce `:expand_entity` option ([#14](https://github.com/qcam/saxy/pull/14)).
* Hard deprecate `Saxy.Handler.handle_entity_reference/1` callback ([#14](https://github.com/qcam/saxy/pull/14)).
* Fix a UTF-8 buffering bug for streaming parsing ([#13](https://github.com/qcam/saxy/pull/13), [#15](https://github.com/qcam/saxy/pull/15)).
* Return only root tag in simple form parsing ([e8c062](https://github.com/qcam/saxy/commit/e8c062e94f91ccea4491cec29c4c7861e7b7163b)).

## v0.5.0 - 2018-03-15

* Introduce Simple Form parsing.
* Parse misc after finishing parsing root element.

## v0.4.0 - 2018-03-12

* Supported Elixir v1.3.
* Increased parsing speed by 22 times.
* Improved returning error.
* Added `handle_entity_reference` callback in `Saxy.Handler`.

**Breaking changes:**

* Required entity reference handling in `Saxy.Handler`.
