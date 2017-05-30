# Jerboa

[![Build Status](https://travis-ci.org/esl/jerboa.svg?branch=travis-ci-integration)](https://travis-ci.org/esl/jerboa)
[![Inline docs](http://inch-ci.org/github/esl/jerboa.svg?branch=master)](http://inch-ci.org/github/esl/jerboa)
[![Coverage Status](https://coveralls.io/repos/github/esl/jerboa/badge.svg?branch=master)](https://coveralls.io/github/esl/jerboa?branch=master)
[![Ebert](https://ebertapp.io/github/esl/jerboa.svg)](https://ebertapp.io/github/esl/jerboa)

[Documentation](https://hexdocs.pm/jerboa/0.3.0)


STUN/TURN encoder, decoder and client library by [Erlang Solutions](https://www.erlang-solutions.com)

Jerboa aims to provide simple APIs for common STUN/TURN use cases. It is used by [Fennec](https://github.com/esl/fennec)
for encoding and decoding of STUN messages, as well as a testing tool.

### Installation

Jerboa is available on [Hex](https://hex.pm/packages/jerboa). To use it, just add it to your dependencies:

```elixir
def deps do
  [{:jerboa, "~> 0.3.0"}]
end
```

### Checklist of STUN/TURN/ICE methods supported by Jerboa's encoder/decoder

- [x] Binding
- [x] Allocate
- [x] Refresh
- [x] Send
- [x] Data
- [x] CreatePermission
- [x] ChannelBind

### Checklist of STUN/TURN/ICE attributes supported by Jerboa's encoder/decoder

#### Comprehension Required

- [x] XOR-MAPPED-ADDRESS
- [x] MESSAGE-INTEGRITY
- [x] ERROR-CODE
- [ ] UNKNOWN-ATTRIBUTES
- [x] REALM
- [x] NONCE
- [x] CHANNEL-NUMBER
- [x] LIFETIME
- [x] XOR-PEER-ADDRESS
- [x] DATA
- [x] XOR-RELAYED-ADDRESS
- [x] EVEN-PORT
- [x] REQUESTED-TRANSPORT
- [x] DONT-FRAGMENT
- [x] RESERVATION-TOKEN
- [ ] PRIORITY
- [ ] USE-CANDIDATE
- [ ] ICE-CONTROLLED
- [ ] ICE-CONTROLLING

#### Comprehension Optional

- [ ] SOFTWARE
- [ ] ALTERNATE-SERVER
- [ ] FINGERPRINT

## License

Copyright 2016-2017 Erlang Solutions Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
