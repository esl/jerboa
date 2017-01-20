# Jerboa

[![Build Status](https://travis-ci.org/esl/jerboa.svg?branch=travis-ci-integration)](https://travis-ci.org/esl/jerboa)
[![Inline docs](http://inch-ci.org/github/esl/jerboa.svg?branch=master)](http://inch-ci.org/github/esl/jerboa)
[![Coverage Status](https://coveralls.io/repos/github/esl/jerboa/badge.svg?branch=master)](https://coveralls.io/github/esl/jerboa?branch=master)
[![Ebert](https://ebertapp.io/github/esl/jerboa.svg)](https://ebertapp.io/github/esl/jerboa)


STUN/TURN encoder, decoder and client library

### Checklist of STUN/TURN/ICE methods supported by Jerboa's encoder/decoder

- [x] Binding
- [ ] Allocate
- [ ] Refresh
- [ ] Send
- [ ] Data
- [ ] CreatePermission
- [ ] ChannelBind

### Checklist of STUN/TURN/ICE attributes supported by Jerboa' encoder/decoder

#### Comprehension-required range

- [x] XOR-MAPPED-ADDRESS
- [ ] MESSAGE-INTEGRITY
- [ ] ERROR-CODE
- [ ] UNKNOWN-ATTRIBUTES
- [ ] REALM
- [ ] NONCE
- [ ] CHANNEL-NUMBER
- [ ] LIFETIME
- [ ] XOR-PEER-ADDRESS
- [ ] DATA
- [ ] XOR-RELAYED-ADDRESS
- [ ] EVEN-PORT
- [ ] REQUESTED-TRANSPORT
- [ ] DONT-FRAGMENT
- [ ] RESERVATION-TOKEN
- [ ] PRIORITY
- [ ] USE-CANDIDATE
- [ ] ICE-CONTROLLED
- [ ] ICE-CONTROLLING

#### Comprehension-optional range

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
