# Change log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## v0.3.0 - 2017-05-30

### Added
* encoding and decoding of ChannelData messages
* encoding and decoding of ChannelBind method and CHANNEL-NUMBER attribute
* support for TURN channels mechanism for data exchange (`Jerboa.Client.open_channel/2`)

### Fixed
* multiple bugs around permissions by changing the design of acknowledging permissions - permissions are
  tracked only after a successful CreatePermission arrives from the server

## v0.2.0 - 2017-05-16

### Added
* encoding and decoding of TURN attributes and methods (without channels)
* TURN client behaviour - allocations, permissions, sending and receiving data over relay

## v0.1.0 - 2017-02-21

### Added
* encoding and decoding of STUN messages format, header validation
* encoding and decoding of XOR-MAPPED-ADDRESS attribute
* basic STUN client utilities - sending Binding request and indication
