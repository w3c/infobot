
# W3C's own infobot

## Introduction

This bot is based on [infobot](http://www.infobot.org/), written by Kevin Lenzo <lenzo@cs.cmu.edu>.
It adds the *inform* feature, which lets you leave a message to someone offline.

## Syntax

```
botie, inform <nick> [that|to|about] <message>
```

* `inform` may also be any of these other keywords:  
`tell`, `notify`, `advise`, `alert`, `advise`, `enlighten`, `send word to`, `ping`, `remind`, `ask`, `beseech`, `beg` or `say`.
* A comma after the nickname is OK, too.
* `that`, `to` and `about` before the message are entirely optional.

## Examples

```
botie, alert joe123 that wings are on fire
botie, ask laureen to please re-send the previous version of that doc
botie, ping McNulty, The Bunks called!
botie, inform susan32 Done! :)
```

## Dependencies

Perl 5

